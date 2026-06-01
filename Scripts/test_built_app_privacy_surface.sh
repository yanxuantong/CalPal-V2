#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_app() {
  local app_dir="$1"
  local executable_contents="$2"
  mkdir -p "$app_dir"
  printf '%s\n' "$executable_contents" >"$app_dir/CalPal"
}

clean_app="$tmp_root/Clean.app"
endpoint_app="$tmp_root/Endpoint.app"
sdk_app="$tmp_root/Sdk.app"
placeholder_app="$tmp_root/Placeholder.app"

make_app "$clean_app" "CalPal local-only executable strings"
SKIP_BUILD=1 APP_PATH="$clean_app" APP_EXECUTABLE="$clean_app/CalPal" bash Scripts/verify_built_app_privacy_surface.sh >/dev/null

make_app "$endpoint_app" "https://api.example.invalid"
if SKIP_BUILD=1 APP_PATH="$endpoint_app" APP_EXECUTABLE="$endpoint_app/CalPal" bash Scripts/verify_built_app_privacy_surface.sh >/dev/null 2>&1; then
  echo "Expected built app privacy verifier to reject executable HTTP(S) endpoints." >&2
  exit 1
fi

make_app "$sdk_app" "Firebase"
if SKIP_BUILD=1 APP_PATH="$sdk_app" APP_EXECUTABLE="$sdk_app/CalPal" bash Scripts/verify_built_app_privacy_surface.sh >/dev/null 2>&1; then
  echo "Expected built app privacy verifier to reject SDK markers." >&2
  exit 1
fi

make_app "$placeholder_app" "CalPal local-only executable strings"
printf 'Support URL: https://example.com/calpal/support\n' >"$placeholder_app/Info.plist"
if SKIP_BUILD=1 APP_PATH="$placeholder_app" APP_EXECUTABLE="$placeholder_app/CalPal" bash Scripts/verify_built_app_privacy_surface.sh >/dev/null 2>&1; then
  echo "Expected built app privacy verifier to reject sample placeholder content." >&2
  exit 1
fi

echo "Built app privacy surface verifier self-test passed."
