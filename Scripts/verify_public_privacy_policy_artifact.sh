#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_MD="${POLICY_MD:-$ROOT_DIR/AppStore/PRIVACY_POLICY.md}"
POLICY_HTML="${POLICY_HTML:-$ROOT_DIR/AppStore/Public/privacy.html}"

require_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "Missing non-empty privacy policy artifact: $path" >&2
    exit 1
  fi
}

require_no_placeholders() {
  local path="$1"
  if grep -Eqi 'TODO|TBD|\[ \]' "$path"; then
    echo "Privacy policy artifact still contains placeholder text: $path" >&2
    exit 1
  fi
}

require_phrase() {
  local path="$1"
  local phrase="$2"
  if ! grep -Fqi "$phrase" "$path"; then
    echo "Privacy policy artifact is missing required phrase in $path: $phrase" >&2
    exit 1
  fi
}

require_exact_count() {
  local path="$1"
  local pattern="$2"
  local expected="$3"
  local count
  count="$(grep -Eic "$pattern" "$path" || true)"
  if [[ "$count" != "$expected" ]]; then
    echo "Expected $expected matches for '$pattern' in $path, found $count." >&2
    exit 1
  fi
}

reject_pattern() {
  local path="$1"
  local pattern="$2"
  if grep -Eiq "$pattern" "$path"; then
    echo "Privacy policy artifact contains disallowed markup in $path: $pattern" >&2
    exit 1
  fi
}

require_file "$POLICY_MD"
require_file "$POLICY_HTML"
require_no_placeholders "$POLICY_MD"
require_no_placeholders "$POLICY_HTML"

for artifact in "$POLICY_MD" "$POLICY_HTML"; do
  require_phrase "$artifact" "Effective date: May 22, 2026"
  require_phrase "$artifact" "does not collect data from this app"
  require_phrase "$artifact" "does not operate a developer-hosted backend"
  require_phrase "$artifact" "not uploaded to a CalPal server"
  require_phrase "$artifact" "UserDefaults"
  require_phrase "$artifact" "CA92.1"
  require_phrase "$artifact" "does not track users"
  require_phrase "$artifact" "does not sell data"
done

require_phrase "$POLICY_HTML" "<!doctype html>"
require_phrase "$POLICY_HTML" "<html lang=\"en\">"
require_phrase "$POLICY_HTML" "<meta charset=\"utf-8\">"
require_phrase "$POLICY_HTML" "<meta name=\"viewport\""
require_phrase "$POLICY_HTML" "<meta name=\"description\""
require_phrase "$POLICY_HTML" "<title>CalPal Privacy Policy</title>"
require_phrase "$POLICY_HTML" "<main>"
require_phrase "$POLICY_HTML" "<h1>CalPal Privacy Policy</h1>"
require_exact_count "$POLICY_HTML" "<h1[ >]" "1"

reject_pattern "$POLICY_HTML" "<script[ >]"
reject_pattern "$POLICY_HTML" "<iframe[ >]"
reject_pattern "$POLICY_HTML" "<form[ >]"
reject_pattern "$POLICY_HTML" "http://"

echo "Public privacy policy artifact verified."
