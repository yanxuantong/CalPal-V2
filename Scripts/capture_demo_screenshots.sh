#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/CalPalDemoScreenshots}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/Artifacts/AppStoreScreenshots}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/CalPal.app"
BUNDLE_ID="com.calpal.mvp"

mkdir -p "$OUTPUT_DIR"

cd "$ROOT_DIR"

xcodebuild \
  -project CalPal.xcodeproj \
  -scheme CalPal \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

UDID="${SIMULATOR_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(
    xcrun simctl list devices available |
      awk -v name="$SIMULATOR_NAME" '
        index($0, "    " name " (") == 1 {
          line = $0
          sub(/^.*\(/, "", line)
          sub(/\).*$/, "", line)
          print line
          exit
        }
      '
  )"
fi

if [[ -z "$UDID" ]]; then
  echo "Could not find an available simulator named '$SIMULATOR_NAME'." >&2
  echo "Set SIMULATOR_NAME or SIMULATOR_UDID to one listed by: xcrun simctl list devices available" >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID" --args --calpal-demo
sleep 2
xcrun simctl io "$UDID" screenshot "$OUTPUT_DIR/calpal-demo-home.png"

xcrun simctl ui "$UDID" appearance dark
xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" --args --calpal-demo
sleep 2
xcrun simctl io "$UDID" screenshot "$OUTPUT_DIR/calpal-demo-home-dark.png"

xcrun simctl ui "$UDID" appearance light

echo "Wrote demo screenshots to $OUTPUT_DIR"
