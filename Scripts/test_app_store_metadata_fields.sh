#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_fixture() {
  local dir="$1"
  mkdir -p "$dir/AppStore"
  cp AppStore/APP_STORE_CONNECT_SUBMISSION.md "$dir/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
}

valid_dir="$tmp_root/valid"
long_subtitle_dir="$tmp_root/long-subtitle"
spaced_keywords_dir="$tmp_root/spaced-keywords"
short_keyword_dir="$tmp_root/short-keyword"
long_keywords_dir="$tmp_root/long-keywords"
html_description_dir="$tmp_root/html-description"

make_fixture "$valid_dir"
DOC_ROOT="$valid_dir" bash Scripts/verify_app_store_metadata_fields.sh >/dev/null

make_fixture "$long_subtitle_dir"
perl -0pi -e 's/Private AI calendar commands/Private AI calendar commands for Apple Calendar users/g' "$long_subtitle_dir/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$long_subtitle_dir" bash Scripts/verify_app_store_metadata_fields.sh >/dev/null 2>&1; then
  echo "Expected metadata verifier to reject an overlong subtitle." >&2
  exit 1
fi

make_fixture "$spaced_keywords_dir"
perl -0pi -e 's/calendar,assistant,schedule,planner,voice,agenda,productivity,events/calendar, assistant, schedule/' "$spaced_keywords_dir/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$spaced_keywords_dir" bash Scripts/verify_app_store_metadata_fields.sh >/dev/null 2>&1; then
  echo "Expected metadata verifier to reject spaces in keywords." >&2
  exit 1
fi

make_fixture "$short_keyword_dir"
perl -0pi -e 's/calendar,assistant,schedule,planner,voice,agenda,productivity,events/calendar,AI,planner/' "$short_keyword_dir/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$short_keyword_dir" bash Scripts/verify_app_store_metadata_fields.sh >/dev/null 2>&1; then
  echo "Expected metadata verifier to reject short keywords." >&2
  exit 1
fi

make_fixture "$long_keywords_dir"
perl -0pi -e 's/calendar,assistant,schedule,planner,voice,agenda,productivity,events/calendarassistantproductivityplanneragenda,calendarassistantproductivityplanneragenda,calendarassistantproductivityplanneragenda/' "$long_keywords_dir/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$long_keywords_dir" bash Scripts/verify_app_store_metadata_fields.sh >/dev/null 2>&1; then
  echo "Expected metadata verifier to reject overlong keyword bytes." >&2
  exit 1
fi

make_fixture "$html_description_dir"
perl -0pi -e 's|CalPal is a private calendar assistant|<b>CalPal</b> is a private calendar assistant|' "$html_description_dir/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
if DOC_ROOT="$html_description_dir" bash Scripts/verify_app_store_metadata_fields.sh >/dev/null 2>&1; then
  echo "Expected metadata verifier to reject HTML in description." >&2
  exit 1
fi

echo "App Store metadata fields verifier self-test passed."
