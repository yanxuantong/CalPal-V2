#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/CalPalAppStoreMetadata}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/CalPal.app"
INFO_PLIST="$APP_PATH/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"

cd "$ROOT_DIR"

xcodebuild \
  -project CalPal.xcodeproj \
  -scheme CalPal \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

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

require_value CFBundleShortVersionString "1.0"
require_value CFBundleVersion "10"
require_nonempty NSCalendarsFullAccessUsageDescription
require_nonempty NSCalendarsUsageDescription
require_nonempty NSMicrophoneUsageDescription
require_nonempty NSSpeechRecognitionUsageDescription

plutil -lint "$PRIVACY_MANIFEST" >/dev/null

if ! plutil -p "$PRIVACY_MANIFEST" | grep -q "NSPrivacyAccessedAPICategoryUserDefaults"; then
  echo "Privacy manifest does not declare UserDefaults required-reason API usage." >&2
  exit 1
fi

if ! plutil -p "$PRIVACY_MANIFEST" | grep -q "CA92.1"; then
  echo "Privacy manifest does not declare the CA92.1 UserDefaults reason." >&2
  exit 1
fi

echo "App Store metadata verified in $APP_PATH"
