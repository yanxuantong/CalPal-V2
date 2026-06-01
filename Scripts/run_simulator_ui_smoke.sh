#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/CalPalUISmokeTests}"

cd "$ROOT_DIR"

xcodebuild \
  test \
  -project CalPal.xcodeproj \
  -scheme CalPal \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:CalPalUITests/CalPalSmokeUITests

echo "Simulator UI smoke passed."
