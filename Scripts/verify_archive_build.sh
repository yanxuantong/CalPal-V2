#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/CalPalV10ArchiveDerivedData}"
ARCHIVE_PATH="${ARCHIVE_PATH:-/tmp/CalPalV10Unsigned.xcarchive}"
SKIP_ARCHIVE_BUILD="${SKIP_ARCHIVE_BUILD:-0}"

cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

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

require_plist_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")"
  if [[ "$actual" != "$expected" ]]; then
    fail "Expected archive $key to be '$expected' but found '$actual'."
  fi
}

require_plist_nonempty() {
  local plist="$1"
  local key="$2"
  local actual
  actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")"
  [[ -n "$actual" ]] || fail "Expected archive $key to be present and non-empty."
}

require_privacy_manifest_contract() {
  local manifest="$1"
  local value

  plutil -lint "$manifest" >/dev/null

  value="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyTracking" "$manifest")"
  [[ "$value" == "false" ]] || fail "Archive privacy manifest must declare NSPrivacyTracking=false."

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyCollectedDataTypes:0" "$manifest" >/dev/null 2>&1; then
    fail "Archive privacy manifest must not declare collected data types for the 1.0 local-only release."
  fi

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyTrackingDomains:0" "$manifest" >/dev/null 2>&1; then
    fail "Archive privacy manifest must not declare tracking domains for the 1.0 local-only release."
  fi

  value="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType" "$manifest")"
  [[ "$value" == "NSPrivacyAccessedAPICategoryUserDefaults" ]] || fail "Archive privacy manifest must declare UserDefaults as its required-reason API."

  value="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0" "$manifest")"
  [[ "$value" == "CA92.1" ]] || fail "Archive privacy manifest must declare the CA92.1 UserDefaults reason."

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:1" "$manifest" >/dev/null 2>&1; then
    fail "Archive privacy manifest must not declare extra UserDefaults reasons for 1.0."
  fi

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:1" "$manifest" >/dev/null 2>&1; then
    fail "Archive privacy manifest must not declare extra required-reason APIs for 1.0."
  fi
}

expected_version="$(project_setting MARKETING_VERSION)"
expected_build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$expected_version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$expected_build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."

if [[ "$SKIP_ARCHIVE_BUILD" != "0" && "$SKIP_ARCHIVE_BUILD" != "1" ]]; then
  fail "SKIP_ARCHIVE_BUILD must be 0 or 1."
fi

if [[ "$SKIP_ARCHIVE_BUILD" == "0" ]]; then
  xcodebuild \
    archive \
    -project CalPal.xcodeproj \
    -scheme CalPal \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    SKIP_INSTALL=NO
fi

APP_PATH="$ARCHIVE_PATH/Products/Applications/CalPal.app"
INFO_PLIST="$APP_PATH/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"
if [[ ! -d "$APP_PATH" ]]; then
  fail "Archive did not contain CalPal.app at $APP_PATH"
fi

[[ -f "$INFO_PLIST" ]] || fail "Archive app is missing Info.plist."
[[ -f "$PRIVACY_MANIFEST" ]] || fail "Archive app is missing PrivacyInfo.xcprivacy."

require_plist_value "$INFO_PLIST" CFBundleShortVersionString "$expected_version"
require_plist_value "$INFO_PLIST" CFBundleVersion "$expected_build"
require_plist_value "$INFO_PLIST" CFBundleIdentifier "com.calpal.mvp"
require_plist_nonempty "$INFO_PLIST" NSCalendarsFullAccessUsageDescription
require_plist_nonempty "$INFO_PLIST" NSCalendarsUsageDescription
require_plist_nonempty "$INFO_PLIST" NSMicrophoneUsageDescription
require_plist_nonempty "$INFO_PLIST" NSSpeechRecognitionUsageDescription
require_privacy_manifest_contract "$PRIVACY_MANIFEST"

SKIP_BUILD=1 \
APP_PATH="$APP_PATH" \
APP_EXECUTABLE="$APP_PATH/CalPal" \
bash Scripts/verify_built_app_privacy_surface.sh

echo "Unsigned archive build verified at $ARCHIVE_PATH"
