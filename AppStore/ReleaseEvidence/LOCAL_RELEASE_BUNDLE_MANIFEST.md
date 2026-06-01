# CalPal 1.0 Local Release Bundle Manifest

This manifest is generated from the current project version and `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`.
Regenerate it with `bash Scripts/generate_release_bundle_manifest.sh`.

## Release Candidate

Version: 1.0
Build: 10
Local release gate result: PASS
Local release gate date: 2026-05-31

## Required Local Bundle Artifacts

- `AppStore/APP_STORE_CONNECT_SUBMISSION.md`
- `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`
- `AppStore/APP_STORE_READINESS.md`
- `AppStore/ExportOptions-AppStore.plist`
- `AppStore/PRIVACY_POLICY.md`
- `AppStore/Public/privacy.html`
- `AppStore/Public/support.html`
- `AppStore/ReleaseEvidence/APP_STORE_CONNECT_METADATA_TEMPLATE.md`
- `AppStore/ReleaseEvidence/APP_STORE_PRIVACY_ANSWERS_TEMPLATE.md`
- `AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md`
- `AppStore/ReleaseEvidence/SCREENSHOT_REVIEW_TEMPLATE.md`
- `AppStore/ReleaseEvidence/SIGNED_UPLOAD_TEMPLATE.md`
- `AppStore/SmokeTests/2026-05-31-local-release-gate/README.md`
- `AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md`
- `Artifacts/AppStoreScreenshots/calpal-demo-home.png`
- `Artifacts/AppStoreScreenshots/calpal-demo-home-dark.png`

## External Release Evidence Fields

- Signed archive upload result: TODO
- TestFlight real-device smoke result: TODO
- Public privacy policy URL: TODO
- Public support URL: TODO
- Public marketing URL: TODO
- Final screenshot review result: TODO
- App Store Connect metadata result: TODO
- App Store Connect privacy answers result: TODO
- Open release blockers: TODO

## Verification Commands

- `bash Scripts/run_v10_release_gate.sh`
- `bash Scripts/verify_public_release_readiness.sh`
- `bash Scripts/prepare_app_store_upload.sh`
- `bash Scripts/create_release_evidence_artifacts.sh --date YYYY-MM-DD`

## Stop Condition

This local bundle is not public App Store readiness proof by itself. Public readiness requires completed external evidence and a passing `bash Scripts/verify_public_release_readiness.sh`.
