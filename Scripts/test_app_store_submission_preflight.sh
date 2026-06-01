#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

version="$(awk '/MARKETING_VERSION = / { value = $3; gsub(/;/, "", value); print value; exit }' CalPal.xcodeproj/project.pbxproj)"
build="$(awk '/CURRENT_PROJECT_VERSION = / { value = $3; gsub(/;/, "", value); print value; exit }' CalPal.xcodeproj/project.pbxproj)"

fixture="$tmpdir/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
cat >"$fixture" <<EOF
# CalPal $version Public Release Evidence

Version: $version
Build: $build

Local release gate result: PASS
Local release gate command: bash Scripts/run_v10_release_gate.sh
Local release gate date: 2026-05-31
Local release gate artifact: AppStore/SmokeTests/2026-05-31-local-release-gate/README.md

Signed archive upload result: TODO
Signed archive upload build: TODO
Signed archive upload date: TODO
Signed archive upload evidence: TODO

TestFlight real-device smoke result: TODO
TestFlight real-device smoke device: TODO
TestFlight real-device smoke iOS version: TODO
TestFlight real-device smoke date: TODO
TestFlight real-device smoke evidence: TODO

Public privacy policy URL: TODO
Public support URL: TODO
Public marketing URL: TODO

Final screenshot review result: TODO
Final screenshot review date: TODO
Final screenshot review evidence: TODO

App Store Connect metadata result: TODO
App Store Connect metadata evidence: TODO
App Store Connect privacy answers result: TODO
App Store Connect privacy answers evidence: TODO

Open release blockers: TODO

## Real-Device Smoke Checklist

- [ ] Fresh install, first launch, onboarding completes.
EOF

output="$tmpdir/preflight.out"
EVIDENCE_FILE="$fixture" TODAY=2099-12-29 bash Scripts/run_app_store_submission_preflight.sh >"$output"
grep -Fq "Local submission material checks:" "$output"
grep -Fq "Public static artifacts: PASS" "$output"
grep -Fq "App Store material consistency: PASS" "$output"
grep -Fq "App Store metadata field limits: PASS" "$output"
grep -Fq "Release placeholder boundaries: PASS" "$output"
grep -Fq "Published public URLs: SKIPPED" "$output"
grep -Fq "Upload dry-run: PASS" "$output"
grep -Fq "Public release status: EXTERNAL ACTIONS REQUIRED" "$output"
grep -Fq -- "- Signed archive upload result" "$output"
grep -Fq "Unchecked real-device smoke items:" "$output"
grep -Fq "Missing dated evidence skeletons:" "$output"
grep -Fq "bash Scripts/create_release_evidence_artifacts.sh --date 2099-12-29" "$output"
grep -Fq "Next owner actions:" "$output"

create_output="$tmpdir/preflight-create.out"
EVIDENCE_FILE="$fixture" TODAY=2099-12-29 CREATE_EVIDENCE_SKELETONS=1 bash Scripts/run_app_store_submission_preflight.sh >"$create_output"
grep -Fq "Creating missing dated evidence skeletons for 2099-12-29" "$create_output"
grep -Fq -- "- AppStore/ReleaseEvidence/2099-12-29-signed-upload.md" "$create_output"
test -e AppStore/ReleaseEvidence/2099-12-29-signed-upload.md
test -e AppStore/SmokeTests/2099-12-29-testflight-real-device-smoke.md
rm -f \
  AppStore/ReleaseEvidence/2099-12-29-signed-upload.md \
  AppStore/SmokeTests/2099-12-29-testflight-real-device-smoke.md \
  AppStore/ReleaseEvidence/2099-12-29-screenshot-review.md \
  AppStore/ReleaseEvidence/2099-12-29-app-store-connect-metadata.md \
  AppStore/ReleaseEvidence/2099-12-29-app-store-privacy-answers.md

if REQUIRE_PUBLIC_READY=1 EVIDENCE_FILE="$fixture" bash Scripts/run_app_store_submission_preflight.sh >/dev/null 2>&1; then
  echo "Expected REQUIRE_PUBLIC_READY=1 to fail while external evidence is incomplete." >&2
  exit 1
fi

if RUN_LOCAL_GATE=maybe EVIDENCE_FILE="$fixture" bash Scripts/run_app_store_submission_preflight.sh >/dev/null 2>&1; then
  echo "Expected invalid RUN_LOCAL_GATE to fail." >&2
  exit 1
fi

if CREATE_EVIDENCE_SKELETONS=maybe EVIDENCE_FILE="$fixture" bash Scripts/run_app_store_submission_preflight.sh >/dev/null 2>&1; then
  echo "Expected invalid CREATE_EVIDENCE_SKELETONS to fail." >&2
  exit 1
fi

bad_static_dir="$tmpdir/bad-static"
mkdir -p "$bad_static_dir/Public"
cp AppStore/Public/privacy.html "$bad_static_dir/Public/privacy.html"
cp AppStore/Public/support.html "$bad_static_dir/Public/support.html"
printf '\nTODO: broken public artifact\n' >>"$bad_static_dir/Public/support.html"
if EVIDENCE_FILE="$fixture" PUBLIC_DIR="$bad_static_dir/Public" bash Scripts/run_app_store_submission_preflight.sh >/dev/null 2>&1; then
  echo "Expected preflight to fail when local public static artifacts are invalid." >&2
  exit 1
fi

url_ready_fixture="$tmpdir/url-ready-evidence.md"
sed \
  -e 's|^Public privacy policy URL: TODO$|Public privacy policy URL: https://calpal.test/privacy|' \
  -e 's|^Public support URL: TODO$|Public support URL: https://calpal.test/support|' \
  -e 's|^Public marketing URL: TODO$|Public marketing URL: https://calpal.test/|' \
  "$fixture" >"$url_ready_fixture"
url_fixture_pages="$tmpdir/url-fixtures"
mkdir -p "$url_fixture_pages"
cp AppStore/Public/privacy.html "$url_fixture_pages/privacy.html"
cp AppStore/Public/support.html "$url_fixture_pages/support.html"
cp AppStore/Public/support.html "$url_fixture_pages/marketing.html"
url_output="$tmpdir/preflight-url-ready.out"
EVIDENCE_FILE="$url_ready_fixture" PUBLIC_URL_FIXTURE_DIR="$url_fixture_pages" TODAY=2099-12-29 bash Scripts/run_app_store_submission_preflight.sh >"$url_output"
grep -Fq "Published public URLs: PASS" "$url_output"

bad_url_pages="$tmpdir/bad-url-fixtures"
mkdir -p "$bad_url_pages"
cp AppStore/Public/privacy.html "$bad_url_pages/privacy.html"
cp AppStore/Public/support.html "$bad_url_pages/support.html"
cp AppStore/Public/support.html "$bad_url_pages/marketing.html"
printf '\nTODO: not actually published\n' >>"$bad_url_pages/marketing.html"
if EVIDENCE_FILE="$url_ready_fixture" PUBLIC_URL_FIXTURE_DIR="$bad_url_pages" bash Scripts/run_app_store_submission_preflight.sh >/dev/null 2>&1; then
  echo "Expected preflight to fail when filled public URLs fetch invalid page content." >&2
  exit 1
fi

echo "App Store submission preflight self-test passed."
