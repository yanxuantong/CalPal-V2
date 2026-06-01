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
team_id="$(project_setting DEVELOPMENT_TEAM)"
[[ -n "$version" && -n "$build" && -n "$team_id" ]]

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

valid_plist="$tmpdir/ExportOptions-AppStore.plist"
output="$tmpdir/prepare-output.txt"
cp AppStore/ExportOptions-AppStore.plist "$valid_plist"

EXPORT_OPTIONS_PLIST="$valid_plist" OUTPUT_DIR="$tmpdir/upload" bash Scripts/prepare_app_store_upload.sh >"$output"

if ! grep -Fq "Prepared CalPal App Store upload commands" "$output"; then
  echo "Expected upload preparation to print prepared command summary." >&2
  exit 1
fi

if ! grep -Fq "Archive path: $tmpdir/upload/CalPal-$version-$build.xcarchive" "$output"; then
  echo "Expected upload preparation to include the current version/build archive path." >&2
  exit 1
fi

if DRY_RUN=maybe EXPORT_OPTIONS_PLIST="$valid_plist" bash Scripts/prepare_app_store_upload.sh >/dev/null 2>&1; then
  echo "Expected upload preparation to reject invalid DRY_RUN values." >&2
  exit 1
fi

if EXPORT_OPTIONS_PLIST="$tmpdir/missing.plist" bash Scripts/prepare_app_store_upload.sh >/dev/null 2>&1; then
  echo "Expected upload preparation to reject missing export options plist." >&2
  exit 1
fi

bad_method="$tmpdir/bad-method.plist"
cp "$valid_plist" "$bad_method"
/usr/libexec/PlistBuddy -c "Set :method development" "$bad_method"
if EXPORT_OPTIONS_PLIST="$bad_method" bash Scripts/prepare_app_store_upload.sh >/dev/null 2>&1; then
  echo "Expected upload preparation to reject non-App Store Connect export method." >&2
  exit 1
fi

bad_manage="$tmpdir/bad-manage-version.plist"
cp "$valid_plist" "$bad_manage"
/usr/libexec/PlistBuddy -c "Set :manageAppVersionAndBuildNumber true" "$bad_manage"
if EXPORT_OPTIONS_PLIST="$bad_manage" bash Scripts/prepare_app_store_upload.sh >/dev/null 2>&1; then
  echo "Expected upload preparation to reject managed App Store version/build numbers." >&2
  exit 1
fi

bad_team="$tmpdir/bad-team.plist"
cp "$valid_plist" "$bad_team"
/usr/libexec/PlistBuddy -c "Set :teamID NOT$team_id" "$bad_team"
if EXPORT_OPTIONS_PLIST="$bad_team" bash Scripts/prepare_app_store_upload.sh >/dev/null 2>&1; then
  echo "Expected upload preparation to reject export options with the wrong team ID." >&2
  exit 1
fi

if APP_STORE_CONNECT_KEY_PATH="$tmpdir/AuthKey_TEST.p8" EXPORT_OPTIONS_PLIST="$valid_plist" bash Scripts/prepare_app_store_upload.sh >/dev/null 2>&1; then
  echo "Expected upload preparation to reject incomplete App Store Connect API key authentication." >&2
  exit 1
fi

echo "App Store upload preparation self-test passed."
