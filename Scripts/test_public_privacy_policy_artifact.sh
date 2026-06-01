#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  cp AppStore/PRIVACY_POLICY.md "$dir/PRIVACY_POLICY.md"
  cp AppStore/Public/privacy.html "$dir/privacy.html"
}

valid_dir="$tmp_root/valid"
placeholder_dir="$tmp_root/placeholder"
script_dir="$tmp_root/script"
missing_phrase_dir="$tmp_root/missing-phrase"
duplicate_heading_dir="$tmp_root/duplicate-heading"
http_dir="$tmp_root/http"

make_fixture "$valid_dir"
POLICY_MD="$valid_dir/PRIVACY_POLICY.md" POLICY_HTML="$valid_dir/privacy.html" bash Scripts/verify_public_privacy_policy_artifact.sh >/dev/null

make_fixture "$placeholder_dir"
printf '\nTODO: publish URL\n' >>"$placeholder_dir/PRIVACY_POLICY.md"
if POLICY_MD="$placeholder_dir/PRIVACY_POLICY.md" POLICY_HTML="$placeholder_dir/privacy.html" bash Scripts/verify_public_privacy_policy_artifact.sh >/dev/null 2>&1; then
  echo "Expected privacy policy verifier to reject placeholder text." >&2
  exit 1
fi

make_fixture "$script_dir"
printf '\n<script>alert("x")</script>\n' >>"$script_dir/privacy.html"
if POLICY_MD="$script_dir/PRIVACY_POLICY.md" POLICY_HTML="$script_dir/privacy.html" bash Scripts/verify_public_privacy_policy_artifact.sh >/dev/null 2>&1; then
  echo "Expected privacy policy verifier to reject script markup." >&2
  exit 1
fi

make_fixture "$missing_phrase_dir"
perl -0pi -e 's/does not collect data from this app/does not collect this data/g' "$missing_phrase_dir/privacy.html"
if POLICY_MD="$missing_phrase_dir/PRIVACY_POLICY.md" POLICY_HTML="$missing_phrase_dir/privacy.html" bash Scripts/verify_public_privacy_policy_artifact.sh >/dev/null 2>&1; then
  echo "Expected privacy policy verifier to reject a missing required privacy phrase." >&2
  exit 1
fi

make_fixture "$duplicate_heading_dir"
printf '\n<h1>CalPal Privacy Policy</h1>\n' >>"$duplicate_heading_dir/privacy.html"
if POLICY_MD="$duplicate_heading_dir/PRIVACY_POLICY.md" POLICY_HTML="$duplicate_heading_dir/privacy.html" bash Scripts/verify_public_privacy_policy_artifact.sh >/dev/null 2>&1; then
  echo "Expected privacy policy verifier to reject duplicate h1 markup." >&2
  exit 1
fi

make_fixture "$http_dir"
printf '\n<a href="http://calpal.app/privacy">privacy</a>\n' >>"$http_dir/privacy.html"
if POLICY_MD="$http_dir/PRIVACY_POLICY.md" POLICY_HTML="$http_dir/privacy.html" bash Scripts/verify_public_privacy_policy_artifact.sh >/dev/null 2>&1; then
  echo "Expected privacy policy verifier to reject insecure HTTP links." >&2
  exit 1
fi

echo "Public privacy policy artifact verifier self-test passed."
