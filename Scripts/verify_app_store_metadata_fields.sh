#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC_ROOT="${DOC_ROOT:-$ROOT_DIR}"
SUBMISSION="$DOC_ROOT/AppStore/APP_STORE_CONNECT_SUBMISSION.md"

cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "Missing non-empty App Store metadata draft: $path"
}

trim_blank_edges() {
  awk '
    NF { seen=1 }
    seen { lines[++count]=$0 }
    END {
      while (count > 0 && lines[count] == "") count--
      for (i = 1; i <= count; i++) print lines[i]
    }
  '
}

field_between_labels() {
  local start_label="$1"
  local end_label="$2"
  awk -v start="$start_label" -v end="$end_label" '
    $0 == start { capture=1; next }
    capture && $0 == end { exit }
    capture { print }
  ' "$SUBMISSION" | trim_blank_edges
}

field_until_heading() {
  local start_label="$1"
  local end_heading="$2"
  awk -v start="$start_label" -v end="$end_heading" '
    $0 == start { capture=1; next }
    capture && $0 == end { exit }
    capture { print }
  ' "$SUBMISSION" | trim_blank_edges
}

char_count() {
  LC_CTYPE=UTF-8 printf '%s' "$1" | wc -m | tr -d '[:space:]'
}

byte_count() {
  LC_CTYPE=UTF-8 printf '%s' "$1" | wc -c | tr -d '[:space:]'
}

require_non_empty() {
  local field="$1"
  local value="$2"
  [[ -n "$value" ]] || fail "$field must not be empty."
}

require_max_chars() {
  local field="$1"
  local value="$2"
  local max="$3"
  local count
  count="$(char_count "$value")"
  if (( count > max )); then
    fail "$field must be at most $max characters; found $count."
  fi
}

require_min_chars() {
  local field="$1"
  local value="$2"
  local min="$3"
  local count
  count="$(char_count "$value")"
  if (( count < min )); then
    fail "$field must be at least $min characters; found $count."
  fi
}

require_max_bytes() {
  local field="$1"
  local value="$2"
  local max="$3"
  local count
  count="$(byte_count "$value")"
  if (( count > max )); then
    fail "$field must be at most $max bytes; found $count."
  fi
}

require_plain_text() {
  local field="$1"
  local value="$2"
  if grep -Eq '<[A-Za-z/][^>]*>' <<<"$value"; then
    fail "$field must be plain text; HTML is not supported."
  fi
}

require_keywords_contract() {
  local keywords="$1"
  local keyword trimmed chars

  [[ "$keywords" != *" "* ]] || fail "Keywords must be comma-separated without spaces to preserve the 100-byte budget."
  [[ "$keywords" != *, ]] || fail "Keywords must not end with a comma."
  [[ "$keywords" != ,* ]] || fail "Keywords must not start with a comma."
  [[ "$keywords" != *,,* ]] || fail "Keywords must not contain empty entries."

  IFS=',' read -r -a keyword_list <<<"$keywords"
  for keyword in "${keyword_list[@]}"; do
    trimmed="$(printf '%s' "$keyword" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ "$keyword" == "$trimmed" ]] || fail "Keyword has surrounding whitespace: $keyword"
    chars="$(char_count "$keyword")"
    if (( chars <= 2 )); then
      fail "Each keyword must be longer than two characters; found: $keyword"
    fi
  done
}

require_file "$SUBMISSION"

name="$(field_between_labels "Name:" "Subtitle:")"
subtitle="$(field_between_labels "Subtitle:" "Promotional text:")"
promotional_text="$(field_between_labels "Promotional text:" "Description:")"
description="$(field_between_labels "Description:" "Keywords:")"
keywords="$(field_between_labels "Keywords:" "Category:")"
what_to_test="$(field_until_heading "What to Test in TestFlight:" "## App Review Notes")"
review_notes="$(field_until_heading "## App Review Notes" "## Privacy Answers Draft")"

require_non_empty "Name" "$name"
require_min_chars "Name" "$name" 2
require_max_chars "Name" "$name" 30

require_non_empty "Subtitle" "$subtitle"
require_max_chars "Subtitle" "$subtitle" 30

require_non_empty "Promotional text" "$promotional_text"
require_max_chars "Promotional text" "$promotional_text" 170

require_non_empty "Description" "$description"
require_max_chars "Description" "$description" 4000
require_plain_text "Description" "$description"

require_non_empty "Keywords" "$keywords"
require_max_bytes "Keywords" "$keywords" 100
require_keywords_contract "$keywords"

require_non_empty "What to Test in TestFlight" "$what_to_test"
require_max_chars "What to Test in TestFlight" "$what_to_test" 4000
require_plain_text "What to Test in TestFlight" "$what_to_test"

require_non_empty "App Review Notes" "$review_notes"
require_max_chars "App Review Notes" "$review_notes" 4000
require_plain_text "App Review Notes" "$review_notes"

echo "App Store metadata fields verified."
