#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL_GATE="$ROOT_DIR/Scripts/run_v10_release_gate.sh"
LEGACY_GATE="$ROOT_DIR/Scripts/run_v03_release_gate.sh"

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

version="$(project_setting MARKETING_VERSION)"
build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."

[[ "$version" == "1.0" ]] || fail "Canonical release gate expects active version 1.0, found $version."
[[ "$build" == "10" ]] || fail "Canonical release gate expects active build 10, found $build."

[[ -s "$CANONICAL_GATE" ]] || fail "Missing canonical release gate: Scripts/run_v10_release_gate.sh"
[[ -s "$LEGACY_GATE" ]] || fail "Missing legacy release gate shim: Scripts/run_v03_release_gate.sh"

if ! grep -Fq 'CalPal 1.0 local release gate passed.' "$CANONICAL_GATE"; then
  fail "Canonical gate must report the CalPal 1.0 release gate."
fi

for required in \
  "verify_app_store_metadata.sh" \
  "test_app_store_metadata_verifier.sh" \
  "verify_archive_build.sh" \
  "test_archive_build_verifier.sh" \
  "verify_smoke_automation_contract.sh" \
  "test_smoke_automation_contract_verifier.sh" \
  "test_public_release_readiness_verifier.sh" \
  "prepare_app_store_upload.sh" \
  "test_prepare_app_store_upload.sh" \
  "run_app_store_submission_preflight.sh" \
  "test_app_store_submission_preflight.sh" \
  "verify_public_privacy_policy_artifact.sh" \
  "test_public_privacy_policy_artifact.sh" \
  "verify_public_support_page_artifact.sh" \
  "test_public_support_page_artifact.sh" \
  "verify_public_static_artifacts.sh" \
  "test_public_static_artifacts_verifier.sh" \
  "verify_public_url_publication.sh" \
  "test_public_url_publication_verifier.sh" \
  "verify_app_store_submission_consistency.sh" \
  "test_app_store_submission_consistency.sh" \
  "verify_app_store_metadata_fields.sh" \
  "test_app_store_metadata_fields.sh" \
  "verify_demo_screenshot_artifacts.sh" \
  "test_demo_screenshot_artifacts_verifier.sh" \
  "create_release_evidence_artifacts.sh --check" \
  "test_release_evidence_artifact_generator.sh" \
  "verify_local_only_runtime.sh" \
  "test_local_only_runtime_verifier.sh" \
  "generate_release_handoff_report.sh --check" \
  "generate_release_bundle_manifest.sh --check"; do
  if ! grep -Fq "$required" "$CANONICAL_GATE"; then
    fail "Canonical gate is missing required check: $required"
  fi
done

if ! grep -Fq 'run_v03_release_gate.sh is deprecated' "$LEGACY_GATE"; then
  fail "Legacy v0.3 gate must clearly announce deprecation."
fi

if ! grep -Fq 'exec "$ROOT_DIR/Scripts/run_v10_release_gate.sh" "$@"' "$LEGACY_GATE"; then
  fail "Legacy v0.3 gate must delegate to the canonical 1.0 gate."
fi

if grep -Eq 'xcodebuild|verify_app_store_metadata|verify_archive_build|capture_demo_screenshots' "$LEGACY_GATE"; then
  fail "Legacy v0.3 gate must remain a thin shim, not a second release gate implementation."
fi

echo "Canonical release gate verified for CalPal $version build $build."
