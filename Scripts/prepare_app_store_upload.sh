#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/AppStore/ExportOptions-AppStore.plist}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/Artifacts/AppStoreUpload}"
DRY_RUN="${DRY_RUN:-1}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"

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

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$EXPORT_OPTIONS_PLIST" 2>/dev/null || true
}

print_command() {
  printf '  %q' "$@"
  printf '\n'
}

[[ "$DRY_RUN" == "0" || "$DRY_RUN" == "1" ]] || fail "DRY_RUN must be 0 or 1."
[[ "$ALLOW_PROVISIONING_UPDATES" == "0" || "$ALLOW_PROVISIONING_UPDATES" == "1" ]] || fail "ALLOW_PROVISIONING_UPDATES must be 0 or 1."
[[ -f "$EXPORT_OPTIONS_PLIST" ]] || fail "Missing export options plist: $EXPORT_OPTIONS_PLIST"
plutil -lint "$EXPORT_OPTIONS_PLIST" >/dev/null

version="$(project_setting MARKETING_VERSION)"
build="$(project_setting CURRENT_PROJECT_VERSION)"
bundle_id="$(project_setting PRODUCT_BUNDLE_IDENTIFIER)"
team_id="$(project_setting DEVELOPMENT_TEAM)"

[[ -n "$version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."
[[ -n "$bundle_id" ]] || fail "Could not read PRODUCT_BUNDLE_IDENTIFIER from CalPal.xcodeproj."
[[ -n "$team_id" ]] || fail "Could not read DEVELOPMENT_TEAM from CalPal.xcodeproj."

[[ "$(plist_value method)" == "app-store-connect" ]] || fail "Export options method must be app-store-connect."
[[ "$(plist_value destination)" == "upload" ]] || fail "Export options destination must be upload."
[[ "$(plist_value manageAppVersionAndBuildNumber)" == "false" ]] || fail "Export options must keep manageAppVersionAndBuildNumber false so project build $build is preserved."
[[ "$(plist_value teamID)" == "$team_id" ]] || fail "Export options teamID must match project DEVELOPMENT_TEAM $team_id."

archive_path="$OUTPUT_DIR/CalPal-${version}-${build}.xcarchive"

archive_command=(
  xcodebuild
  archive
  -project CalPal.xcodeproj
  -scheme CalPal
  -configuration Release
  -destination generic/platform=iOS
  -archivePath "$archive_path"
  DEVELOPMENT_TEAM="$team_id"
  SKIP_INSTALL=NO
)

upload_command=(
  xcodebuild
  -exportArchive
  -archivePath "$archive_path"
  -exportPath "$OUTPUT_DIR"
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
  archive_command+=(-allowProvisioningUpdates)
  upload_command+=(-allowProvisioningUpdates)
fi

if [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" || -n "${APP_STORE_CONNECT_KEY_ID:-}" || -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" ]] || fail "APP_STORE_CONNECT_KEY_PATH is required when using App Store Connect API key authentication."
  [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" ]] || fail "APP_STORE_CONNECT_KEY_ID is required when using App Store Connect API key authentication."
  [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || fail "APP_STORE_CONNECT_ISSUER_ID is required when using App Store Connect API key authentication."
  [[ -f "$APP_STORE_CONNECT_KEY_PATH" ]] || fail "Missing App Store Connect API key file: $APP_STORE_CONNECT_KEY_PATH"
  archive_command+=(
    -authenticationKeyPath "$APP_STORE_CONNECT_KEY_PATH"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
  upload_command+=(
    -authenticationKeyPath "$APP_STORE_CONNECT_KEY_PATH"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
fi

echo "Prepared CalPal App Store upload commands for $bundle_id version $version build $build."
echo "Archive path: $archive_path"
echo "Export options: $EXPORT_OPTIONS_PLIST"
echo "Archive command:"
print_command "${archive_command[@]}"
echo "Upload command:"
print_command "${upload_command[@]}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run only. Re-run with DRY_RUN=0 after the local release gate, signed account, and external release evidence process are ready."
  exit 0
fi

mkdir -p "$OUTPUT_DIR"
"${archive_command[@]}"
"${upload_command[@]}"

echo "App Store upload command completed for CalPal $version ($build). Record the App Store Connect processing evidence in AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md."
