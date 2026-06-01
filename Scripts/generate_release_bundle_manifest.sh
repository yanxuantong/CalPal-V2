#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_EVIDENCE="$ROOT_DIR/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
OUTPUT_PATH="$ROOT_DIR/AppStore/ReleaseEvidence/LOCAL_RELEASE_BUNDLE_MANIFEST.md"
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: Scripts/generate_release_bundle_manifest.sh [--check] [--output PATH]

Generates the local release bundle manifest from the current Xcode
version/build and AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md.

Options:
  --check        Fail if the existing manifest is missing or stale.
  --output PATH  Write the manifest to a custom repo-local path.
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

require_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "Missing non-empty release bundle input: $path"
}

version="$(project_setting MARKETING_VERSION)"
build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."
require_file "$PUBLIC_EVIDENCE"

case "$OUTPUT_PATH" in
  "$ROOT_DIR"/AppStore/ReleaseEvidence/*|AppStore/ReleaseEvidence/*) ;;
  *) fail "Release bundle manifest output must stay under AppStore/ReleaseEvidence: $OUTPUT_PATH" ;;
esac

if [[ "$OUTPUT_PATH" == *TEMPLATE.md* ]]; then
  fail "Release bundle manifest output must not be a template path: $OUTPUT_PATH"
fi

required_artifacts=(
  "AppStore/APP_STORE_CONNECT_SUBMISSION.md"
  "AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
  "AppStore/APP_STORE_READINESS.md"
  "AppStore/ExportOptions-AppStore.plist"
  "AppStore/PRIVACY_POLICY.md"
  "AppStore/Public/privacy.html"
  "AppStore/Public/support.html"
  "AppStore/ReleaseEvidence/APP_STORE_CONNECT_METADATA_TEMPLATE.md"
  "AppStore/ReleaseEvidence/APP_STORE_PRIVACY_ANSWERS_TEMPLATE.md"
  "AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
  "AppStore/ReleaseEvidence/SCREENSHOT_REVIEW_TEMPLATE.md"
  "AppStore/ReleaseEvidence/SIGNED_UPLOAD_TEMPLATE.md"
  "AppStore/SmokeTests/2026-05-31-local-release-gate/README.md"
  "AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md"
  "Artifacts/AppStoreScreenshots/calpal-demo-home.png"
  "Artifacts/AppStoreScreenshots/calpal-demo-home-dark.png"
)

for artifact in "${required_artifacts[@]}"; do
  require_file "$ROOT_DIR/$artifact"
done

local_gate_result="$(evidence_value "Local release gate result")"
local_gate_date="$(evidence_value "Local release gate date")"
signed_upload_result="$(evidence_value "Signed archive upload result")"
testflight_result="$(evidence_value "TestFlight real-device smoke result")"
privacy_url="$(evidence_value "Public privacy policy URL")"
support_url="$(evidence_value "Public support URL")"
marketing_url="$(evidence_value "Public marketing URL")"
screenshot_review_result="$(evidence_value "Final screenshot review result")"
metadata_result="$(evidence_value "App Store Connect metadata result")"
privacy_answers_result="$(evidence_value "App Store Connect privacy answers result")"
open_blockers="$(evidence_value "Open release blockers")"

tmp_manifest="$(mktemp "${TMPDIR:-/tmp}/calpal-release-bundle-manifest.XXXXXX")"
trap 'rm -f "$tmp_manifest"' EXIT

cat >"$tmp_manifest" <<EOF
# CalPal $version Local Release Bundle Manifest

This manifest is generated from the current project version and \`AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md\`.
Regenerate it with \`bash Scripts/generate_release_bundle_manifest.sh\`.

## Release Candidate

Version: $version
Build: $build
Local release gate result: $local_gate_result
Local release gate date: $local_gate_date

## Required Local Bundle Artifacts

EOF

for artifact in "${required_artifacts[@]}"; do
  printf -- '- `%s`\n' "$artifact" >>"$tmp_manifest"
done

cat >>"$tmp_manifest" <<EOF

## External Release Evidence Fields

- Signed archive upload result: $signed_upload_result
- TestFlight real-device smoke result: $testflight_result
- Public privacy policy URL: $privacy_url
- Public support URL: $support_url
- Public marketing URL: $marketing_url
- Final screenshot review result: $screenshot_review_result
- App Store Connect metadata result: $metadata_result
- App Store Connect privacy answers result: $privacy_answers_result
- Open release blockers: $open_blockers

## Verification Commands

- \`bash Scripts/run_v10_release_gate.sh\`
- \`bash Scripts/verify_public_release_readiness.sh\`
- \`bash Scripts/prepare_app_store_upload.sh\`
- \`bash Scripts/create_release_evidence_artifacts.sh --date YYYY-MM-DD\`

## Stop Condition

This local bundle is not public App Store readiness proof by itself. Public readiness requires completed external evidence and a passing \`bash Scripts/verify_public_release_readiness.sh\`.
EOF

if [[ "$CHECK_ONLY" == "1" ]]; then
  [[ -s "$OUTPUT_PATH" ]] || fail "Missing release bundle manifest: $OUTPUT_PATH"
  if ! cmp -s "$tmp_manifest" "$OUTPUT_PATH"; then
    echo "Release bundle manifest is stale: $OUTPUT_PATH" >&2
    echo "Run: bash Scripts/generate_release_bundle_manifest.sh" >&2
    exit 1
  fi
  echo "Release bundle manifest is current."
  exit 0
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$tmp_manifest" "$OUTPUT_PATH"
echo "Generated ${OUTPUT_PATH#$ROOT_DIR/}"
