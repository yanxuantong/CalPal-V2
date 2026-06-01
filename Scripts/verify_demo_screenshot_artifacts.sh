#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/Artifacts/AppStoreScreenshots}"
SUBMISSION="${SUBMISSION:-$ROOT_DIR/AppStore/APP_STORE_CONNECT_SUBMISSION.md}"

cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

screenshot_path() {
  printf '%s/%s\n' "$SCREENSHOT_DIR" "$1"
}

read_dimension() {
  local path="$1"
  local key="$2"
  sips -g "$key" "$path" 2>/dev/null | awk -v key="$key" '$1 == key ":" { print $2 }'
}

require_screenshot() {
  local filename="$1"
  local path width height format
  path="$(screenshot_path "$filename")"

  [[ -s "$path" ]] || fail "Missing non-empty screenshot artifact: $path"

  format="$(sips -g format "$path" 2>/dev/null | awk '$1 == "format:" { print $2 }')"
  [[ "$format" == "png" ]] || fail "Screenshot artifact must be a PNG: $path"

  width="$(read_dimension "$path" pixelWidth)"
  height="$(read_dimension "$path" pixelHeight)"
  [[ "$width" =~ ^[0-9]+$ ]] || fail "Could not read screenshot width for $path"
  [[ "$height" =~ ^[0-9]+$ ]] || fail "Could not read screenshot height for $path"

  if (( width < 390 || height < 800 )); then
    fail "Screenshot artifact is too small for App Store review evidence: $path is ${width}x${height}."
  fi

  if (( height <= width )); then
    fail "Screenshot artifact must be portrait orientation: $path is ${width}x${height}."
  fi

  if ! grep -Fq "Artifacts/AppStoreScreenshots/$filename" "$SUBMISSION"; then
    fail "App Store Connect submission draft must reference screenshot artifact: $filename"
  fi

  printf '%s %s %s\n' "$path" "$width" "$height"
}

light_info="$(require_screenshot calpal-demo-home.png)"
dark_info="$(require_screenshot calpal-demo-home-dark.png)"

light_path="$(awk '{ print $1 }' <<<"$light_info")"
light_width="$(awk '{ print $2 }' <<<"$light_info")"
light_height="$(awk '{ print $3 }' <<<"$light_info")"
dark_path="$(awk '{ print $1 }' <<<"$dark_info")"
dark_width="$(awk '{ print $2 }' <<<"$dark_info")"
dark_height="$(awk '{ print $3 }' <<<"$dark_info")"

if [[ "$light_width" != "$dark_width" || "$light_height" != "$dark_height" ]]; then
  fail "Light and dark screenshot artifacts must use matching dimensions: ${light_width}x${light_height} vs ${dark_width}x${dark_height}."
fi

if cmp -s "$light_path" "$dark_path"; then
  fail "Light and dark screenshot artifacts must not be identical files."
fi

echo "Demo screenshot artifacts verified at ${light_width}x${light_height}."
