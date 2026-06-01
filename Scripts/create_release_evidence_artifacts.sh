#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DATE="${RELEASE_DATE:-$(date +%F)}"
CHECK_ONLY=0
FORCE=0

usage() {
  cat <<'EOF'
Usage: Scripts/create_release_evidence_artifacts.sh [--date YYYY-MM-DD] [--check] [--force]

Creates dated repo-local release evidence artifacts from the App Store templates.
The generated files are intentionally incomplete until the release owner fills
remaining TODO values and checklist items after the external evidence exists.

Options:
  --date YYYY-MM-DD  Date to use in generated artifact filenames and Date fields.
  --check            Validate templates and planned output paths without writing.
  --force            Overwrite existing generated artifacts.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      [[ $# -ge 2 ]] || { echo "--date requires a value." >&2; exit 1; }
      RELEASE_DATE="$2"
      shift 2
      ;;
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cd "$ROOT_DIR"

if [[ ! "$RELEASE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Release date must use YYYY-MM-DD format." >&2
  exit 1
fi

if ! date -j -f "%F" "$RELEASE_DATE" "+%F" >/dev/null 2>&1; then
  echo "Release date must be a valid calendar date." >&2
  exit 1
fi

project_setting() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ key " = " {
      value = $3
      gsub(/;/, "", value)
      print value
      exit
    }
  ' CalPal.xcodeproj/project.pbxproj
}

version="$(project_setting MARKETING_VERSION)"
build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$version" ]] || { echo "Could not read MARKETING_VERSION from CalPal.xcodeproj." >&2; exit 1; }
[[ -n "$build" ]] || { echo "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj." >&2; exit 1; }

replace_placeholders() {
  local template="$1"
  sed \
    -e "s/CalPal 1.0/CalPal $version/g" \
    -e "s/^Build: TODO$/Build: $build/" \
    -e "s/^Date: TODO$/Date: $RELEASE_DATE/" \
    "$template"
}

create_artifact() {
  local template="$1"
  local output="$2"
  local required_heading="$3"

  if [[ ! -s "$template" ]]; then
    echo "Missing non-empty template: $template" >&2
    exit 1
  fi

  if ! grep -Fq "$required_heading" "$template"; then
    echo "Template does not look like the expected evidence artifact: $template" >&2
    exit 1
  fi

  if [[ "$output" == *TEMPLATE.md* ]]; then
    echo "Generated output path must not be a template path: $output" >&2
    exit 1
  fi

  case "$output" in
    AppStore/ReleaseEvidence/*|AppStore/SmokeTests/*) ;;
    *) echo "Generated output must stay under AppStore/ReleaseEvidence or AppStore/SmokeTests: $output" >&2; exit 1 ;;
  esac

  if [[ "$CHECK_ONLY" == "1" ]]; then
    echo "Would create $output from $template"
    return
  fi

  if [[ -e "$output" && "$FORCE" != "1" ]]; then
    echo "Refusing to overwrite existing artifact without --force: $output" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$output")"
  replace_placeholders "$template" >"$output"
  echo "Created $output"
}

create_artifact \
  "AppStore/ReleaseEvidence/SIGNED_UPLOAD_TEMPLATE.md" \
  "AppStore/ReleaseEvidence/$RELEASE_DATE-signed-upload.md" \
  "Signed Upload Evidence"

create_artifact \
  "AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md" \
  "AppStore/SmokeTests/$RELEASE_DATE-testflight-real-device-smoke.md" \
  "TestFlight Real-Device Smoke Evidence"

create_artifact \
  "AppStore/ReleaseEvidence/SCREENSHOT_REVIEW_TEMPLATE.md" \
  "AppStore/ReleaseEvidence/$RELEASE_DATE-screenshot-review.md" \
  "Final Screenshot Review Evidence"

create_artifact \
  "AppStore/ReleaseEvidence/APP_STORE_CONNECT_METADATA_TEMPLATE.md" \
  "AppStore/ReleaseEvidence/$RELEASE_DATE-app-store-connect-metadata.md" \
  "App Store Connect Metadata Evidence"

create_artifact \
  "AppStore/ReleaseEvidence/APP_STORE_PRIVACY_ANSWERS_TEMPLATE.md" \
  "AppStore/ReleaseEvidence/$RELEASE_DATE-app-store-privacy-answers.md" \
  "App Store Privacy Answers Evidence"

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo "Release evidence artifact generation check passed for CalPal $version build $build."
else
  echo "Release evidence artifact skeletons created for CalPal $version build $build."
fi
