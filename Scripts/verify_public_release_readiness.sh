#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_FILE="${EVIDENCE_FILE:-$ROOT_DIR/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md}"

cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

require_line() {
  local expected="$1"
  if ! grep -Fxq "$expected" "$EVIDENCE_FILE"; then
    fail "Missing required evidence line: $expected"
  fi
}

[[ -f "$EVIDENCE_FILE" ]] || fail "Missing public release evidence file: $EVIDENCE_FILE"

if grep -Eq 'TODO|TBD|\[ \]' "$EVIDENCE_FILE"; then
  fail "Public release evidence is incomplete: remove TODO/TBD values and complete every checklist item only after evidence exists."
fi

require_line "Version: 1.0"
require_line "Build: 3"
require_line "Local release gate result: PASS"
require_line "Signed archive upload result: PASS"
require_line "TestFlight real-device smoke result: PASS"
require_line "Final screenshot review result: PASS"
require_line "App Store Connect metadata result: PASS"
require_line "App Store Connect privacy answers result: PASS"
require_line "Open release blockers: NONE"

privacy_url="$(awk -F': ' '/^Public privacy policy URL: / { print $2 }' "$EVIDENCE_FILE")"
if [[ ! "$privacy_url" =~ ^https://[^[:space:]]+$ ]]; then
  fail "Public privacy policy URL must be an https URL."
fi

for required_field in \
  "Local release gate date" \
  "Signed archive upload build" \
  "Signed archive upload date" \
  "TestFlight real-device smoke device" \
  "TestFlight real-device smoke iOS version" \
  "TestFlight real-device smoke date" \
  "Final screenshot review date"; do
  value="$(awk -F': ' -v field="$required_field" '$1 == field { print $2 }' "$EVIDENCE_FILE")"
  if [[ -z "$value" ]]; then
    fail "Missing value for: $required_field"
  fi
done

echo "CalPal 1.0 public release readiness evidence verified."
