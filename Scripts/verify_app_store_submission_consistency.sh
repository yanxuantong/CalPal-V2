#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC_ROOT="${DOC_ROOT:-$ROOT_DIR}"
SUBMISSION="$DOC_ROOT/AppStore/APP_STORE_CONNECT_SUBMISSION.md"
READINESS="$DOC_ROOT/AppStore/APP_STORE_READINESS.md"
PUBLIC_EVIDENCE="$DOC_ROOT/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md"
PRIVACY_MD="$DOC_ROOT/AppStore/PRIVACY_POLICY.md"
PRIVACY_HTML="$DOC_ROOT/AppStore/Public/privacy.html"
SUPPORT_HTML="$DOC_ROOT/AppStore/Public/support.html"
HANDOFF="$DOC_ROOT/AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
MANIFEST="$DOC_ROOT/AppStore/ReleaseEvidence/LOCAL_RELEASE_BUNDLE_MANIFEST.md"

cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "Missing non-empty App Store material: $path"
}

require_phrase() {
  local path="$1"
  local phrase="$2"
  if ! grep -Fqi -- "$phrase" "$path"; then
    fail "Missing required App Store material phrase in $path: $phrase"
  fi
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

expected_version="$(project_setting MARKETING_VERSION)"
expected_build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$expected_version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$expected_build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."

for material in "$SUBMISSION" "$READINESS" "$PUBLIC_EVIDENCE" "$PRIVACY_MD" "$PRIVACY_HTML" "$SUPPORT_HTML" "$HANDOFF" "$MANIFEST"; do
  require_file "$material"
done

require_phrase "$SUBMISSION" "Version:"
require_phrase "$SUBMISSION" "$expected_version"
require_phrase "$SUBMISSION" "Build:"
require_phrase "$SUBMISSION" "$expected_build"
require_phrase "$PUBLIC_EVIDENCE" "Version: $expected_version"
require_phrase "$PUBLIC_EVIDENCE" "Build: $expected_build"
require_phrase "$HANDOFF" "CalPal $expected_version Release Handoff Report"
require_phrase "$HANDOFF" "Build: $expected_build"
require_phrase "$MANIFEST" "CalPal $expected_version Local Release Bundle Manifest"
require_phrase "$MANIFEST" "Build: $expected_build"
require_phrase "$READINESS" "CalPal $expected_version"

for material in "$SUBMISSION" "$PRIVACY_MD" "$PRIVACY_HTML"; do
  require_phrase "$material" "does not collect data from this app"
  require_phrase "$material" "does not track"
  require_phrase "$material" "does not sell data"
  require_phrase "$material" "does not operate a developer-hosted backend"
  require_phrase "$material" "UserDefaults"
  require_phrase "$material" "CA92.1"
done

for material in "$SUBMISSION" "$SUPPORT_HTML"; do
  require_phrase "$material" "support contact configured on CalPal's App Store product page"
  require_phrase "$material" "Calendar Full Access"
  require_phrase "$material" "text entry and manual"
done

for material in "$SUBMISSION" "$READINESS" "$PUBLIC_EVIDENCE"; do
  require_phrase "$material" "AppStore/Public/privacy.html"
  require_phrase "$material" "AppStore/Public/support.html"
  require_phrase "$material" "AppStore/ReleaseEvidence/"
  require_phrase "$material" "AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md"
done

require_phrase "$SUBMISSION" "no account login"
require_phrase "$SUBMISSION" "no developer-hosted backend"
require_phrase "$SUBMISSION" "no third-party analytics SDK"
require_phrase "$SUBMISSION" "no advertising SDK"
require_phrase "$SUBMISSION" "None collected by the developer"
require_phrase "$SUBMISSION" "Normal launches use live EventKit"
require_phrase "$SUBMISSION" "--calpal-demo"
require_phrase "$SUBMISSION" "Support URL source:"
require_phrase "$SUBMISSION" "Marketing URL source:"
require_phrase "$PUBLIC_EVIDENCE" "Public support URL: TODO"
require_phrase "$PUBLIC_EVIDENCE" "Public marketing URL: TODO"

require_phrase "$READINESS" "Do not claim public App Store readiness until"
require_phrase "$READINESS" "completed repo-local evidence artifacts"
require_phrase "$READINESS" "AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md"
require_phrase "$HANDOFF" "Do not claim public App Store readiness until"
require_phrase "$HANDOFF" "Scripts/verify_public_release_readiness.sh"
require_phrase "$MANIFEST" "Scripts/run_v10_release_gate.sh"
require_phrase "$MANIFEST" "Scripts/verify_public_release_readiness.sh"
require_phrase "$PUBLIC_EVIDENCE" "Open release blockers: TODO"
require_phrase "$PUBLIC_EVIDENCE" "Open release blockers: NONE"

echo "App Store submission material consistency verified."
