#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_FILE="${EVIDENCE_FILE:-$ROOT_DIR/AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md}"
ALLOW_EXTERNAL_RELEASE_ARTIFACTS="${ALLOW_EXTERNAL_RELEASE_ARTIFACTS:-0}"

cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

require_line() {
  local expected="$1"
  if ! grep -Fxq -- "$expected" "$EVIDENCE_FILE"; then
    fail "Missing required evidence line: $expected"
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

field_value() {
  local field="$1"
  awk -F': ' -v field="$field" '$1 == field { print $2 }' "$EVIDENCE_FILE"
}

require_field_value() {
  local field="$1"
  local value
  value="$(field_value "$field")"
  if [[ -z "$value" ]]; then
    fail "Missing value for: $field"
  fi
}

require_iso_date() {
  local field="$1"
  local value
  value="$(field_value "$field")"
  if [[ ! "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    fail "$field must use YYYY-MM-DD format."
  fi
}

require_existing_artifact() {
  local field="$1"
  local value path
  value="$(field_value "$field")"
  path="$(artifact_path "$field")"
  if [[ ! -e "$path" ]]; then
    fail "$field must point to an existing artifact: $value"
  fi
}

require_repo_release_artifact() {
  local field="$1"
  local value path
  value="$(field_value "$field")"
  path="$(artifact_path "$field")"

  if [[ "$value" == *TEMPLATE.md* ]]; then
    fail "$field must point to a completed dated artifact, not a template: $value"
  fi

  if [[ "$ALLOW_EXTERNAL_RELEASE_ARTIFACTS" == "1" ]]; then
    return
  fi

  case "$path" in
    "$ROOT_DIR"/*) ;;
    *) fail "$field must point to a repo-local artifact: $value" ;;
  esac
}

require_artifact_under() {
  local field="$1"
  local expected_dir="$2"
  local value path expected_path
  value="$(field_value "$field")"
  path="$(artifact_path "$field")"
  expected_path="$ROOT_DIR/$expected_dir/"

  if [[ "$ALLOW_EXTERNAL_RELEASE_ARTIFACTS" == "1" ]]; then
    return
  fi

  case "$path" in
    "$expected_path"*) ;;
    *) fail "$field must point under $expected_dir, not: $value" ;;
  esac
}

artifact_path() {
  local field="$1"
  local value
  value="$(field_value "$field")"
  if [[ "$value" = /* ]]; then
    printf '%s\n' "$value"
  else
    printf '%s/%s\n' "$ROOT_DIR" "$value"
  fi
}

require_artifact_line() {
  local path="$1"
  local expected="$2"
  if ! grep -Fxq -- "$expected" "$path"; then
    fail "Missing required artifact line in $path: $expected"
  fi
}

require_checked_artifact_item() {
  local path="$1"
  local item="$2"
  require_artifact_line "$path" "- [x] $item"
}

artifact_field_value() {
  local path="$1"
  local field="$2"
  awk -F': ' -v field="$field" '$1 == field { print $2 }' "$path"
}

artifact_field_path() {
  local path="$1"
  local field="$2"
  local value
  value="$(artifact_field_value "$path" "$field")"
  if [[ "$value" = /* ]]; then
    printf '%s\n' "$value"
  else
    printf '%s/%s\n' "$ROOT_DIR" "$value"
  fi
}

require_artifact_field_value() {
  local path="$1"
  local field="$2"
  local value
  value="$(artifact_field_value "$path" "$field")"
  if [[ -z "$value" ]]; then
    fail "Missing value for $field in artifact: $path"
  fi
}

require_artifact_iso_date() {
  local path="$1"
  local field="$2"
  local value
  value="$(artifact_field_value "$path" "$field")"
  if [[ ! "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    fail "$field must use YYYY-MM-DD format in artifact: $path"
  fi
}

require_completed_artifact() {
  local path="$1"
  if grep -Eq 'TODO|TBD|\[ \]' "$path"; then
    fail "Artifact is incomplete: $path"
  fi

  if grep -Eq 'https?://example\.com|REPLACE_ME|YOUR_' "$path"; then
    fail "Artifact contains sample placeholder content: $path"
  fi
}

require_local_release_gate_artifact() {
  local path="$1"
  require_artifact_line "$path" "# CalPal $expected_version Local Release Gate Evidence"
  require_artifact_line "$path" "Build: $expected_build"
  require_artifact_line "$path" "Date: $(field_value "Local release gate date")"
  require_artifact_line "$path" "CAPTURE_SCREENSHOTS=0 bash Scripts/run_v10_release_gate.sh"
  require_artifact_line "$path" "- Local 1.0 release gate: PASS"
  require_artifact_line "$path" "- Unsigned archive verification: PASS"
  require_artifact_line "$path" "This artifact does not prove the external public App Store gates. The final release record still needs signed App Store Connect upload evidence, TestFlight real-device smoke evidence, public privacy-policy URL, final screenshot review, and App Store Connect metadata/privacy-answer confirmation."
}

require_signed_upload_checklist() {
  local path="$1"
  require_checked_artifact_item "$path" '`DRY_RUN=0 bash Scripts/prepare_app_store_upload.sh` completed without error.'
  require_checked_artifact_item "$path" 'The uploaded build number matches the Xcode project build.'
  require_checked_artifact_item "$path" 'App Store Connect shows the build as uploaded or processing.'
  require_checked_artifact_item "$path" 'No unexpected export, signing, validation, or upload warnings remain.'
}

require_signed_upload_fields() {
  local path="$1"
  local archive_path upload_method expected_archive_path
  archive_path="$(artifact_field_path "$path" "Archive path")"
  upload_method="$(artifact_field_value "$path" "Upload method")"
  expected_archive_path="$ROOT_DIR/Artifacts/AppStoreUpload/CalPal-$expected_version-$expected_build.xcarchive"

  if [[ "$archive_path" != "$expected_archive_path" ]]; then
    fail "Signed upload artifact Archive path must match the prepared App Store archive path: ${expected_archive_path#$ROOT_DIR/}"
  fi

  if [[ "$upload_method" != "xcodebuild -exportArchive" ]]; then
    fail "Signed upload artifact Upload method must be: xcodebuild -exportArchive"
  fi
}

require_testflight_checklist() {
  local path="$1"
  require_checked_artifact_item "$path" 'Fresh install, first launch, onboarding completes.'
  require_checked_artifact_item "$path" 'Calendar Full Access, Speech Recognition, and Microphone permissions can be granted.'
  require_checked_artifact_item "$path" 'Settings readiness shows Calendar access and Writable calendar as ready.'
  require_checked_artifact_item "$path" 'Settings readiness shows Privacy manifest as ready.'
  require_checked_artifact_item "$path" 'Voice create works for: "Meeting with Alex tomorrow at 3 PM."'
  require_checked_artifact_item "$path" 'The created event appears in CalPal.'
  require_checked_artifact_item "$path" 'The created event appears in Apple Calendar.'
  require_checked_artifact_item "$path" 'Result card Open in Calendar opens Apple Calendar near the event date.'
  require_checked_artifact_item "$path" 'Text create works for: "明天下午三点和 Alex 开会."'
  require_checked_artifact_item "$path" 'Event detail sheet opens from the agenda.'
  require_checked_artifact_item "$path" 'Event detail title or location update can be staged and reviewed before save.'
  require_checked_artifact_item "$path" 'Modify flows require review.'
  require_checked_artifact_item "$path" 'Delete flows require review.'
  require_checked_artifact_item "$path" 'Recurring-event modify/delete flows require recurrence scope selection.'
  require_checked_artifact_item "$path" 'Speech denied or unavailable state still leaves text/manual fallbacks usable.'
  require_checked_artifact_item "$path" 'Light Mode reviewed on device.'
  require_checked_artifact_item "$path" 'Dark Mode reviewed on device.'
  require_checked_artifact_item "$path" 'Dynamic Type reviewed on device.'
  require_checked_artifact_item "$path" 'Reduce Motion reviewed on device.'
  require_checked_artifact_item "$path" 'Reduce Transparency reviewed on device.'
}

require_public_release_testflight_checklist() {
  require_line '- [x] Fresh install, first launch, onboarding completes.'
  require_line '- [x] Calendar Full Access, Speech Recognition, and Microphone permissions can be granted.'
  require_line '- [x] Settings readiness shows Calendar access and Writable calendar as ready.'
  require_line '- [x] Settings readiness shows Privacy manifest as ready.'
  require_line '- [x] Voice create works for: "Meeting with Alex tomorrow at 3 PM."'
  require_line '- [x] The created event appears in CalPal.'
  require_line '- [x] The created event appears in Apple Calendar.'
  require_line '- [x] Result card Open in Calendar opens Apple Calendar near the event date.'
  require_line '- [x] Text create works for: "明天下午三点和 Alex 开会."'
  require_line '- [x] Event detail sheet opens from the agenda.'
  require_line '- [x] Event detail title or location update can be staged and reviewed before save.'
  require_line '- [x] Modify flows require review.'
  require_line '- [x] Delete flows require review.'
  require_line '- [x] Recurring-event modify/delete flows require recurrence scope selection.'
  require_line '- [x] Speech denied or unavailable state still leaves text/manual fallbacks usable.'
  require_line '- [x] Light Mode reviewed on device.'
  require_line '- [x] Dark Mode reviewed on device.'
  require_line '- [x] Dynamic Type reviewed on device.'
  require_line '- [x] Reduce Motion reviewed on device.'
  require_line '- [x] Reduce Transparency reviewed on device.'
}

require_screenshot_checklist() {
  local path="$1"
  require_checked_artifact_item "$path" 'Required iPhone screenshot sizes are uploaded or intentionally covered by App Store Connect scaling rules.'
  require_checked_artifact_item "$path" 'Light Mode screenshots show readable agenda content.'
  require_checked_artifact_item "$path" 'Dark Mode screenshots show readable agenda content.'
  require_checked_artifact_item "$path" 'Captions and visible UI match the 1.0 product promise.'
  require_checked_artifact_item "$path" 'No simulator-only debug overlays, placeholder text, private calendar content, or broken layout appears.'
  require_checked_artifact_item "$path" 'Final screenshots match the metadata draft in `AppStore/APP_STORE_CONNECT_SUBMISSION.md`.'
}

require_metadata_checklist() {
  local path="$1"
  require_checked_artifact_item "$path" 'Name, subtitle, description, keywords, support URL, and marketing URL are final.'
  require_checked_artifact_item "$path" 'Review notes match `AppStore/APP_STORE_CONNECT_SUBMISSION.md`.'
  require_checked_artifact_item "$path" 'TestFlight notes match the final real-device smoke plan.'
  require_checked_artifact_item "$path" 'Permission purpose strings in App Store Connect align with the app bundle.'
  require_checked_artifact_item "$path" 'No metadata claims a backend, analytics, tracking, or full calendar replacement behavior that 1.0 does not ship.'
}

require_privacy_answers_checklist() {
  local path="$1"
  require_checked_artifact_item "$path" 'Public privacy policy URL is live over HTTPS.'
  require_checked_artifact_item "$path" 'App Store Connect privacy answers say the developer does not collect data from this app.'
  require_checked_artifact_item "$path" 'Tracking is set to No.'
  require_checked_artifact_item "$path" 'No data linked to the user is selected.'
  require_checked_artifact_item "$path" 'No data not linked to the user is selected.'
  require_checked_artifact_item "$path" 'Answers match the 1.0 runtime boundary: no developer backend, no telemetry export, no third-party analytics SDK, and no tracking.'
}

[[ -f "$EVIDENCE_FILE" ]] || fail "Missing public release evidence file: $EVIDENCE_FILE"

if grep -Eq 'TODO|TBD|\[ \]' "$EVIDENCE_FILE"; then
  fail "Public release evidence is incomplete: remove TODO/TBD values and complete every checklist item only after evidence exists."
fi

if grep -Eq 'https?://example\.com|REPLACE_ME|YOUR_' "$EVIDENCE_FILE"; then
  fail "Public release evidence contains sample placeholder content."
fi

expected_version="$(project_setting MARKETING_VERSION)"
expected_build="$(project_setting CURRENT_PROJECT_VERSION)"
[[ -n "$expected_version" ]] || fail "Could not read MARKETING_VERSION from CalPal.xcodeproj."
[[ -n "$expected_build" ]] || fail "Could not read CURRENT_PROJECT_VERSION from CalPal.xcodeproj."

require_line "Version: $expected_version"
require_line "Build: $expected_build"
require_line "Local release gate result: PASS"
require_line "Local release gate command: bash Scripts/run_v10_release_gate.sh"
require_line "Signed archive upload result: PASS"
require_line "TestFlight real-device smoke result: PASS"
require_line "Final screenshot review result: PASS"
require_line "App Store Connect metadata result: PASS"
require_line "App Store Connect privacy answers result: PASS"
require_line "Open release blockers: NONE"
require_public_release_testflight_checklist

privacy_url="$(field_value "Public privacy policy URL")"
if [[ ! "$privacy_url" =~ ^https://[^[:space:]]+$ ]]; then
  fail "Public privacy policy URL must be an https URL."
fi

support_url="$(field_value "Public support URL")"
if [[ ! "$support_url" =~ ^https://[^[:space:]]+$ ]]; then
  fail "Public support URL must be an https URL."
fi

marketing_url="$(field_value "Public marketing URL")"
if [[ ! "$marketing_url" =~ ^https://[^[:space:]]+$ ]]; then
  fail "Public marketing URL must be an https URL."
fi

for required_field in \
  "Signed archive upload build" \
  "TestFlight real-device smoke device" \
  "TestFlight real-device smoke iOS version" \
  "Local release gate artifact" \
  "Signed archive upload evidence" \
  "TestFlight real-device smoke evidence" \
  "Final screenshot review evidence" \
  "App Store Connect metadata evidence" \
  "App Store Connect privacy answers evidence"; do
  require_field_value "$required_field"
done

for date_field in \
  "Local release gate date" \
  "Signed archive upload date" \
  "TestFlight real-device smoke date" \
  "Final screenshot review date"; do
  require_iso_date "$date_field"
done

signed_upload_build="$(field_value "Signed archive upload build")"
if [[ "$signed_upload_build" != "$expected_build" ]]; then
  fail "Signed archive upload build must match project build $expected_build."
fi

require_existing_artifact "Local release gate artifact"
require_existing_artifact "Signed archive upload evidence"
require_existing_artifact "TestFlight real-device smoke evidence"
require_existing_artifact "Final screenshot review evidence"
require_existing_artifact "App Store Connect metadata evidence"
require_existing_artifact "App Store Connect privacy answers evidence"

require_repo_release_artifact "Local release gate artifact"
require_repo_release_artifact "Signed archive upload evidence"
require_repo_release_artifact "TestFlight real-device smoke evidence"
require_repo_release_artifact "Final screenshot review evidence"
require_repo_release_artifact "App Store Connect metadata evidence"
require_repo_release_artifact "App Store Connect privacy answers evidence"

require_artifact_under "Local release gate artifact" "AppStore/SmokeTests"
require_artifact_under "Signed archive upload evidence" "AppStore/ReleaseEvidence"
require_artifact_under "TestFlight real-device smoke evidence" "AppStore/SmokeTests"
require_artifact_under "Final screenshot review evidence" "AppStore/ReleaseEvidence"
require_artifact_under "App Store Connect metadata evidence" "AppStore/ReleaseEvidence"
require_artifact_under "App Store Connect privacy answers evidence" "AppStore/ReleaseEvidence"

signed_upload_artifact="$(artifact_path "Signed archive upload evidence")"
testflight_artifact="$(artifact_path "TestFlight real-device smoke evidence")"
screenshots_artifact="$(artifact_path "Final screenshot review evidence")"
metadata_artifact="$(artifact_path "App Store Connect metadata evidence")"
privacy_answers_artifact="$(artifact_path "App Store Connect privacy answers evidence")"
local_release_gate_artifact="$(artifact_path "Local release gate artifact")"

require_local_release_gate_artifact "$local_release_gate_artifact"
require_completed_artifact "$signed_upload_artifact"
require_completed_artifact "$testflight_artifact"
require_completed_artifact "$screenshots_artifact"
require_completed_artifact "$metadata_artifact"
require_completed_artifact "$privacy_answers_artifact"

require_artifact_line "$signed_upload_artifact" "Result: PASS"
require_artifact_line "$signed_upload_artifact" "Build: $expected_build"
require_artifact_line "$signed_upload_artifact" "Date: $(field_value "Signed archive upload date")"
require_artifact_field_value "$signed_upload_artifact" "Archive path"
require_artifact_field_value "$signed_upload_artifact" "Upload method"
require_artifact_field_value "$signed_upload_artifact" "App Store Connect evidence"
require_artifact_field_value "$signed_upload_artifact" "Uploader"
require_signed_upload_fields "$signed_upload_artifact"
require_signed_upload_checklist "$signed_upload_artifact"

require_artifact_line "$testflight_artifact" "Result: PASS"
require_artifact_line "$testflight_artifact" "Build: $expected_build"
require_artifact_line "$testflight_artifact" "Date: $(field_value "TestFlight real-device smoke date")"
require_artifact_line "$testflight_artifact" "Device: $(field_value "TestFlight real-device smoke device")"
require_artifact_line "$testflight_artifact" "iOS version: $(field_value "TestFlight real-device smoke iOS version")"
require_artifact_field_value "$testflight_artifact" "Tester"
require_artifact_field_value "$testflight_artifact" "TestFlight build evidence"
require_testflight_checklist "$testflight_artifact"

require_artifact_line "$screenshots_artifact" "Result: PASS"
require_artifact_line "$screenshots_artifact" "Build: $expected_build"
require_artifact_line "$screenshots_artifact" "Date: $(field_value "Final screenshot review date")"
require_artifact_field_value "$screenshots_artifact" "Reviewer"
require_artifact_field_value "$screenshots_artifact" "Screenshot source"
require_artifact_field_value "$screenshots_artifact" "App Store Connect screenshot evidence"
require_screenshot_checklist "$screenshots_artifact"

require_artifact_line "$metadata_artifact" "Result: PASS"
require_artifact_line "$metadata_artifact" "Build: $expected_build"
require_artifact_iso_date "$metadata_artifact" "Date"
require_artifact_field_value "$metadata_artifact" "Reviewer"
require_artifact_line "$metadata_artifact" "Public support URL: $support_url"
require_artifact_line "$metadata_artifact" "Public marketing URL: $marketing_url"
require_artifact_field_value "$metadata_artifact" "App Store Connect evidence"
require_metadata_checklist "$metadata_artifact"

require_artifact_line "$privacy_answers_artifact" "Result: PASS"
require_artifact_line "$privacy_answers_artifact" "Build: $expected_build"
require_artifact_iso_date "$privacy_answers_artifact" "Date"
require_artifact_field_value "$privacy_answers_artifact" "Reviewer"
require_artifact_line "$privacy_answers_artifact" "Public privacy policy URL: $privacy_url"
require_artifact_field_value "$privacy_answers_artifact" "App Store Connect evidence"
require_privacy_answers_checklist "$privacy_answers_artifact"

echo "CalPal 1.0 public release readiness evidence verified."
