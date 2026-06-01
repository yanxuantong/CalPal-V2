# CalPal 1.0 App Review Readiness Runbook

This runbook is the launch-owner checklist for moving the current CalPal 1.0 build from locally verified release candidate to App Store review submission.

Use these files as the source of truth:

- `AppStore/APP_STORE_READINESS.md` - product promise, local evidence, and release gate commands.
- `AppStore/APP_STORE_CONNECT_SUBMISSION.md` - App Store Connect copy, TestFlight notes, review notes, privacy-answer draft, permission strings, and screenshot references.
- `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` - final public-release evidence record. This file should still fail verification until the external Apple and public-URL steps are genuinely complete.
- `AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md` - generated summary of current local proof and remaining external gates.

## Current Local Readiness

The local release candidate is version `1.0`, build `10`.

Local checks completed for the current candidate:

- `CAPTURE_SCREENSHOTS=0 bash Scripts/run_v10_release_gate.sh`
- `bash Scripts/run_app_store_submission_preflight.sh`
- `bash Scripts/test_public_release_readiness_verifier.sh`
- `bash Scripts/test_release_evidence_artifact_generator.sh`
- `git diff --check HEAD`

The local gate verifies simulator unit/UI tests, App Store metadata, unsigned Release archive sanity, local-only runtime posture, built/archive privacy surface, public static artifacts, screenshot artifacts, evidence-template guardrails, and canonical 1.0 gate coverage.

## Prepared Documents

These documents are ready to use before App Store Connect submission:

- Product page and review copy: `AppStore/APP_STORE_CONNECT_SUBMISSION.md`
- Privacy policy source: `AppStore/PRIVACY_POLICY.md`
- Deployable privacy page: `AppStore/Public/privacy.html`
- Deployable support or marketing page: `AppStore/Public/support.html`
- Public release evidence record: `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`
- Signed upload evidence skeleton: `AppStore/ReleaseEvidence/2026-05-31-signed-upload.md`
- TestFlight real-device smoke skeleton: `AppStore/SmokeTests/2026-05-31-testflight-real-device-smoke.md`
- Screenshot review skeleton: `AppStore/ReleaseEvidence/2026-05-31-screenshot-review.md`
- App Store Connect metadata skeleton: `AppStore/ReleaseEvidence/2026-05-31-app-store-connect-metadata.md`
- App Store privacy answers skeleton: `AppStore/ReleaseEvidence/2026-05-31-app-store-privacy-answers.md`
- Local release handoff report: `AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md`

If the final submission happens on a later date, regenerate dated evidence skeletons before filling evidence:

```sh
bash Scripts/create_release_evidence_artifacts.sh --date YYYY-MM-DD
```

## Submission Sequence

### 1. Publish Public Pages

Publish the static files over HTTPS:

- `AppStore/Public/privacy.html` -> final privacy policy URL
- `AppStore/Public/support.html` -> final support URL
- `AppStore/Public/support.html` or a reviewed product page -> final marketing URL

After URLs are live, update these fields:

- `Public privacy policy URL` in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`
- `Public support URL` in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`
- `Public marketing URL` in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`
- matching URL fields in the App Store Connect metadata and privacy-answer evidence artifacts

Then run:

```sh
bash Scripts/run_app_store_submission_preflight.sh
```

Once the TODO URLs are replaced, preflight fetches the public pages and verifies that the hosted privacy/support claims still match the local 1.0 contract.

### 2. Upload Signed Build

Use the guarded upload script:

```sh
bash Scripts/prepare_app_store_upload.sh
```

This dry-runs the signed archive/export/upload path. When Apple signing and App Store Connect credentials are ready, run:

```sh
DRY_RUN=0 bash Scripts/prepare_app_store_upload.sh
```

The completed signed-upload evidence must record:

- `Result: PASS`
- `Build: 10`
- `Archive path: Artifacts/AppStoreUpload/CalPal-1.0-10.xcarchive`
- `Upload method: xcodebuild -exportArchive`
- the App Store Connect or Transporter evidence that build `1.0 (10)` was accepted for processing

Do not mark this gate as complete until the build is visible in App Store Connect or TestFlight for the same version/build.

### 3. Run TestFlight Real-Device Smoke

Install the TestFlight build on a physical iPhone and complete `AppStore/SmokeTests/2026-05-31-testflight-real-device-smoke.md`.

Required checks:

- fresh install and onboarding
- Calendar Full Access, Speech Recognition, and Microphone permission flows
- Settings readiness rows for Calendar access, Writable calendar, and Privacy manifest
- voice create: `Meeting with Alex tomorrow at 3 PM.`
- text create: `明天下午三点和 Alex 开会.`
- created event visible in CalPal and Apple Calendar
- Open in Calendar action
- agenda event detail, staged edit, modify review, delete review, recurring-event scope review
- speech-denied fallback to text/manual entry
- Light Mode, Dark Mode, Dynamic Type, Reduce Motion, Reduce Transparency

After completion, copy its build/date/device/iOS version into `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`.

### 4. Finalize Screenshots

Use the generated screenshot artifacts as the baseline:

- `Artifacts/AppStoreScreenshots/calpal-demo-home.png`
- `Artifacts/AppStoreScreenshots/calpal-demo-home-dark.png`

Upload the final App Store screenshot set, review every uploaded image for placeholder content and layout issues, then complete `AppStore/ReleaseEvidence/2026-05-31-screenshot-review.md`.

### 5. Fill App Store Connect Metadata

Copy from `AppStore/APP_STORE_CONNECT_SUBMISSION.md` into App Store Connect:

- name, subtitle, promotional text, description, keywords, category
- support URL and marketing URL
- TestFlight `What to Test`
- App Review Notes
- permission purpose strings if App Store Connect asks for matching explanations

Then complete `AppStore/ReleaseEvidence/2026-05-31-app-store-connect-metadata.md` with reviewer, date, URL values, and App Store Connect evidence.

### 6. Fill App Privacy Answers

Use `AppStore/APP_STORE_CONNECT_SUBMISSION.md` and `AppStore/PRIVACY_POLICY.md` as the source of truth.

For CalPal 1.0:

- developer data collection: no data collected from this app
- tracking: no
- data linked to user: none collected by developer
- data not linked to user: none collected by developer
- privacy policy URL: the live HTTPS privacy page

Then complete `AppStore/ReleaseEvidence/2026-05-31-app-store-privacy-answers.md`.

### 7. Final Public Release Verification

Fill `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` with all completed evidence artifact paths and set:

- `Signed archive upload result: PASS`
- `TestFlight real-device smoke result: PASS`
- `Final screenshot review result: PASS`
- `App Store Connect metadata result: PASS`
- `App Store Connect privacy answers result: PASS`
- `Open release blockers: NONE`

Then run:

```sh
bash Scripts/verify_public_release_readiness.sh
bash Scripts/run_app_store_submission_preflight.sh
```

Only submit for App Review after both commands pass.

## Launch Owner Task List

- Publish privacy, support, and marketing URLs over HTTPS.
- Run the signed upload with Apple credentials: `DRY_RUN=0 bash Scripts/prepare_app_store_upload.sh`.
- Confirm build `1.0 (10)` is processed and selectable in App Store Connect/TestFlight.
- Complete TestFlight smoke on a physical iPhone.
- Upload and review the final screenshot set in App Store Connect.
- Copy the final product page, TestFlight, and review copy into App Store Connect.
- Complete App Store privacy answers using the local-only 1.0 privacy contract.
- Fill all dated evidence artifacts and `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`.
- Run final verification: `bash Scripts/verify_public_release_readiness.sh` and `bash Scripts/run_app_store_submission_preflight.sh`.
- Submit for App Review only after the final public-release verifier passes.
