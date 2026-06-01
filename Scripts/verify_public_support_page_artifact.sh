#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT_HTML="${SUPPORT_HTML:-$ROOT_DIR/AppStore/Public/support.html}"
PRIVACY_HTML="${PRIVACY_HTML:-$ROOT_DIR/AppStore/Public/privacy.html}"
SUBMISSION="${SUBMISSION:-$ROOT_DIR/AppStore/APP_STORE_CONNECT_SUBMISSION.md}"

require_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "Missing non-empty support artifact: $path" >&2
    exit 1
  fi
}

require_no_placeholders() {
  local path="$1"
  if grep -Eqi 'TODO|TBD|\[ \]' "$path"; then
    echo "Support artifact still contains placeholder text: $path" >&2
    exit 1
  fi
}

require_phrase() {
  local path="$1"
  local phrase="$2"
  if ! grep -Fqi "$phrase" "$path"; then
    echo "Support artifact is missing required phrase in $path: $phrase" >&2
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
    echo "Support artifact contains disallowed markup in $path: $pattern" >&2
    exit 1
  fi
}

require_file "$SUPPORT_HTML"
require_file "$PRIVACY_HTML"
require_file "$SUBMISSION"
require_no_placeholders "$SUPPORT_HTML"

require_phrase "$SUPPORT_HTML" "<!doctype html>"
require_phrase "$SUPPORT_HTML" "<html lang=\"en\">"
require_phrase "$SUPPORT_HTML" "<meta charset=\"utf-8\">"
require_phrase "$SUPPORT_HTML" "<meta name=\"viewport\""
require_phrase "$SUPPORT_HTML" "<meta name=\"description\""
require_phrase "$SUPPORT_HTML" "<title>CalPal Support</title>"
require_phrase "$SUPPORT_HTML" "<main>"
require_phrase "$SUPPORT_HTML" "<h1>CalPal Support</h1>"
require_exact_count "$SUPPORT_HTML" "<h1[ >]" "1"

for phrase in \
  "Support page for CalPal 1.0" \
  "Apple Calendar as the source of truth" \
  "Calendar Full Access" \
  "Microphone and Speech Recognition permissions" \
  "text entry and manual event creation remain available" \
  "review sensitive create, update, and delete actions" \
  "does not operate a developer-hosted backend" \
  "does not track users" \
  "does not upload calendar content to a CalPal server" \
  "privacy.html" \
  "support contact configured on CalPal's App Store product page"; do
  require_phrase "$SUPPORT_HTML" "$phrase"
done

require_phrase "$SUBMISSION" "AppStore/Public/support.html"
require_phrase "$SUBMISSION" "Support URL source:"
require_phrase "$SUBMISSION" "Marketing URL source:"

reject_pattern "$SUPPORT_HTML" "<script[ >]"
reject_pattern "$SUPPORT_HTML" "<iframe[ >]"
reject_pattern "$SUPPORT_HTML" "<form[ >]"
reject_pattern "$SUPPORT_HTML" "http://"

echo "Public support page artifact verified."
