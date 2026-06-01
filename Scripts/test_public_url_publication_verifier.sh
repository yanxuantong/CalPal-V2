#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_evidence() {
  local path="$1"
  cat >"$path" <<'EOF'
# CalPal Public URL Publication Fixture

Public privacy policy URL: https://calpal.test/privacy
Public support URL: https://calpal.test/support
Public marketing URL: https://calpal.test/
EOF
}

make_fixture_pages() {
  local dir="$1"
  mkdir -p "$dir"
  cp AppStore/Public/privacy.html "$dir/privacy.html"
  cp AppStore/Public/support.html "$dir/support.html"
  cp AppStore/Public/support.html "$dir/marketing.html"
}

valid_evidence="$tmpdir/evidence.md"
valid_pages="$tmpdir/pages"
make_evidence "$valid_evidence"
make_fixture_pages "$valid_pages"

PUBLIC_URL_FIXTURE_DIR="$valid_pages" EVIDENCE_FILE="$valid_evidence" bash Scripts/verify_public_url_publication.sh >/dev/null

todo_evidence="$tmpdir/todo-evidence.md"
make_evidence "$todo_evidence"
perl -0pi -e 's|Public support URL: https://calpal\.test/support|Public support URL: TODO|' "$todo_evidence"
if PUBLIC_URL_FIXTURE_DIR="$valid_pages" EVIDENCE_FILE="$todo_evidence" bash Scripts/verify_public_url_publication.sh >/dev/null 2>&1; then
  echo "Expected public URL verifier to reject TODO URL fields." >&2
  exit 1
fi

http_evidence="$tmpdir/http-evidence.md"
make_evidence "$http_evidence"
perl -0pi -e 's|Public privacy policy URL: https://calpal\.test/privacy|Public privacy policy URL: http://calpal.test/privacy|' "$http_evidence"
if PUBLIC_URL_FIXTURE_DIR="$valid_pages" EVIDENCE_FILE="$http_evidence" bash Scripts/verify_public_url_publication.sh >/dev/null 2>&1; then
  echo "Expected public URL verifier to reject non-https URL fields." >&2
  exit 1
fi

placeholder_pages="$tmpdir/placeholder-pages"
make_fixture_pages "$placeholder_pages"
printf '\nTODO: publish support URL\n' >>"$placeholder_pages/support.html"
if PUBLIC_URL_FIXTURE_DIR="$placeholder_pages" EVIDENCE_FILE="$valid_evidence" bash Scripts/verify_public_url_publication.sh >/dev/null 2>&1; then
  echo "Expected public URL verifier to reject placeholder page content." >&2
  exit 1
fi

missing_claim_pages="$tmpdir/missing-claim-pages"
make_fixture_pages "$missing_claim_pages"
perl -0pi -e 's/not uploaded to a CalPal server/not sent away/g' "$missing_claim_pages/privacy.html"
if PUBLIC_URL_FIXTURE_DIR="$missing_claim_pages" EVIDENCE_FILE="$valid_evidence" bash Scripts/verify_public_url_publication.sh >/dev/null 2>&1; then
  echo "Expected public URL verifier to reject a privacy page missing required privacy claims." >&2
  exit 1
fi

unsafe_pages="$tmpdir/unsafe-pages"
make_fixture_pages "$unsafe_pages"
printf '\n<script>alert("x")</script>\n' >>"$unsafe_pages/marketing.html"
if PUBLIC_URL_FIXTURE_DIR="$unsafe_pages" EVIDENCE_FILE="$valid_evidence" bash Scripts/verify_public_url_publication.sh >/dev/null 2>&1; then
  echo "Expected public URL verifier to reject unsafe public page markup." >&2
  exit 1
fi

echo "Public URL publication verifier self-test passed."
