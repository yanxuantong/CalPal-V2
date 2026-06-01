#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  cp AppStore/Public/privacy.html "$dir/privacy.html"
  cp AppStore/Public/support.html "$dir/support.html"
}

valid_dir="$tmp_root/valid"
unexpected_dir="$tmp_root/unexpected-file"
external_link_dir="$tmp_root/external-link"
broken_link_dir="$tmp_root/broken-link"
placeholder_dir="$tmp_root/placeholder"

make_fixture "$valid_dir"
PUBLIC_DIR="$valid_dir" bash Scripts/verify_public_static_artifacts.sh >/dev/null

make_fixture "$unexpected_dir"
printf 'extra\n' >"$unexpected_dir/notes.txt"
if PUBLIC_DIR="$unexpected_dir" bash Scripts/verify_public_static_artifacts.sh >/dev/null 2>&1; then
  echo "Expected public static verifier to reject unexpected publish files." >&2
  exit 1
fi

make_fixture "$external_link_dir"
printf '<a href="https://example.com/support">external</a>\n' >>"$external_link_dir/support.html"
if PUBLIC_DIR="$external_link_dir" bash Scripts/verify_public_static_artifacts.sh >/dev/null 2>&1; then
  echo "Expected public static verifier to reject external links." >&2
  exit 1
fi

make_fixture "$broken_link_dir"
perl -0pi -e 's/href="privacy\.html"/href="missing.html"/' "$broken_link_dir/support.html"
if PUBLIC_DIR="$broken_link_dir" bash Scripts/verify_public_static_artifacts.sh >/dev/null 2>&1; then
  echo "Expected public static verifier to reject missing relative link targets." >&2
  exit 1
fi

make_fixture "$placeholder_dir"
printf 'TODO: publish URL\n' >>"$placeholder_dir/privacy.html"
if PUBLIC_DIR="$placeholder_dir" bash Scripts/verify_public_static_artifacts.sh >/dev/null 2>&1; then
  echo "Expected public static verifier to reject placeholder text." >&2
  exit 1
fi

echo "Public static artifacts verifier self-test passed."
