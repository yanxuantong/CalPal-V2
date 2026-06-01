#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_DATE="${TEST_DATE:-2099-12-30}"

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
[[ -n "$version" && -n "$build" ]]

artifacts=(
  "AppStore/ReleaseEvidence/$TEST_DATE-signed-upload.md"
  "AppStore/SmokeTests/$TEST_DATE-testflight-real-device-smoke.md"
  "AppStore/ReleaseEvidence/$TEST_DATE-screenshot-review.md"
  "AppStore/ReleaseEvidence/$TEST_DATE-app-store-connect-metadata.md"
  "AppStore/ReleaseEvidence/$TEST_DATE-app-store-privacy-answers.md"
)

cleanup() {
  rm -f "${artifacts[@]}"
}
trap cleanup EXIT
cleanup

bash Scripts/create_release_evidence_artifacts.sh --check --date "$TEST_DATE" >/dev/null

for artifact in "${artifacts[@]}"; do
  if [[ -e "$artifact" ]]; then
    echo "--check unexpectedly created $artifact" >&2
    exit 1
  fi
done

bash Scripts/create_release_evidence_artifacts.sh --date "$TEST_DATE" >/dev/null

for artifact in "${artifacts[@]}"; do
  if [[ ! -s "$artifact" ]]; then
    echo "Expected generated artifact to exist: $artifact" >&2
    exit 1
  fi
  if [[ "$artifact" == *TEMPLATE.md* ]]; then
    echo "Generated artifact path must not be a template path: $artifact" >&2
    exit 1
  fi
  if ! grep -Fq "CalPal $version" "$artifact"; then
    echo "Generated artifact does not include current marketing version: $artifact" >&2
    exit 1
  fi
  if ! grep -Fq "Date: $TEST_DATE" "$artifact"; then
    echo "Generated artifact does not include requested date: $artifact" >&2
    exit 1
  fi
  if ! grep -Fq "Build: $build" "$artifact"; then
    echo "Generated artifact does not include current build: $artifact" >&2
    exit 1
  fi
done

if bash Scripts/create_release_evidence_artifacts.sh --date "$TEST_DATE" >/dev/null 2>&1; then
  echo "Expected generator to refuse overwriting existing artifacts without --force." >&2
  exit 1
fi

bash Scripts/create_release_evidence_artifacts.sh --force --date "$TEST_DATE" >/dev/null

if bash Scripts/create_release_evidence_artifacts.sh --date 2099-99-99 --check >/dev/null 2>&1; then
  echo "Expected generator to reject invalid calendar dates." >&2
  exit 1
fi

if bash Scripts/create_release_evidence_artifacts.sh --unknown >/dev/null 2>&1; then
  echo "Expected generator to reject unknown arguments." >&2
  exit 1
fi

echo "Release evidence artifact generator self-test passed."
