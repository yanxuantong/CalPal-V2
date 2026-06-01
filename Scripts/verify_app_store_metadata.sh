#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/CalPalAppStoreMetadata}"
APP_PATH="${APP_PATH:-$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/CalPal.app}"
INFO_PLIST="$APP_PATH/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"
SOURCE_PRIVACY_MANIFEST="${SOURCE_PRIVACY_MANIFEST:-$ROOT_DIR/CalPal/PrivacyInfo.xcprivacy}"
SKIP_BUILD="${SKIP_BUILD:-0}"

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

expected_version="$(project_setting MARKETING_VERSION)"
expected_build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$expected_version" ]] || { echo "Could not read MARKETING_VERSION from CalPal.xcodeproj." >&2; exit 1; }
[[ -n "$expected_build" ]] || { echo "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj." >&2; exit 1; }

if [[ "$SKIP_BUILD" != "0" && "$SKIP_BUILD" != "1" ]]; then
  echo "SKIP_BUILD must be 0 or 1." >&2
  exit 1
fi

if [[ "$SKIP_BUILD" == "0" ]]; then
  xcodebuild \
    -project CalPal.xcodeproj \
    -scheme CalPal \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing built Info.plist at $INFO_PLIST" >&2
  exit 1
fi

if [[ ! -f "$PRIVACY_MANIFEST" ]]; then
  echo "Missing PrivacyInfo.xcprivacy in app bundle." >&2
  exit 1
fi

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

require_value() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(plist_value "$key")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected $key to be '$expected' but found '$actual'." >&2
    exit 1
  fi
}

require_nonempty() {
  local key="$1"
  local value
  value="$(plist_value "$key")"
  if [[ -z "$value" ]]; then
    echo "Expected $key to be present and non-empty." >&2
    exit 1
  fi
}

require_value CFBundleShortVersionString "$expected_version"
require_value CFBundleVersion "$expected_build"
require_value CFBundleIdentifier "com.calpal.mvp"
require_nonempty NSCalendarsFullAccessUsageDescription
require_nonempty NSCalendarsUsageDescription
require_nonempty NSMicrophoneUsageDescription
require_nonempty NSSpeechRecognitionUsageDescription

require_privacy_manifest_contract() {
  local manifest="$1"
  local label="$2"
  local value

  plutil -lint "$manifest" >/dev/null

  value="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyTracking" "$manifest")"
  if [[ "$value" != "false" ]]; then
    echo "$label privacy manifest must declare NSPrivacyTracking=false." >&2
    exit 1
  fi

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyCollectedDataTypes:0" "$manifest" >/dev/null 2>&1; then
    echo "$label privacy manifest must not declare collected data types for the 1.0 local-only release." >&2
    exit 1
  fi

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyTrackingDomains:0" "$manifest" >/dev/null 2>&1; then
    echo "$label privacy manifest must not declare tracking domains for the 1.0 local-only release." >&2
    exit 1
  fi

  value="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType" "$manifest")"
  if [[ "$value" != "NSPrivacyAccessedAPICategoryUserDefaults" ]]; then
    echo "$label privacy manifest must declare UserDefaults as its required-reason API." >&2
    exit 1
  fi

  value="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0" "$manifest")"
  if [[ "$value" != "CA92.1" ]]; then
    echo "$label privacy manifest must declare the CA92.1 UserDefaults reason." >&2
    exit 1
  fi

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:1" "$manifest" >/dev/null 2>&1; then
    echo "$label privacy manifest must not declare extra UserDefaults reasons for 1.0." >&2
    exit 1
  fi

  if /usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:1" "$manifest" >/dev/null 2>&1; then
    echo "$label privacy manifest must not declare extra required-reason APIs for 1.0." >&2
    exit 1
  fi
}

require_privacy_manifest_contract "$SOURCE_PRIVACY_MANIFEST" "Source"
require_privacy_manifest_contract "$PRIVACY_MANIFEST" "Built app"

echo "App Store metadata verified in $APP_PATH"
