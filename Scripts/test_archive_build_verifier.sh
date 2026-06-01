#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

project_setting() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ key " = " {
      value = $3
      gsub(/;/, "", value)
      print value
      exit
    }
  ' CalPal.xcodeproj/project.pbxproj
}

version="$(project_setting MARKETING_VERSION)"
build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$version" && -n "$build" ]]

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

write_info_plist() {
  local path="$1"
  local bundle_id="${2:-com.calpal.mvp}"
  local calendars_full="${3:-CalPal needs full calendar access to show your agenda and save changes you approve.}"
  local calendars_legacy="${4:-CalPal needs calendar access to show and edit events you approve.}"

  cat >"$path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>CFBundleVersion</key>
  <string>$build</string>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>$calendars_full</string>
  <key>NSCalendarsUsageDescription</key>
  <string>$calendars_legacy</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>CalPal uses the microphone only when you start a voice command.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>CalPal uses speech recognition to transcribe calendar commands.</string>
</dict>
</plist>
PLIST
}

write_privacy_manifest() {
  local path="$1"
  local tracking="${2:-false}"

  cat >"$path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>
      </array>
    </dict>
  </array>
  <key>NSPrivacyCollectedDataTypes</key>
  <array/>
  <key>NSPrivacyTracking</key>
  <$tracking/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>
</dict>
</plist>
PLIST
}

make_archive() {
  local archive_path="$1"
  local bundle_id="${2:-com.calpal.mvp}"
  local tracking="${3:-false}"
  local calendars_full="${4:-CalPal needs full calendar access to show your agenda and save changes you approve.}"

  local app_path="$archive_path/Products/Applications/CalPal.app"
  mkdir -p "$app_path"
  printf '%s\n' "CalPal local-only executable strings" >"$app_path/CalPal"
  write_info_plist "$app_path/Info.plist" "$bundle_id" "$calendars_full"
  write_privacy_manifest "$app_path/PrivacyInfo.xcprivacy" "$tracking"
}

valid_archive="$tmp_root/Valid.xcarchive"
wrong_bundle_archive="$tmp_root/WrongBundle.xcarchive"
tracking_archive="$tmp_root/Tracking.xcarchive"
missing_permission_archive="$tmp_root/MissingPermission.xcarchive"

make_archive "$valid_archive"
SKIP_ARCHIVE_BUILD=1 ARCHIVE_PATH="$valid_archive" bash Scripts/verify_archive_build.sh >/dev/null

make_archive "$wrong_bundle_archive" "com.example.invalid"
if SKIP_ARCHIVE_BUILD=1 ARCHIVE_PATH="$wrong_bundle_archive" bash Scripts/verify_archive_build.sh >/dev/null 2>&1; then
  echo "Expected archive verifier to reject an unexpected bundle identifier." >&2
  exit 1
fi

make_archive "$tracking_archive" "com.calpal.mvp" "true"
if SKIP_ARCHIVE_BUILD=1 ARCHIVE_PATH="$tracking_archive" bash Scripts/verify_archive_build.sh >/dev/null 2>&1; then
  echo "Expected archive verifier to reject tracking=true in PrivacyInfo.xcprivacy." >&2
  exit 1
fi

make_archive "$missing_permission_archive"
/usr/libexec/PlistBuddy -c "Delete :NSCalendarsFullAccessUsageDescription" "$missing_permission_archive/Products/Applications/CalPal.app/Info.plist"
if SKIP_ARCHIVE_BUILD=1 ARCHIVE_PATH="$missing_permission_archive" bash Scripts/verify_archive_build.sh >/dev/null 2>&1; then
  echo "Expected archive verifier to reject a missing Calendar Full Access usage description." >&2
  exit 1
fi

echo "Archive build verifier self-test passed."
