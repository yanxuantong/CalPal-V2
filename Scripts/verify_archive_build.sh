#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/CalPalV10ArchiveDerivedData}"
ARCHIVE_PATH="${ARCHIVE_PATH:-/tmp/CalPalV10Unsigned.xcarchive}"

cd "$ROOT_DIR"

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

APP_PATH="$ARCHIVE_PATH/Products/Applications/CalPal.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Archive did not contain CalPal.app at $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$APP_PATH/PrivacyInfo.xcprivacy" ]]; then
  echo "Archive app is missing PrivacyInfo.xcprivacy." >&2
  exit 1
fi

echo "Unsigned archive build verified at $ARCHIVE_PATH"
