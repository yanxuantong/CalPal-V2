#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/CalPalAppStoreMetadata}"
APP_PATH="${APP_PATH:-$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/CalPal.app}"
APP_EXECUTABLE="${APP_EXECUTABLE:-$APP_PATH/CalPal}"
SKIP_BUILD="${SKIP_BUILD:-0}"

cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

if [[ "$SKIP_BUILD" != "0" && "$SKIP_BUILD" != "1" ]]; then
  fail "SKIP_BUILD must be 0 or 1."
fi

if [[ ! -d "$APP_PATH" && "$SKIP_BUILD" == "0" ]]; then
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

[[ -d "$APP_PATH" ]] || fail "Missing built app bundle: $APP_PATH"
[[ -f "$APP_EXECUTABLE" ]] || fail "Missing built app executable: $APP_EXECUTABLE"

prohibited_sdk_pattern='Firebase|Amplitude|Mixpanel|Sentry|Segment|PostHog|AppCenter|GoogleAnalytics|Datadog|Bugsnag|Crashlytics|RevenueCat|Adjust|AppsFlyer|OneSignal'

if strings "$APP_EXECUTABLE" | grep -nE 'https?://'; then
  fail "Built app executable contains an HTTP(S) endpoint; review the 1.0 local-only privacy claim."
fi

if strings "$APP_EXECUTABLE" | grep -nE '\bURLSession\b'; then
  fail "Built app executable contains URLSession; review the 1.0 local-only privacy claim."
fi

if strings "$APP_EXECUTABLE" | grep -nE "$prohibited_sdk_pattern"; then
  fail "Built app executable contains a prohibited analytics/crash/attribution/subscription SDK marker."
fi

if grep -R --binary-files=without-match -nE 'https?://example\.com|REPLACE_ME|YOUR_' "$APP_PATH"; then
  fail "Built app bundle contains sample placeholder content."
fi

if grep -R --binary-files=without-match -nE "$prohibited_sdk_pattern" "$APP_PATH"; then
  fail "Built app bundle contains a prohibited analytics/crash/attribution/subscription SDK marker."
fi

echo "Built app privacy surface verified in $APP_PATH"
