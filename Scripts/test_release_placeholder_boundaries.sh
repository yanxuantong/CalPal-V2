#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

required_docs=(
  "README.md"
  "IMPLEMENTATION_NOTES.md"
  "AppStore/APP_STORE_CONNECT_SUBMISSION.md"
  "AppStore/APP_STORE_READINESS.md"
  "AppStore/PRIVACY_POLICY.md"
  "AppStore/README.md"
  "AppStore/Public/privacy.html"
  "AppStore/Public/support.html"
  "AppStore/ProductionPolish/2026-05-28/README.md"
  "AppStore/ProductionPolish/2026-05-28/SMOKE_AUTOMATION_CONTRACT.md"
  "AppStore/SmokeTests/2026-05-31-local-release-gate/README.md"
  "AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
  "AppStore/ReleaseEvidence/APP_STORE_CONNECT_METADATA_TEMPLATE.md"
  "AppStore/ReleaseEvidence/APP_STORE_PRIVACY_ANSWERS_TEMPLATE.md"
  "AppStore/ReleaseEvidence/LOCAL_RELEASE_BUNDLE_MANIFEST.md"
  "AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
  "AppStore/ReleaseEvidence/SCREENSHOT_REVIEW_TEMPLATE.md"
  "AppStore/ReleaseEvidence/SIGNED_UPLOAD_TEMPLATE.md"
  "AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md"
)

for doc in "${required_docs[@]}"; do
  mkdir -p "$tmp_root/$(dirname "$doc")"
  cp "$doc" "$tmp_root/$doc"
done

DOC_ROOT="$tmp_root" bash Scripts/verify_release_placeholder_boundaries.sh >/dev/null

printf '\nSupport URL: TODO\n' >>"$tmp_root/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$tmp_root" bash Scripts/verify_release_placeholder_boundaries.sh >/dev/null 2>&1; then
  echo "Expected release placeholder verifier to reject a finalized doc TODO field." >&2
  exit 1
fi

cp "AppStore/APP_STORE_CONNECT_SUBMISSION.md" "$tmp_root/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
printf '\nSupport URL: https://example.com/calpal/support\n' >>"$tmp_root/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$tmp_root" bash Scripts/verify_release_placeholder_boundaries.sh >/dev/null 2>&1; then
  echo "Expected release placeholder verifier to reject sample example.com content." >&2
  exit 1
fi

cp "AppStore/APP_STORE_CONNECT_SUBMISSION.md" "$tmp_root/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
printf '\n- [ ] Finalize support URL.\n' >>"$tmp_root/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$tmp_root" bash Scripts/verify_release_placeholder_boundaries.sh >/dev/null 2>&1; then
  echo "Expected release placeholder verifier to reject unchecked finalized-doc checklist items." >&2
  exit 1
fi

echo "Release placeholder boundary verifier self-test passed."
