#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DERIVED_DATA_PATH="${TEST_DERIVED_DATA_PATH:-/tmp/CalPalV10ReleaseGateTests}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/Artifacts/AppStoreScreenshots}"
CAPTURE_SCREENSHOTS="${CAPTURE_SCREENSHOTS:-auto}"
PRIVACY_POLICY_PATH="$ROOT_DIR/AppStore/PRIVACY_POLICY.md"

cd "$ROOT_DIR"

if [[ "$CAPTURE_SCREENSHOTS" != "0" && "$CAPTURE_SCREENSHOTS" != "1" && "$CAPTURE_SCREENSHOTS" != "auto" ]]; then
  echo "CAPTURE_SCREENSHOTS must be 0, 1, or auto." >&2
  exit 1
fi

bash -n Scripts/capture_demo_screenshots.sh
bash -n Scripts/verify_app_store_metadata.sh
bash -n Scripts/verify_archive_build.sh
bash -n Scripts/verify_smoke_automation_contract.sh

if [[ ! -s "$PRIVACY_POLICY_PATH" ]]; then
  echo "Missing AppStore/PRIVACY_POLICY.md." >&2
  exit 1
fi

if ! grep -q "does not collect data from this app" "$PRIVACY_POLICY_PATH"; then
  echo "AppStore/PRIVACY_POLICY.md must state the current 1.0 data collection posture." >&2
  exit 1
fi

if ! grep -q "does not track users" "$PRIVACY_POLICY_PATH"; then
  echo "AppStore/PRIVACY_POLICY.md must state the current 1.0 tracking posture." >&2
  exit 1
fi

xcodebuild \
  test \
  -project CalPal.xcodeproj \
  -scheme CalPal \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$TEST_DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO

bash Scripts/verify_app_store_metadata.sh
bash Scripts/verify_archive_build.sh
bash Scripts/verify_smoke_automation_contract.sh

screenshots_missing=0
for screenshot in calpal-demo-home.png calpal-demo-home-dark.png; do
  if [[ ! -s "$SCREENSHOT_DIR/$screenshot" ]]; then
    screenshots_missing=1
  fi
done

if [[ "$CAPTURE_SCREENSHOTS" == "1" || ( "$CAPTURE_SCREENSHOTS" == "auto" && "$screenshots_missing" == "1" ) ]]; then
  bash Scripts/capture_demo_screenshots.sh
fi

for screenshot in calpal-demo-home.png calpal-demo-home-dark.png; do
  path="$SCREENSHOT_DIR/$screenshot"
  if [[ ! -s "$path" ]]; then
    echo "Missing non-empty screenshot artifact: $path" >&2
    echo "Run CAPTURE_SCREENSHOTS=1 bash Scripts/run_v10_release_gate.sh or bash Scripts/capture_demo_screenshots.sh." >&2
    exit 1
  fi
  dimensions="$(sips -g pixelWidth -g pixelHeight "$path")"
  if ! grep -q "pixelWidth:" <<<"$dimensions" || ! grep -q "pixelHeight:" <<<"$dimensions"; then
    echo "Could not read screenshot dimensions for $path" >&2
    exit 1
  fi
  width="$(awk '/pixelWidth:/ { print $2 }' <<<"$dimensions")"
  height="$(awk '/pixelHeight:/ { print $2 }' <<<"$dimensions")"
  if (( width < 390 || height < 800 )); then
    echo "Screenshot artifact is too small for App Store review evidence: $path is ${width}x${height}." >&2
    exit 1
  fi
done

echo "CalPal 1.0 local release gate passed."
