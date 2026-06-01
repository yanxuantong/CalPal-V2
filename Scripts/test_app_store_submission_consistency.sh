#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

required_docs=(
  "AppStore/APP_STORE_CONNECT_SUBMISSION.md"
  "AppStore/APP_STORE_READINESS.md"
  "AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
  "AppStore/PRIVACY_POLICY.md"
  "AppStore/Public/privacy.html"
  "AppStore/Public/support.html"
  "AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
  "AppStore/ReleaseEvidence/LOCAL_RELEASE_BUNDLE_MANIFEST.md"
)

make_fixture() {
  local dir="$1"
  for doc in "${required_docs[@]}"; do
    mkdir -p "$dir/$(dirname "$doc")"
    cp "$doc" "$dir/$doc"
  done
}

valid_dir="$tmp_root/valid"
wrong_build_dir="$tmp_root/wrong-build"
missing_privacy_claim_dir="$tmp_root/missing-privacy-claim"
missing_support_claim_dir="$tmp_root/missing-support-claim"
missing_public_artifact_pointer_dir="$tmp_root/missing-public-artifact-pointer"
missing_handoff_warning_dir="$tmp_root/missing-handoff-warning"

make_fixture "$valid_dir"
DOC_ROOT="$valid_dir" bash Scripts/verify_app_store_submission_consistency.sh >/dev/null

make_fixture "$wrong_build_dir"
perl -0pi -e 's/Build: 10/Build: 999/' "$wrong_build_dir/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
if DOC_ROOT="$wrong_build_dir" bash Scripts/verify_app_store_submission_consistency.sh >/dev/null 2>&1; then
  echo "Expected App Store submission consistency verifier to reject build drift." >&2
  exit 1
fi

make_fixture "$missing_privacy_claim_dir"
perl -0pi -e 's/does not collect data from this app/does not collect this data/g' "$missing_privacy_claim_dir/AppStore/Public/privacy.html"
if DOC_ROOT="$missing_privacy_claim_dir" bash Scripts/verify_app_store_submission_consistency.sh >/dev/null 2>&1; then
  echo "Expected App Store submission consistency verifier to reject missing privacy claims." >&2
  exit 1
fi

make_fixture "$missing_support_claim_dir"
perl -0pi -e 's/Calendar Full Access/Calendar access/g' "$missing_support_claim_dir/AppStore/Public/support.html"
if DOC_ROOT="$missing_support_claim_dir" bash Scripts/verify_app_store_submission_consistency.sh >/dev/null 2>&1; then
  echo "Expected App Store submission consistency verifier to reject missing support claims." >&2
  exit 1
fi

make_fixture "$missing_public_artifact_pointer_dir"
perl -0pi -e 's/AppStore\/Public\/support\.html/AppStore\/Public\/missing.html/g' "$missing_public_artifact_pointer_dir/AppStore/APP_STORE_READINESS.md"
if DOC_ROOT="$missing_public_artifact_pointer_dir" bash Scripts/verify_app_store_submission_consistency.sh >/dev/null 2>&1; then
  echo "Expected App Store submission consistency verifier to reject public artifact pointer drift." >&2
  exit 1
fi

make_fixture "$missing_handoff_warning_dir"
perl -0pi -e 's/Do not claim public App Store readiness until/Do not claim public readiness until/g' "$missing_handoff_warning_dir/AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
if DOC_ROOT="$missing_handoff_warning_dir" bash Scripts/verify_app_store_submission_consistency.sh >/dev/null 2>&1; then
  echo "Expected App Store submission consistency verifier to reject missing handoff readiness warning." >&2
  exit 1
fi

echo "App Store submission material consistency verifier self-test passed."
