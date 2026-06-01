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
[[ -n "$version" && -n "$build" ]]

complete_evidence="$(mktemp)"
wrong_build_evidence="$(mktemp)"
missing_artifact_evidence="$(mktemp)"
missing_support_url_evidence="$(mktemp)"
wrong_metadata_url_evidence="$(mktemp)"
example_url_evidence="$(mktemp)"
missing_metadata_reviewer_evidence="$(mktemp)"
missing_metadata_reviewer_artifact="$(mktemp)"
wrong_privacy_build_evidence="$(mktemp)"
wrong_privacy_build_artifact="$(mktemp)"
bad_privacy_date_evidence="$(mktemp)"
bad_privacy_date_artifact="$(mktemp)"
incomplete_testflight_pointer_evidence="$(mktemp)"
incomplete_testflight_evidence="$(mktemp)"
missing_testflight_checklist_pointer_evidence="$(mktemp)"
missing_testflight_checklist_evidence="$(mktemp)"
missing_public_checklist_evidence="$(mktemp)"
wrong_signed_upload_location_evidence="$(mktemp)"
bad_local_gate_pointer_evidence="$(mktemp)"
bad_local_gate_artifact="$(mktemp)"
local_gate_artifact="$(mktemp)"
signed_upload_artifact="$(mktemp)"
testflight_artifact="$(mktemp)"
screenshots_artifact="$(mktemp)"
metadata_artifact="$(mktemp)"
wrong_metadata_url_artifact="$(mktemp)"
privacy_answers_artifact="$(mktemp)"
repo_local_gate_artifact="$ROOT_DIR/AppStore/SmokeTests/.tmp-public-release-local-gate-$$.md"
repo_signed_upload_artifact="$ROOT_DIR/AppStore/ReleaseEvidence/.tmp-public-release-signed-upload-$$.md"
repo_testflight_artifact="$ROOT_DIR/AppStore/SmokeTests/.tmp-public-release-testflight-$$.md"
repo_screenshots_artifact="$ROOT_DIR/AppStore/ReleaseEvidence/.tmp-public-release-screenshots-$$.md"
repo_metadata_artifact="$ROOT_DIR/AppStore/ReleaseEvidence/.tmp-public-release-metadata-$$.md"
repo_privacy_answers_artifact="$ROOT_DIR/AppStore/ReleaseEvidence/.tmp-public-release-privacy-answers-$$.md"
repo_wrong_signed_upload_artifact="$ROOT_DIR/Artifacts/AppStoreUpload/.tmp-public-release-signed-upload-$$.md"
trap 'rm -f "$complete_evidence" "$wrong_build_evidence" "$missing_artifact_evidence" "$missing_support_url_evidence" "$wrong_metadata_url_evidence" "$example_url_evidence" "$missing_metadata_reviewer_evidence" "$missing_metadata_reviewer_artifact" "$wrong_privacy_build_evidence" "$wrong_privacy_build_artifact" "$bad_privacy_date_evidence" "$bad_privacy_date_artifact" "$incomplete_testflight_pointer_evidence" "$incomplete_testflight_evidence" "$missing_testflight_checklist_pointer_evidence" "$missing_testflight_checklist_evidence" "$missing_public_checklist_evidence" "$wrong_signed_upload_location_evidence" "$bad_local_gate_pointer_evidence" "$bad_local_gate_artifact" "$local_gate_artifact" "$signed_upload_artifact" "$testflight_artifact" "$screenshots_artifact" "$metadata_artifact" "$wrong_metadata_url_artifact" "$missing_metadata_reviewer_artifact" "$wrong_privacy_build_artifact" "$bad_privacy_date_artifact" "$privacy_answers_artifact" "$repo_local_gate_artifact" "$repo_signed_upload_artifact" "$repo_testflight_artifact" "$repo_screenshots_artifact" "$repo_metadata_artifact" "$repo_privacy_answers_artifact" "$repo_wrong_signed_upload_artifact"' EXIT

cat >"$local_gate_artifact" <<EOF
# CalPal $version Local Release Gate Evidence

Build: $build
Date: 2026-05-31
Environment: iPhone 17 Simulator, local unsigned archive build

## Commands

\`\`\`bash
CAPTURE_SCREENSHOTS=0 bash Scripts/run_v10_release_gate.sh
\`\`\`

## Result

- Local 1.0 release gate: PASS
- Unsigned archive verification: PASS

## Remaining Public-Release Evidence

This artifact does not prove the external public App Store gates. The final release record still needs signed App Store Connect upload evidence, TestFlight real-device smoke evidence, public privacy-policy URL, final screenshot review, and App Store Connect metadata/privacy-answer confirmation.
EOF

cat >"$signed_upload_artifact" <<EOF
# CalPal $version Signed Upload Evidence

Result: PASS
Build: $build
Date: 2026-05-31
Archive path: /tmp/CalPal.xcarchive
Upload method: xcodebuild -exportArchive
App Store Connect evidence: Build processing record
Uploader: Release owner

- [x] Upload completed.
- [x] \`DRY_RUN=0 bash Scripts/prepare_app_store_upload.sh\` completed without error.
- [x] The uploaded build number matches the Xcode project build.
- [x] App Store Connect shows the build as uploaded or processing.
- [x] No unexpected export, signing, validation, or upload warnings remain.
EOF

cat >"$testflight_artifact" <<EOF
# CalPal $version TestFlight Real-Device Smoke Evidence

Result: PASS
Build: $build
Date: 2026-05-31
Device: iPhone 15 Pro
iOS version: iOS 26.5
Tester: Release owner
TestFlight build evidence: App Store Connect build processing record

- [x] Fresh install, first launch, onboarding completes.
- [x] Calendar Full Access, Speech Recognition, and Microphone permissions can be granted.
- [x] Settings readiness shows Calendar access and Writable calendar as ready.
- [x] Settings readiness shows Privacy manifest as ready.
- [x] Voice create works for: "Meeting with Alex tomorrow at 3 PM."
- [x] The created event appears in CalPal.
- [x] The created event appears in Apple Calendar.
- [x] Result card Open in Calendar opens Apple Calendar near the event date.
- [x] Text create works for: "明天下午三点和 Alex 开会."
- [x] Event detail sheet opens from the agenda.
- [x] Event detail title or location update can be staged and reviewed before save.
- [x] Modify flows require review.
- [x] Delete flows require review.
- [x] Recurring-event modify/delete flows require recurrence scope selection.
- [x] Speech denied or unavailable state still leaves text/manual fallbacks usable.
- [x] Light Mode reviewed on device.
- [x] Dark Mode reviewed on device.
- [x] Dynamic Type reviewed on device.
- [x] Reduce Motion reviewed on device.
- [x] Reduce Transparency reviewed on device.
EOF

cat >"$screenshots_artifact" <<EOF
# CalPal $version Final Screenshot Review Evidence

Result: PASS
Build: $build
Date: 2026-05-31
Reviewer: Release owner
Screenshot source: App Store Connect screenshot set
App Store Connect screenshot evidence: Screenshot review record

- [x] Final screenshots reviewed.
- [x] Required iPhone screenshot sizes are uploaded or intentionally covered by App Store Connect scaling rules.
- [x] Light Mode screenshots show readable agenda content.
- [x] Dark Mode screenshots show readable agenda content.
- [x] Captions and visible UI match the 1.0 product promise.
- [x] No simulator-only debug overlays, placeholder text, private calendar content, or broken layout appears.
- [x] Final screenshots match the metadata draft in \`AppStore/APP_STORE_CONNECT_SUBMISSION.md\`.
EOF

cat >"$metadata_artifact" <<EOF
# CalPal $version App Store Connect Metadata Evidence

Result: PASS
Build: $build
Date: 2026-05-31
Reviewer: Release owner
Public support URL: https://calpal.app/support
Public marketing URL: https://calpal.app
App Store Connect evidence: Product page review record

- [x] Metadata reviewed.
- [x] Name, subtitle, description, keywords, support URL, and marketing URL are final.
- [x] Review notes match \`AppStore/APP_STORE_CONNECT_SUBMISSION.md\`.
- [x] TestFlight notes match the final real-device smoke plan.
- [x] Permission purpose strings in App Store Connect align with the app bundle.
- [x] No metadata claims a backend, analytics, tracking, or full calendar replacement behavior that 1.0 does not ship.
EOF

cat >"$privacy_answers_artifact" <<EOF
# CalPal $version App Store Privacy Answers Evidence

Result: PASS
Build: $build
Date: 2026-05-31
Reviewer: Release owner
Public privacy policy URL: https://calpal.app/privacy
App Store Connect evidence: Privacy answers screenshot

- [x] Privacy answers reviewed.
- [x] Public privacy policy URL is live over HTTPS.
- [x] App Store Connect privacy answers say the developer does not collect data from this app.
- [x] Tracking is set to No.
- [x] No data linked to the user is selected.
- [x] No data not linked to the user is selected.
- [x] Answers match the 1.0 runtime boundary: no developer backend, no telemetry export, no third-party analytics SDK, and no tracking.
EOF

cat >"$complete_evidence" <<EOF
# CalPal $version Public Release Evidence

Version: $version
Build: $build

Local release gate result: PASS
Local release gate command: bash Scripts/run_v10_release_gate.sh
Local release gate date: 2026-05-31
Local release gate artifact: $local_gate_artifact

Signed archive upload result: PASS
Signed archive upload build: $build
Signed archive upload date: 2026-05-31
Signed archive upload evidence: $signed_upload_artifact

TestFlight real-device smoke result: PASS
TestFlight real-device smoke device: iPhone 15 Pro
TestFlight real-device smoke iOS version: iOS 26.5
TestFlight real-device smoke date: 2026-05-31
TestFlight real-device smoke evidence: $testflight_artifact

Public privacy policy URL: https://calpal.app/privacy
Public support URL: https://calpal.app/support
Public marketing URL: https://calpal.app

Final screenshot review result: PASS
Final screenshot review date: 2026-05-31
Final screenshot review evidence: $screenshots_artifact

App Store Connect metadata result: PASS
App Store Connect metadata evidence: $metadata_artifact
App Store Connect privacy answers result: PASS
App Store Connect privacy answers evidence: $privacy_answers_artifact

Open release blockers: NONE

- [x] Fresh install, first launch, onboarding completes.
- [x] Calendar Full Access, Speech Recognition, and Microphone permissions can be granted.
- [x] Settings readiness shows Calendar access and Writable calendar as ready.
- [x] Settings readiness shows Privacy manifest as ready.
- [x] Voice create works for: "Meeting with Alex tomorrow at 3 PM."
- [x] The created event appears in CalPal.
- [x] The created event appears in Apple Calendar.
- [x] Result card Open in Calendar opens Apple Calendar near the event date.
- [x] Text create works for: "明天下午三点和 Alex 开会."
- [x] Event detail sheet opens from the agenda.
- [x] Event detail title or location update can be staged and reviewed before save.
- [x] Modify flows require review.
- [x] Delete flows require review.
- [x] Recurring-event modify/delete flows require recurrence scope selection.
- [x] Speech denied or unavailable state still leaves text/manual fallbacks usable.
- [x] Light Mode reviewed on device.
- [x] Dark Mode reviewed on device.
- [x] Dynamic Type reviewed on device.
- [x] Reduce Motion reviewed on device.
- [x] Reduce Transparency reviewed on device.
EOF

if EVIDENCE_FILE="$complete_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject external artifact paths by default." >&2
  exit 1
fi

ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$complete_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null

mkdir -p "$(dirname "$repo_local_gate_artifact")" "$(dirname "$repo_signed_upload_artifact")" "$(dirname "$repo_testflight_artifact")" "$(dirname "$repo_screenshots_artifact")" "$(dirname "$repo_metadata_artifact")" "$(dirname "$repo_privacy_answers_artifact")" "$(dirname "$repo_wrong_signed_upload_artifact")"
cp "$local_gate_artifact" "$repo_local_gate_artifact"
cp "$signed_upload_artifact" "$repo_signed_upload_artifact"
cp "$testflight_artifact" "$repo_testflight_artifact"
cp "$screenshots_artifact" "$repo_screenshots_artifact"
cp "$metadata_artifact" "$repo_metadata_artifact"
cp "$privacy_answers_artifact" "$repo_privacy_answers_artifact"
cp "$signed_upload_artifact" "$repo_wrong_signed_upload_artifact"
sed \
  -e "s|^Local release gate artifact: $local_gate_artifact$|Local release gate artifact: ${repo_local_gate_artifact#$ROOT_DIR/}|" \
  -e "s|^Signed archive upload evidence: $signed_upload_artifact$|Signed archive upload evidence: ${repo_signed_upload_artifact#$ROOT_DIR/}|" \
  -e "s|^TestFlight real-device smoke evidence: $testflight_artifact$|TestFlight real-device smoke evidence: ${repo_testflight_artifact#$ROOT_DIR/}|" \
  -e "s|^Final screenshot review evidence: $screenshots_artifact$|Final screenshot review evidence: ${repo_screenshots_artifact#$ROOT_DIR/}|" \
  -e "s|^App Store Connect metadata evidence: $metadata_artifact$|App Store Connect metadata evidence: ${repo_metadata_artifact#$ROOT_DIR/}|" \
  -e "s|^App Store Connect privacy answers evidence: $privacy_answers_artifact$|App Store Connect privacy answers evidence: ${repo_privacy_answers_artifact#$ROOT_DIR/}|" \
  "$complete_evidence" >"$wrong_signed_upload_location_evidence"
sed -i '' "s|^Signed archive upload evidence: ${repo_signed_upload_artifact#$ROOT_DIR/}$|Signed archive upload evidence: ${repo_wrong_signed_upload_artifact#$ROOT_DIR/}|" "$wrong_signed_upload_location_evidence"
if EVIDENCE_FILE="$wrong_signed_upload_location_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject repo-local signed upload evidence outside AppStore/ReleaseEvidence." >&2
  exit 1
fi

sed "s/^Signed archive upload build: $build$/Signed archive upload build: 999/" "$complete_evidence" >"$wrong_build_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$wrong_build_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject a signed upload build mismatch." >&2
  exit 1
fi

sed "s|^Local release gate artifact: $local_gate_artifact$|Local release gate artifact: /tmp/calpal-missing-local-gate-artifact|" "$complete_evidence" >"$missing_artifact_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$missing_artifact_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject a missing local release gate artifact." >&2
  exit 1
fi

sed "s/^Build: $build$/Build: 999/" "$local_gate_artifact" >"$bad_local_gate_artifact"
sed "s|^Local release gate artifact: $local_gate_artifact$|Local release gate artifact: $bad_local_gate_artifact|" "$complete_evidence" >"$bad_local_gate_pointer_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$bad_local_gate_pointer_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject local release gate artifact content that does not match the current build." >&2
  exit 1
fi

grep -v '^Public support URL:' "$complete_evidence" >"$missing_support_url_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$missing_support_url_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject missing public support URL evidence." >&2
  exit 1
fi

sed 's|^Public support URL: https://calpal.app/support$|Public support URL: https://calpal.app/other-support|' "$metadata_artifact" >"$wrong_metadata_url_artifact"
sed "s|^App Store Connect metadata evidence: $metadata_artifact$|App Store Connect metadata evidence: $wrong_metadata_url_artifact|" "$complete_evidence" >"$wrong_metadata_url_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$wrong_metadata_url_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject metadata support URL mismatch." >&2
  exit 1
fi

sed 's|^Public privacy policy URL: https://calpal.app/privacy$|Public privacy policy URL: https://example.com/calpal/privacy|' "$complete_evidence" >"$example_url_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$example_url_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject sample example.com URLs." >&2
  exit 1
fi

grep -v '^Reviewer:' "$metadata_artifact" >"$missing_metadata_reviewer_artifact"
sed "s|^App Store Connect metadata evidence: $metadata_artifact$|App Store Connect metadata evidence: $missing_metadata_reviewer_artifact|" "$complete_evidence" >"$missing_metadata_reviewer_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$missing_metadata_reviewer_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject metadata evidence without reviewer." >&2
  exit 1
fi

sed "s/^Build: $build$/Build: 999/" "$privacy_answers_artifact" >"$wrong_privacy_build_artifact"
sed "s|^App Store Connect privacy answers evidence: $privacy_answers_artifact$|App Store Connect privacy answers evidence: $wrong_privacy_build_artifact|" "$complete_evidence" >"$wrong_privacy_build_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$wrong_privacy_build_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject privacy-answer evidence for the wrong build." >&2
  exit 1
fi

sed 's/^Date: 2026-05-31$/Date: 05-31-2026/' "$privacy_answers_artifact" >"$bad_privacy_date_artifact"
sed "s|^App Store Connect privacy answers evidence: $privacy_answers_artifact$|App Store Connect privacy answers evidence: $bad_privacy_date_artifact|" "$complete_evidence" >"$bad_privacy_date_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$bad_privacy_date_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject malformed privacy-answer artifact date." >&2
  exit 1
fi

sed 's/^- \[x\] Calendar Full Access/- [ ] Calendar Full Access/' "$testflight_artifact" >"$incomplete_testflight_evidence"
sed "s|^TestFlight real-device smoke evidence: $testflight_artifact$|TestFlight real-device smoke evidence: $incomplete_testflight_evidence|" "$complete_evidence" >"$incomplete_testflight_pointer_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$incomplete_testflight_pointer_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject incomplete TestFlight real-device smoke evidence." >&2
  exit 1
fi

grep -v '^\- \[x\] Reduce Transparency reviewed on device\.$' "$testflight_artifact" >"$missing_testflight_checklist_evidence"
sed "s|^TestFlight real-device smoke evidence: $testflight_artifact$|TestFlight real-device smoke evidence: $missing_testflight_checklist_evidence|" "$complete_evidence" >"$missing_testflight_checklist_pointer_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$missing_testflight_checklist_pointer_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject TestFlight evidence with an omitted required checklist item." >&2
  exit 1
fi

grep -v '^\- \[x\] Dynamic Type reviewed on device\.$' "$complete_evidence" >"$missing_public_checklist_evidence"
if ALLOW_EXTERNAL_RELEASE_ARTIFACTS=1 EVIDENCE_FILE="$missing_public_checklist_evidence" bash Scripts/verify_public_release_readiness.sh >/dev/null 2>&1; then
  echo "Expected public release verifier to reject a public evidence summary with an omitted required real-device checklist item." >&2
  exit 1
fi

echo "Public release readiness verifier self-test passed."
