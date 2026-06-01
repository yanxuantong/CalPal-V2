#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_DIR="${PUBLIC_DIR:-$ROOT_DIR/AppStore/Public}"

fail() {
  echo "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "Missing non-empty public static artifact: $path"
}

reject_pattern() {
  local path="$1"
  local pattern="$2"
  if grep -Eiq "$pattern" "$path"; then
    fail "Public static artifact contains disallowed content in $path: $pattern"
  fi
}

require_phrase() {
  local path="$1"
  local phrase="$2"
  if ! grep -Fqi "$phrase" "$path"; then
    fail "Public static artifact is missing required phrase in $path: $phrase"
  fi
}

require_exact_count() {
  local path="$1"
  local pattern="$2"
  local expected="$3"
  local count
  count="$(grep -Eic "$pattern" "$path" || true)"
  [[ "$count" == "$expected" ]] || fail "Expected $expected matches for '$pattern' in $path, found $count."
}

[[ -d "$PUBLIC_DIR" ]] || fail "Missing public static artifact directory: AppStore/Public"

expected_files=(
  "$PUBLIC_DIR/privacy.html"
  "$PUBLIC_DIR/support.html"
)

for file in "${expected_files[@]}"; do
  require_file "$file"
done

while IFS= read -r -d '' file; do
  case "$file" in
    "$PUBLIC_DIR/privacy.html"|"$PUBLIC_DIR/support.html") ;;
    *) fail "Unexpected public static artifact. Update this verifier before publishing: ${file#$ROOT_DIR/}" ;;
  esac
done < <(find "$PUBLIC_DIR" -type f -print0)

for file in "${expected_files[@]}"; do
  require_phrase "$file" "<!doctype html>"
  require_phrase "$file" "<html lang=\"en\">"
  require_phrase "$file" "<meta charset=\"utf-8\">"
  require_phrase "$file" "<meta name=\"viewport\""
  require_phrase "$file" "<main>"
  require_exact_count "$file" "<h1[ >]" "1"
  require_exact_count "$file" "<main[ >]" "1"

  reject_pattern "$file" 'TODO|TBD|\[ \]'
  reject_pattern "$file" 'REPLACE_ME|YOUR_|example\.com'
  reject_pattern "$file" '<script[ >]'
  reject_pattern "$file" '<iframe[ >]'
  reject_pattern "$file" '<form[ >]'
  reject_pattern "$file" 'http://'
  reject_pattern "$file" 'https://'
  reject_pattern "$file" 'mailto:'
done

while IFS= read -r href; do
  [[ -n "$href" ]] || continue
  case "$href" in
    \#*) continue ;;
    *://*|mailto:*) fail "Public static artifact contains external link: $href" ;;
  esac

  target="${href%%#*}"
  [[ -n "$target" ]] || continue
  [[ "$target" != /* ]] || fail "Public static artifact link must be relative: $href"
  [[ "$target" != *".."* ]] || fail "Public static artifact link must not traverse directories: $href"
  [[ -s "$PUBLIC_DIR/$target" ]] || fail "Public static artifact link target does not exist: $href"
done < <(grep -REio 'href="[^"]+"' "$PUBLIC_DIR" | sed -E 's/.*href="([^"]+)".*/\1/')

echo "Public static artifacts verified."
