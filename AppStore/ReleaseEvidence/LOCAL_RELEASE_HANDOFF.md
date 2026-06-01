# CalPal 1.0 Release Handoff Report

This report is generated from the current project version and `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`.
Regenerate it with `bash Scripts/generate_release_handoff_report.sh`.

## Release Candidate

Version: 1.0
Build: 10
Local release gate date: 2026-05-31

## Local Evidence

- Local release gate result: PASS
- Local release gate command: `bash Scripts/run_v10_release_gate.sh`
- Local release gate artifact: `AppStore/SmokeTests/2026-05-31-local-release-gate/README.md`
- Runtime privacy boundary: `bash Scripts/verify_local_only_runtime.sh`
- Public privacy artifact: `bash Scripts/verify_public_privacy_policy_artifact.sh`
- App Store material consistency: `bash Scripts/verify_app_store_submission_consistency.sh`
- Evidence skeleton generator: `bash Scripts/test_release_evidence_artifact_generator.sh`
- Simulator smoke: `bash Scripts/run_simulator_ui_smoke.sh`
- Unsigned archive verification: `bash Scripts/verify_archive_build.sh`

## Remaining External Gates

- Signed archive upload result: TODO
- TestFlight real-device smoke result: TODO
- Public privacy policy URL: TODO
- Public support URL: TODO
- Public marketing URL: TODO
- Final screenshot review result: TODO
- App Store Connect metadata result: TODO
- App Store Connect privacy answers result: TODO
- Open release blockers: TODO

## Public Release Stop Condition

Do not claim public App Store readiness until `bash Scripts/verify_public_release_readiness.sh` passes after the signed upload, TestFlight real-device smoke, public HTTPS privacy URL, screenshot review, App Store Connect metadata, and App Store privacy answers are recorded with completed repo-local evidence artifacts.
