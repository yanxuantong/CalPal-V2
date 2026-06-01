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
  local app_version="${3:-$version}"
  local app_build="${4:-$build}"

  cat >"$path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleShortVersionString</key>
  <string>$app_version</string>
  <key>CFBundleVersion</key>
  <string>$app_build</string>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>CalPal needs full calendar access to show your agenda and save changes you approve.</string>
  <key>NSCalendarsUsageDescription</key>
  <string>CalPal needs calendar access to show and edit events you approve.</string>
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

make_fixture() {
  local dir="$1"
  local bundle_id="${2:-com.calpal.mvp}"
  local app_version="${3:-$version}"
  local app_build="${4:-$build}"
  local source_tracking="${5:-false}"
  local built_tracking="${6:-false}"

  local app_dir="$dir/CalPal.app"
  mkdir -p "$app_dir"
  write_info_plist "$app_dir/Info.plist" "$bundle_id" "$app_version" "$app_build"
  write_privacy_manifest "$dir/SourcePrivacyInfo.xcprivacy" "$source_tracking"
  write_privacy_manifest "$app_dir/PrivacyInfo.xcprivacy" "$built_tracking"
}

valid_dir="$tmp_root/valid"
wrong_bundle_dir="$tmp_root/wrong-bundle"
wrong_version_dir="$tmp_root/wrong-version"
missing_permission_dir="$tmp_root/missing-permission"
source_tracking_dir="$tmp_root/source-tracking"
built_tracking_dir="$tmp_root/built-tracking"
extra_reason_dir="$tmp_root/extra-reason"

make_fixture "$valid_dir"
SKIP_BUILD=1 APP_PATH="$valid_dir/CalPal.app" SOURCE_PRIVACY_MANIFEST="$valid_dir/SourcePrivacyInfo.xcprivacy" bash Scripts/verify_app_store_metadata.sh >/dev/null

make_fixture "$wrong_bundle_dir" "com.example.invalid"
if SKIP_BUILD=1 APP_PATH="$wrong_bundle_dir/CalPal.app" SOURCE_PRIVACY_MANIFEST="$wrong_bundle_dir/SourcePrivacyInfo.xcprivacy" bash Scripts/verify_app_store_metadata.sh >/dev/null 2>&1; then
  echo "Expected App Store metadata verifier to reject an unexpected bundle identifier." >&2
  exit 1
fi

make_fixture "$wrong_version_dir" "com.calpal.mvp" "9.9" "$build"
if SKIP_BUILD=1 APP_PATH="$wrong_version_dir/CalPal.app" SOURCE_PRIVACY_MANIFEST="$wrong_version_dir/SourcePrivacyInfo.xcprivacy" bash Scripts/verify_app_store_metadata.sh >/dev/null 2>&1; then
  echo "Expected App Store metadata verifier to reject version drift." >&2
  exit 1
fi

make_fixture "$missing_permission_dir"
/usr/libexec/PlistBuddy -c "Delete :NSMicrophoneUsageDescription" "$missing_permission_dir/CalPal.app/Info.plist"
if SKIP_BUILD=1 APP_PATH="$missing_permission_dir/CalPal.app" SOURCE_PRIVACY_MANIFEST="$missing_permission_dir/SourcePrivacyInfo.xcprivacy" bash Scripts/verify_app_store_metadata.sh >/dev/null 2>&1; then
  echo "Expected App Store metadata verifier to reject missing permission usage strings." >&2
  exit 1
fi

make_fixture "$source_tracking_dir" "com.calpal.mvp" "$version" "$build" "true" "false"
if SKIP_BUILD=1 APP_PATH="$source_tracking_dir/CalPal.app" SOURCE_PRIVACY_MANIFEST="$source_tracking_dir/SourcePrivacyInfo.xcprivacy" bash Scripts/verify_app_store_metadata.sh >/dev/null 2>&1; then
  echo "Expected App Store metadata verifier to reject tracking=true in the source privacy manifest." >&2
  exit 1
fi

make_fixture "$built_tracking_dir" "com.calpal.mvp" "$version" "$build" "false" "true"
if SKIP_BUILD=1 APP_PATH="$built_tracking_dir/CalPal.app" SOURCE_PRIVACY_MANIFEST="$built_tracking_dir/SourcePrivacyInfo.xcprivacy" bash Scripts/verify_app_store_metadata.sh >/dev/null 2>&1; then
  echo "Expected App Store metadata verifier to reject tracking=true in the built privacy manifest." >&2
  exit 1
fi

make_fixture "$extra_reason_dir"
/usr/libexec/PlistBuddy -c "Add :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:1 string CA92.2" "$extra_reason_dir/CalPal.app/PrivacyInfo.xcprivacy"
if SKIP_BUILD=1 APP_PATH="$extra_reason_dir/CalPal.app" SOURCE_PRIVACY_MANIFEST="$extra_reason_dir/SourcePrivacyInfo.xcprivacy" bash Scripts/verify_app_store_metadata.sh >/dev/null 2>&1; then
  echo "Expected App Store metadata verifier to reject extra privacy manifest reasons." >&2
  exit 1
fi

echo "App Store metadata verifier self-test passed."
