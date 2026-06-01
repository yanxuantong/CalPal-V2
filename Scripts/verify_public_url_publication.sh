#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_FILE="${EVIDENCE_FILE:-$ROOT_DIR/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md}"
FIXTURE_DIR="${PUBLIC_URL_FIXTURE_DIR:-}"

fail() {
  echo "$1" >&2
  exit 1
}

field_value() {
  local field="$1"
  awk -F': ' -v field="$field" '$1 == field { print $2 }' "$EVIDENCE_FILE"
}

require_https_url() {
  local field="$1"
  local value
  value="$(field_value "$field")"

  if [[ -z "$value" || "$value" == "TODO" ]]; then
    fail "$field must be filled with a public https URL before publication can be verified."
  fi

  if [[ ! "$value" =~ ^https://[^[:space:]]+$ ]]; then
    fail "$field must be a public https URL: $value"
  fi

  if [[ "$value" =~ example\.com|REPLACE_ME|YOUR_ ]]; then
    fail "$field contains sample placeholder content: $value"
  fi
}

fetch_url() {
  local label="$1"
  local url="$2"
  local out="$3"

  if [[ -n "$FIXTURE_DIR" ]]; then
    case "$label" in
      privacy) cp "$FIXTURE_DIR/privacy.html" "$out" ;;
      support) cp "$FIXTURE_DIR/support.html" "$out" ;;
      marketing) cp "$FIXTURE_DIR/marketing.html" "$out" ;;
      *) fail "Unknown public URL fixture label: $label" ;;
    esac
    return
  fi

  curl -fsSL --max-time 20 "$url" -o "$out" || fail "Could not fetch $label URL: $url"
}

require_phrase() {
  local path="$1"
  local phrase="$2"
  if ! grep -Fqi "$phrase" "$path"; then
    fail "Fetched public page is missing required phrase in $path: $phrase"
  fi
}

reject_pattern() {
  local path="$1"
  local pattern="$2"
  if grep -Eiq "$pattern" "$path"; then
    fail "Fetched public page contains disallowed content in $path: $pattern"
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

require_common_public_page_contract() {
  local path="$1"

  [[ -s "$path" ]] || fail "Fetched public page is empty: $path"
  require_phrase "$path" "<!doctype html>"
  require_phrase "$path" "<html lang=\"en\">"
  require_phrase "$path" "<meta charset=\"utf-8\">"
  require_phrase "$path" "<meta name=\"viewport\""
  require_phrase "$path" "<main>"
  require_exact_count "$path" "<h1[ >]" "1"
  reject_pattern "$path" 'TODO|TBD|\[ \]'
  reject_pattern "$path" 'REPLACE_ME|YOUR_|example\.com'
  reject_pattern "$path" '<script[ >]'
  reject_pattern "$path" '<iframe[ >]'
  reject_pattern "$path" '<form[ >]'
  reject_pattern "$path" 'http://'
}

require_privacy_page_contract() {
  local path="$1"

  require_common_public_page_contract "$path"
  require_phrase "$path" "<title>CalPal Privacy Policy</title>"
  require_phrase "$path" "<h1>CalPal Privacy Policy</h1>"
  require_phrase "$path" "does not collect data from this app"
  require_phrase "$path" "does not operate a developer-hosted backend"
  require_phrase "$path" "not uploaded to a CalPal server"
  require_phrase "$path" "does not track users"
}

require_support_page_contract() {
  local path="$1"

  require_common_public_page_contract "$path"
  require_phrase "$path" "<title>CalPal Support</title>"
  require_phrase "$path" "<h1>CalPal Support</h1>"
  require_phrase "$path" "Apple Calendar as the source of truth"
  require_phrase "$path" "Calendar Full Access"
  require_phrase "$path" "text entry and manual event creation remain available"
  require_phrase "$path" "does not upload calendar content to a CalPal server"
}

require_marketing_page_contract() {
  local path="$1"

  require_common_public_page_contract "$path"
  require_phrase "$path" "CalPal"
  require_phrase "$path" "Apple Calendar"
  require_phrase "$path" "calendar"
}

[[ -f "$EVIDENCE_FILE" ]] || fail "Missing public release evidence file: $EVIDENCE_FILE"

require_https_url "Public privacy policy URL"
require_https_url "Public support URL"
require_https_url "Public marketing URL"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

privacy_url="$(field_value "Public privacy policy URL")"
support_url="$(field_value "Public support URL")"
marketing_url="$(field_value "Public marketing URL")"

fetch_url privacy "$privacy_url" "$tmpdir/privacy.html"
fetch_url support "$support_url" "$tmpdir/support.html"
fetch_url marketing "$marketing_url" "$tmpdir/marketing.html"

require_privacy_page_contract "$tmpdir/privacy.html"
require_support_page_contract "$tmpdir/support.html"
require_marketing_page_contract "$tmpdir/marketing.html"

echo "Public URL publication verified."
