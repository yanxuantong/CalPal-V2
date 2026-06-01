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
bash -n Scripts/test_app_store_metadata_verifier.sh
bash -n Scripts/verify_archive_build.sh
bash -n Scripts/test_archive_build_verifier.sh
bash -n Scripts/verify_smoke_automation_contract.sh
bash -n Scripts/test_smoke_automation_contract_verifier.sh
bash -n Scripts/verify_public_release_readiness.sh
bash -n Scripts/test_public_release_readiness_verifier.sh
bash -n Scripts/run_simulator_ui_smoke.sh
bash -n Scripts/prepare_app_store_upload.sh
bash -n Scripts/test_prepare_app_store_upload.sh
bash -n Scripts/run_app_store_submission_preflight.sh
bash -n Scripts/test_app_store_submission_preflight.sh
bash -n Scripts/verify_public_privacy_policy_artifact.sh
bash -n Scripts/test_public_privacy_policy_artifact.sh
bash -n Scripts/verify_public_support_page_artifact.sh
bash -n Scripts/test_public_support_page_artifact.sh
bash -n Scripts/verify_public_static_artifacts.sh
bash -n Scripts/test_public_static_artifacts_verifier.sh
bash -n Scripts/verify_public_url_publication.sh
bash -n Scripts/test_public_url_publication_verifier.sh
bash -n Scripts/verify_app_store_submission_consistency.sh
bash -n Scripts/test_app_store_submission_consistency.sh
bash -n Scripts/verify_app_store_metadata_fields.sh
bash -n Scripts/test_app_store_metadata_fields.sh
bash -n Scripts/verify_release_placeholder_boundaries.sh
bash -n Scripts/test_release_placeholder_boundaries.sh
bash -n Scripts/create_release_evidence_artifacts.sh
bash -n Scripts/test_release_evidence_artifact_generator.sh
bash -n Scripts/verify_local_only_runtime.sh
bash -n Scripts/test_local_only_runtime_verifier.sh
bash -n Scripts/verify_built_app_privacy_surface.sh
bash -n Scripts/test_built_app_privacy_surface.sh
bash -n Scripts/generate_release_handoff_report.sh
bash -n Scripts/generate_release_bundle_manifest.sh
bash -n Scripts/verify_canonical_release_gate.sh
bash -n Scripts/verify_demo_screenshot_artifacts.sh
bash -n Scripts/test_demo_screenshot_artifacts_verifier.sh

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
bash Scripts/test_app_store_metadata_verifier.sh
bash Scripts/verify_archive_build.sh
bash Scripts/test_archive_build_verifier.sh
bash Scripts/verify_smoke_automation_contract.sh
bash Scripts/test_smoke_automation_contract_verifier.sh
bash Scripts/test_public_release_readiness_verifier.sh
bash Scripts/prepare_app_store_upload.sh >/dev/null
bash Scripts/test_prepare_app_store_upload.sh
bash Scripts/run_app_store_submission_preflight.sh >/dev/null
bash Scripts/test_app_store_submission_preflight.sh
bash Scripts/verify_public_privacy_policy_artifact.sh
bash Scripts/test_public_privacy_policy_artifact.sh
bash Scripts/verify_public_support_page_artifact.sh
bash Scripts/test_public_support_page_artifact.sh
bash Scripts/verify_public_static_artifacts.sh
bash Scripts/test_public_static_artifacts_verifier.sh
bash Scripts/test_public_url_publication_verifier.sh
bash Scripts/verify_app_store_submission_consistency.sh
bash Scripts/test_app_store_submission_consistency.sh
bash Scripts/verify_app_store_metadata_fields.sh
bash Scripts/test_app_store_metadata_fields.sh
bash Scripts/verify_release_placeholder_boundaries.sh
bash Scripts/test_release_placeholder_boundaries.sh
bash Scripts/create_release_evidence_artifacts.sh --check --date 2026-05-31 >/dev/null
bash Scripts/test_release_evidence_artifact_generator.sh
bash Scripts/verify_local_only_runtime.sh
bash Scripts/test_local_only_runtime_verifier.sh
bash Scripts/verify_built_app_privacy_surface.sh
bash Scripts/test_built_app_privacy_surface.sh
bash Scripts/generate_release_handoff_report.sh --check
bash Scripts/generate_release_bundle_manifest.sh --check
bash Scripts/verify_canonical_release_gate.sh

screenshots_missing=0
for screenshot in calpal-demo-home.png calpal-demo-home-dark.png; do
  if [[ ! -s "$SCREENSHOT_DIR/$screenshot" ]]; then
    screenshots_missing=1
  fi
done

if [[ "$CAPTURE_SCREENSHOTS" == "1" || ( "$CAPTURE_SCREENSHOTS" == "auto" && "$screenshots_missing" == "1" ) ]]; then
  bash Scripts/capture_demo_screenshots.sh
fi

bash Scripts/verify_demo_screenshot_artifacts.sh
bash Scripts/test_demo_screenshot_artifacts_verifier.sh

echo "CalPal 1.0 local release gate passed."
