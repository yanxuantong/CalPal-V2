#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  cp AppStore/Public/support.html "$dir/support.html"
  cp AppStore/Public/privacy.html "$dir/privacy.html"
  cp AppStore/APP_STORE_CONNECT_SUBMISSION.md "$dir/APP_STORE_CONNECT_SUBMISSION.md"
}

valid_dir="$tmp_root/valid"
placeholder_dir="$tmp_root/placeholder"
script_dir="$tmp_root/script"
missing_phrase_dir="$tmp_root/missing-phrase"
duplicate_heading_dir="$tmp_root/duplicate-heading"
missing_submission_pointer_dir="$tmp_root/missing-submission-pointer"

make_fixture "$valid_dir"
SUPPORT_HTML="$valid_dir/support.html" PRIVACY_HTML="$valid_dir/privacy.html" SUBMISSION="$valid_dir/APP_STORE_CONNECT_SUBMISSION.md" bash Scripts/verify_public_support_page_artifact.sh >/dev/null

make_fixture "$placeholder_dir"
printf '\nTODO: publish URL\n' >>"$placeholder_dir/support.html"
if SUPPORT_HTML="$placeholder_dir/support.html" PRIVACY_HTML="$placeholder_dir/privacy.html" SUBMISSION="$placeholder_dir/APP_STORE_CONNECT_SUBMISSION.md" bash Scripts/verify_public_support_page_artifact.sh >/dev/null 2>&1; then
  echo "Expected support page verifier to reject placeholder text." >&2
  exit 1
fi

make_fixture "$script_dir"
printf '\n<script>alert("x")</script>\n' >>"$script_dir/support.html"
if SUPPORT_HTML="$script_dir/support.html" PRIVACY_HTML="$script_dir/privacy.html" SUBMISSION="$script_dir/APP_STORE_CONNECT_SUBMISSION.md" bash Scripts/verify_public_support_page_artifact.sh >/dev/null 2>&1; then
  echo "Expected support page verifier to reject script markup." >&2
  exit 1
fi

make_fixture "$missing_phrase_dir"
perl -0pi -e 's/Apple Calendar as the source of truth/Apple Calendar/g' "$missing_phrase_dir/support.html"
if SUPPORT_HTML="$missing_phrase_dir/support.html" PRIVACY_HTML="$missing_phrase_dir/privacy.html" SUBMISSION="$missing_phrase_dir/APP_STORE_CONNECT_SUBMISSION.md" bash Scripts/verify_public_support_page_artifact.sh >/dev/null 2>&1; then
  echo "Expected support page verifier to reject a missing required support phrase." >&2
  exit 1
fi

make_fixture "$duplicate_heading_dir"
printf '\n<h1>CalPal Support</h1>\n' >>"$duplicate_heading_dir/support.html"
if SUPPORT_HTML="$duplicate_heading_dir/support.html" PRIVACY_HTML="$duplicate_heading_dir/privacy.html" SUBMISSION="$duplicate_heading_dir/APP_STORE_CONNECT_SUBMISSION.md" bash Scripts/verify_public_support_page_artifact.sh >/dev/null 2>&1; then
  echo "Expected support page verifier to reject duplicate h1 markup." >&2
  exit 1
fi

make_fixture "$missing_submission_pointer_dir"
perl -0pi -e 's/AppStore\/Public\/support\.html/AppStore\/Public\/missing.html/g' "$missing_submission_pointer_dir/APP_STORE_CONNECT_SUBMISSION.md"
if SUPPORT_HTML="$missing_submission_pointer_dir/support.html" PRIVACY_HTML="$missing_submission_pointer_dir/privacy.html" SUBMISSION="$missing_submission_pointer_dir/APP_STORE_CONNECT_SUBMISSION.md" bash Scripts/verify_public_support_page_artifact.sh >/dev/null 2>&1; then
  echo "Expected support page verifier to reject a missing App Store submission source pointer." >&2
  exit 1
fi

echo "Public support page artifact verifier self-test passed."
