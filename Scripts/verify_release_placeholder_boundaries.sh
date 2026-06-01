#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC_ROOT="${DOC_ROOT:-$ROOT_DIR}"
cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$DOC_ROOT/$path" ]] || fail "Missing non-empty release document: $path"
}

reject_accidental_placeholders() {
  local path="$1"
  require_file "$path"

  if grep -En '(^|:[[:space:]])(TODO|TBD)([[:space:]]*$)|^- \[ \]' "$DOC_ROOT/$path"; then
    fail "Finalized release document contains an unresolved placeholder field or unchecked item: $path"
  fi

  if grep -En 'https?://example\.com|REPLACE_ME|YOUR_' "$DOC_ROOT/$path"; then
    fail "Finalized release document contains sample placeholder content: $path"
  fi
}

allow_intentional_placeholders() {
  local path="$1"
  require_file "$path"
}

finalized_release_docs=(
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
)

intentional_pending_evidence_docs=(
  "AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
  "AppStore/ReleaseEvidence/APP_STORE_CONNECT_METADATA_TEMPLATE.md"
  "AppStore/ReleaseEvidence/APP_STORE_PRIVACY_ANSWERS_TEMPLATE.md"
  "AppStore/ReleaseEvidence/LOCAL_RELEASE_BUNDLE_MANIFEST.md"
  "AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
  "AppStore/ReleaseEvidence/SCREENSHOT_REVIEW_TEMPLATE.md"
  "AppStore/ReleaseEvidence/SIGNED_UPLOAD_TEMPLATE.md"
  "AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md"
)

for doc in "${finalized_release_docs[@]}"; do
  reject_accidental_placeholders "$doc"
done

for doc in "${intentional_pending_evidence_docs[@]}"; do
  allow_intentional_placeholders "$doc"
done

echo "Release placeholder boundaries verified."
