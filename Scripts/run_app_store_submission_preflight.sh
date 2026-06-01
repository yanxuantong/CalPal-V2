#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_FILE="${EVIDENCE_FILE:-$ROOT_DIR/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md}"
RUN_LOCAL_GATE="${RUN_LOCAL_GATE:-0}"
REQUIRE_PUBLIC_READY="${REQUIRE_PUBLIC_READY:-0}"
CREATE_EVIDENCE_SKELETONS="${CREATE_EVIDENCE_SKELETONS:-0}"
TODAY="${TODAY:-$(date +%F)}"

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

field_value() {
  local field="$1"
  awk -F': ' -v field="$field" '$1 == field { print $2 }' "$EVIDENCE_FILE"
}

print_pending_fields() {
  awk -F': ' '$2 == "TODO" { print "- " $1 }' "$EVIDENCE_FILE"
}

print_unchecked_items() {
  awk '/^- \[ \]/ { sub(/^- \[ \] /, "- "); print }' "$EVIDENCE_FILE"
}

run_local_material_check() {
  local label="$1"
  shift

  if "$@" >/dev/null; then
    echo "$label: PASS"
    return
  fi

  echo "$label: FAIL" >&2
  "$@"
}

public_urls_are_filled() {
  local field value
  for field in "Public privacy policy URL" "Public support URL" "Public marketing URL"; do
    value="$(field_value "$field")"
    if [[ -z "$value" || "$value" == "TODO" ]]; then
      return 1
    fi
  done
}

expected_skeletons=(
  "AppStore/ReleaseEvidence/$TODAY-signed-upload.md"
  "AppStore/SmokeTests/$TODAY-testflight-real-device-smoke.md"
  "AppStore/ReleaseEvidence/$TODAY-screenshot-review.md"
  "AppStore/ReleaseEvidence/$TODAY-app-store-connect-metadata.md"
  "AppStore/ReleaseEvidence/$TODAY-app-store-privacy-answers.md"
)

missing_skeletons() {
  local path
  for path in "${expected_skeletons[@]}"; do
    if [[ ! -e "$path" ]]; then
      printf '%s\n' "$path"
    fi
  done
}

[[ "$RUN_LOCAL_GATE" == "0" || "$RUN_LOCAL_GATE" == "1" ]] || fail "RUN_LOCAL_GATE must be 0 or 1."
[[ "$REQUIRE_PUBLIC_READY" == "0" || "$REQUIRE_PUBLIC_READY" == "1" ]] || fail "REQUIRE_PUBLIC_READY must be 0 or 1."
[[ "$CREATE_EVIDENCE_SKELETONS" == "0" || "$CREATE_EVIDENCE_SKELETONS" == "1" ]] || fail "CREATE_EVIDENCE_SKELETONS must be 0 or 1."
[[ -f "$EVIDENCE_FILE" ]] || fail "Missing public release evidence file: $EVIDENCE_FILE"

version="$(project_setting MARKETING_VERSION)"
build="$(project_setting CURRENT_PROJECT_VERSION)"
bundle_id="$(project_setting PRODUCT_BUNDLE_IDENTIFIER)"
team_id="$(project_setting DEVELOPMENT_TEAM)"

[[ -n "$version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."
[[ -n "$bundle_id" ]] || fail "Could not read PRODUCT_BUNDLE_IDENTIFIER from CalPal.xcodeproj."
[[ -n "$team_id" ]] || fail "Could not read DEVELOPMENT_TEAM from CalPal.xcodeproj."

echo "CalPal App Store submission preflight"
echo "Version: $version"
echo "Build: $build"
echo "Bundle ID: $bundle_id"
echo "Team ID: $team_id"
echo "Evidence file: ${EVIDENCE_FILE#$ROOT_DIR/}"
echo

missing_before_create="$(missing_skeletons)"
if [[ -n "$missing_before_create" && "$CREATE_EVIDENCE_SKELETONS" == "1" ]]; then
  echo "Creating missing dated evidence skeletons for $TODAY..."
  bash Scripts/create_release_evidence_artifacts.sh --date "$TODAY"
  echo
fi

if [[ "$RUN_LOCAL_GATE" == "1" ]]; then
  echo "Running local release gate..."
  CAPTURE_SCREENSHOTS="${CAPTURE_SCREENSHOTS:-0}" bash Scripts/run_v10_release_gate.sh
  echo "Local release gate: PASS"
else
  echo "Local release gate: SKIPPED (set RUN_LOCAL_GATE=1 to run it here)"
fi

echo
echo "Local submission material checks:"
run_local_material_check "Public static artifacts" bash Scripts/verify_public_static_artifacts.sh
run_local_material_check "App Store material consistency" bash Scripts/verify_app_store_submission_consistency.sh
run_local_material_check "App Store metadata field limits" bash Scripts/verify_app_store_metadata_fields.sh
run_local_material_check "Release placeholder boundaries" bash Scripts/verify_release_placeholder_boundaries.sh

echo
if public_urls_are_filled; then
  run_local_material_check "Published public URLs" env EVIDENCE_FILE="$EVIDENCE_FILE" bash Scripts/verify_public_url_publication.sh
else
  echo "Published public URLs: SKIPPED (fill public privacy/support/marketing URLs before final submission)"
fi

upload_output="$(mktemp)"
public_ready_output="$(mktemp)"
trap 'rm -f "$upload_output" "$public_ready_output"' EXIT

echo
if bash Scripts/prepare_app_store_upload.sh >"$upload_output" 2>&1; then
  echo "Upload dry-run: PASS"
  grep -E '^(Prepared|Archive path:|Export options:)' "$upload_output" || true
else
  cat "$upload_output" >&2
  fail "Upload dry-run: FAIL"
fi

echo
if EVIDENCE_FILE="$EVIDENCE_FILE" bash Scripts/verify_public_release_readiness.sh >"$public_ready_output" 2>&1; then
  echo "Public release status: READY"
  cat "$public_ready_output"
  exit 0
fi

echo "Public release status: EXTERNAL ACTIONS REQUIRED"
sed -n '1p' "$public_ready_output"
echo
echo "Pending evidence fields:"
pending_fields="$(print_pending_fields)"
if [[ -n "$pending_fields" ]]; then
  printf '%s\n' "$pending_fields"
else
  echo "- None found in top-level fields; inspect the failure above."
fi

unchecked_items="$(print_unchecked_items)"
if [[ -n "$unchecked_items" ]]; then
  echo
  echo "Unchecked real-device smoke items:"
  printf '%s\n' "$unchecked_items"
fi

echo
echo "Dated evidence skeletons for $TODAY:"
missing_after_create="$(missing_skeletons)"
for path in "${expected_skeletons[@]}"; do
  if [[ -e "$path" ]]; then
    echo "- $path"
  fi
done

if [[ -n "$missing_after_create" ]]; then
  echo
  echo "Missing dated evidence skeletons:"
  printf '%s\n' "$missing_after_create" | sed 's/^/- /'
  echo "Create them with: bash Scripts/create_release_evidence_artifacts.sh --date $TODAY"
fi

cat <<'EOF'

Next owner actions:
1. Publish AppStore/Public/privacy.html and AppStore/Public/support.html to public HTTPS URLs.
2. Run DRY_RUN=0 bash Scripts/prepare_app_store_upload.sh when Apple signing/App Store Connect credentials are ready.
3. Install the uploaded TestFlight build on a physical iPhone and complete the real-device smoke checklist.
4. Fill App Store Connect metadata, screenshots, and privacy answers from AppStore/APP_STORE_CONNECT_SUBMISSION.md.
5. Replace TODO values in AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md with completed dated evidence artifacts.
6. Run bash Scripts/verify_public_release_readiness.sh and submit only after it passes.
EOF

if [[ "$REQUIRE_PUBLIC_READY" == "1" ]]; then
  exit 1
fi
