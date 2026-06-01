#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_EVIDENCE="$ROOT_DIR/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
OUTPUT_PATH="$ROOT_DIR/AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: Scripts/generate_release_handoff_report.sh [--check] [--output PATH]

Generates the local release handoff report from the current Xcode version/build
and AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md.

Options:
  --check        Fail if the existing handoff report is missing or stale.
  --output PATH  Write the report to a custom repo-local path.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a value." >&2; exit 1; }
      OUTPUT_PATH="$2"
      shift 2
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

fail() {
  echo "$1" >&2
  exit 1
}

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

evidence_value() {
  local label="$1"
  awk -F': ' -v label="$label" '
    index($0, label ": ") == 1 {
      print substr($0, length(label) + 3)
      exit
    }
  ' "$PUBLIC_EVIDENCE"
}

version="$(project_setting MARKETING_VERSION)"
build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."
[[ -s "$PUBLIC_EVIDENCE" ]] || fail "Missing public release evidence file: $PUBLIC_EVIDENCE"

case "$OUTPUT_PATH" in
  "$ROOT_DIR"/AppStore/ReleaseEvidence/*|AppStore/ReleaseEvidence/*) ;;
  *) fail "Release handoff output must stay under AppStore/ReleaseEvidence: $OUTPUT_PATH" ;;
esac

if [[ "$OUTPUT_PATH" == *TEMPLATE.md* ]]; then
  fail "Release handoff output must not be a template path: $OUTPUT_PATH"
fi

local_gate_result="$(evidence_value "Local release gate result")"
local_gate_command="$(evidence_value "Local release gate command")"
local_gate_date="$(evidence_value "Local release gate date")"
local_gate_artifact="$(evidence_value "Local release gate artifact")"

signed_upload_result="$(evidence_value "Signed archive upload result")"
testflight_result="$(evidence_value "TestFlight real-device smoke result")"
privacy_url="$(evidence_value "Public privacy policy URL")"
support_url="$(evidence_value "Public support URL")"
marketing_url="$(evidence_value "Public marketing URL")"
screenshot_review_result="$(evidence_value "Final screenshot review result")"
metadata_result="$(evidence_value "App Store Connect metadata result")"
privacy_answers_result="$(evidence_value "App Store Connect privacy answers result")"
open_blockers="$(evidence_value "Open release blockers")"

tmp_report="$(mktemp "${TMPDIR:-/tmp}/calpal-release-handoff.XXXXXX")"
trap 'rm -f "$tmp_report"' EXIT

cat >"$tmp_report" <<EOF
# CalPal $version Release Handoff Report

This report is generated from the current project version and \`AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md\`.
Regenerate it with \`bash Scripts/generate_release_handoff_report.sh\`.

## Release Candidate

Version: $version
Build: $build
Local release gate date: $local_gate_date

## Local Evidence

- Local release gate result: $local_gate_result
- Local release gate command: \`$local_gate_command\`
- Local release gate artifact: \`$local_gate_artifact\`
- Runtime privacy boundary: \`bash Scripts/verify_local_only_runtime.sh\`
- Public privacy artifact: \`bash Scripts/verify_public_privacy_policy_artifact.sh\`
- App Store material consistency: \`bash Scripts/verify_app_store_submission_consistency.sh\`
- Evidence skeleton generator: \`bash Scripts/test_release_evidence_artifact_generator.sh\`
- Simulator smoke: \`bash Scripts/run_simulator_ui_smoke.sh\`
- Unsigned archive verification: \`bash Scripts/verify_archive_build.sh\`

## Remaining External Gates

- Signed archive upload result: $signed_upload_result
- TestFlight real-device smoke result: $testflight_result
- Public privacy policy URL: $privacy_url
- Public support URL: $support_url
- Public marketing URL: $marketing_url
- Final screenshot review result: $screenshot_review_result
- App Store Connect metadata result: $metadata_result
- App Store Connect privacy answers result: $privacy_answers_result
- Open release blockers: $open_blockers

## Public Release Stop Condition

Do not claim public App Store readiness until \`bash Scripts/verify_public_release_readiness.sh\` passes after the signed upload, TestFlight real-device smoke, public HTTPS privacy URL, screenshot review, App Store Connect metadata, and App Store privacy answers are recorded with completed repo-local evidence artifacts.
EOF

if [[ "$CHECK_ONLY" == "1" ]]; then
  [[ -s "$OUTPUT_PATH" ]] || fail "Missing release handoff report: $OUTPUT_PATH"
  if ! cmp -s "$tmp_report" "$OUTPUT_PATH"; then
    echo "Release handoff report is stale: $OUTPUT_PATH" >&2
    echo "Run: bash Scripts/generate_release_handoff_report.sh" >&2
    exit 1
  fi
  echo "Release handoff report is current."
  exit 0
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$tmp_report" "$OUTPUT_PATH"
echo "Generated ${OUTPUT_PATH#$ROOT_DIR/}"
