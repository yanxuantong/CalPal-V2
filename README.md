# CalPal

CalPal is an iOS calendar assistant that turns natural language, text, and voice input into reviewable calendar actions.

This repository is now moving toward the `1.0` launch-readiness baseline. The app is built with SwiftUI and EventKit, with a deterministic local parser fallback for environments where Apple on-device language models are unavailable.

## Features

- Daily agenda home screen with calendar context.
- Natural-language event create, update, and delete flows.
- Candidate selection, confirmation, correction, and manual-entry screens.
- Recurring event mutation policy that requires an explicit recurrence scope.
- EventKit-backed live calendar repository plus mock repositories for previews and tests.
- Local preference summary storage.
- Privacy-preserving local diagnostics for command outcomes, AI route outcomes, and permission/availability blockers.
- A centralized privacy boundary that keeps remote AI text upload and telemetry export disabled for the 1.0 runtime.
- Tap-to-record speech entry with double-tap text and manual fallbacks.
- Result cards can jump the agenda preview to the created event's date or open that date in Apple Calendar.
- Event detail sheets let users review an existing event and stage a small update before CalPal asks for confirmation.
- Agenda reloads and command processing ignore stale async results after a newer day selection, command, or cancellation.

## Project Structure

- `CalPal/` - App source code.
- `CalPal/Features/` - SwiftUI feature views and command home state.
- `CalPal/Services/` - Calendar, parser, speech, capability, and preference services.
- `CalPal/Domain/` - Shared calendar and command models.
- `CalPal/PrivacyInfo.xcprivacy` - App privacy manifest for local preferences and tracking declarations.
- `CalPalTests/` - Unit tests for parsing, mutation policy, and preference storage.
- `IMPLEMENTATION_NOTES.md` - MVP assumptions, verification notes, and known follow-ups.
- `AppStore/` - 1.0 App Store launch materials, including readiness, submission, public-release evidence, and privacy policy drafts.
- `AppStore/ProductionPolish/` - Competitive references, production-polish notes, and verification boundaries for post-MVP hardening passes.

## Requirements

- macOS with Xcode 26.4.1 or compatible.
- iOS Simulator runtime for local build and test validation.
- Calendar and speech permissions for full device/manual QA.

## Build

```sh
xcodebuild -project CalPal.xcodeproj -scheme CalPal -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Test

```sh
xcodebuild -project CalPal.xcodeproj -scheme CalPal -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' CODE_SIGNING_ALLOWED=NO test
```

If the exact simulator is unavailable, list installed destinations and substitute a valid iOS simulator.

## Local Release Gate

Run the local 1.0 gate before TestFlight preparation:

```sh
bash Scripts/run_v10_release_gate.sh
```

By default, the gate refreshes demo screenshots only when they are missing. Set `CAPTURE_SCREENSHOTS=1` to force-refresh them, or `CAPTURE_SCREENSHOTS=0` to only validate existing artifacts.

## Demo / Screenshot Mode

Pass `--calpal-demo` as a launch argument to run with stable mock calendars, skip onboarding, skip permission prompts, and preload the agenda. Use this only for screenshots, demo recordings, and TestFlight review prep; normal launches still use live EventKit, speech authorization, and onboarding.

To capture deterministic baseline screenshots:

```sh
bash Scripts/capture_demo_screenshots.sh
```

Screenshots are written to `Artifacts/AppStoreScreenshots/`. Set `SIMULATOR_NAME` if the default `iPhone 17` simulator is not installed, or `SIMULATOR_UDID` when you need an exact runtime/device.

To verify the built bundle's App Store metadata:

```sh
bash Scripts/verify_app_store_metadata.sh
bash Scripts/test_app_store_metadata_verifier.sh
```

To verify generated demo screenshot artifacts:

```sh
bash Scripts/verify_demo_screenshot_artifacts.sh
bash Scripts/test_demo_screenshot_artifacts_verifier.sh
```

To verify the deployable public privacy-policy artifact:

```sh
bash Scripts/verify_public_privacy_policy_artifact.sh
bash Scripts/test_public_privacy_policy_artifact.sh
```

To verify the deployable public support-page artifact:

```sh
bash Scripts/verify_public_support_page_artifact.sh
bash Scripts/test_public_support_page_artifact.sh
```

To verify the 1.0 runtime remains local-only and free of default network/analytics SDK surfaces:

```sh
bash Scripts/verify_local_only_runtime.sh
bash Scripts/test_local_only_runtime_verifier.sh
```

To verify the built app bundle also remains free of accidental endpoints, sample URLs, and analytics/crash SDK markers:

```sh
bash Scripts/verify_built_app_privacy_surface.sh
```

To verify App Store submission materials stay consistent with the privacy policy and release evidence templates:

```sh
bash Scripts/verify_app_store_submission_consistency.sh
bash Scripts/verify_app_store_metadata_fields.sh
```

To refresh the generated release handoff report after local evidence changes:

```sh
bash Scripts/generate_release_handoff_report.sh
```

To verify the generic iOS archive build without signing, including the archived app privacy surface:

```sh
bash Scripts/verify_archive_build.sh
bash Scripts/test_archive_build_verifier.sh
```

To verify the documented UI smoke-test automation anchors still exist in source/tests:

```sh
bash Scripts/verify_smoke_automation_contract.sh
bash Scripts/test_smoke_automation_contract_verifier.sh
```

To run the narrow Simulator UI smoke path:

```sh
bash Scripts/run_simulator_ui_smoke.sh
```

To verify the final public-release evidence after signed upload, TestFlight device smoke, screenshot review, and App Store Connect privacy metadata are complete:

```sh
bash Scripts/verify_public_release_readiness.sh
```

`Scripts/run_v10_release_gate.sh` is the canonical 1.0 release gate. `Scripts/run_v03_release_gate.sh` remains only as a deprecated compatibility shim and delegates to the 1.0 gate.

For manual evidence, copy the relevant template to a dated repo-local artifact, complete it, and reference that artifact from `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`. Templates live in `AppStore/ReleaseEvidence/` plus `AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md`; final evidence fields should not point to templates or paths outside this repository.

To generate the dated evidence skeletons from those templates:

```sh
bash Scripts/create_release_evidence_artifacts.sh --date YYYY-MM-DD
```

To prepare the signed App Store Connect archive/upload commands without uploading:

```sh
bash Scripts/prepare_app_store_upload.sh
```

To print the launch-owner preflight checklist without uploading:

```sh
bash Scripts/run_app_store_submission_preflight.sh
```

After the public privacy, support, and marketing URLs are filled in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`, the preflight fetches those HTTPS URLs and verifies that the published pages still match the local CalPal privacy/support contract.

Set `CREATE_EVIDENCE_SKELETONS=1` on the preflight command if the dated release evidence files for the current day do not exist yet.

Set `DRY_RUN=0` only when the Apple Developer account or App Store Connect API key is available and the upload should actually be sent to Apple.

## 1.0 Notes

- Foundation Models runtime behavior depends on Apple Intelligence availability; the deterministic parser is used as a privacy-preserving fallback.
- A remote AI parser boundary exists for future backend work, but the 1.0 app is configured local-only and does not contact a developer-hosted AI server by default.
- Settings includes a Remote AI boundary readiness row; it becomes a manual release gate if a future build enables command-text upload.
- Voice entry uses tap once to start recording and tap again to finish; the initial "Tap to speak" hint fades after first use.
- Onboarding explains Calendar access before the first system prompt, and Speech/Microphone permissions are requested just-in-time on first voice use.
- Created/updated-event success cards auto-dismiss, can be tapped to focus the agenda preview on the event date, and expose an Apple Calendar open action.
- EventKit create success is verified against the system calendar, and local wall-clock times use the device timezone.
- Settings includes a 1.0 launch-readiness checklist for calendar access, writable calendars, speech, the bundled privacy manifest, Calendar opening, and store-material gates.
- The app target bundles `PrivacyInfo.xcprivacy`, declaring local `UserDefaults` preference storage under Apple's `CA92.1` required reason and no tracking domains.
- Settings includes local diagnostics counters stored only on device; they do not include calendar text, transcripts, event titles, or personal content.
- Settings lets the user reset local diagnostics separately from local preferences, so QA counters can be cleared without deleting calendar events or preference summaries.
- `Scripts/run_v10_release_gate.sh` runs syntax checks, privacy policy checks, simulator unit/UI tests, App Store metadata verification, unsigned Release archive verification, canonical release-gate checks, and screenshot artifact validation; it can auto-create missing demo screenshots.
- `Scripts/run_simulator_ui_smoke.sh` launches the demo app in Simulator and exercises Settings readiness, text entry, empty-day manual create, and Back to Today through XCUITest.
- `Scripts/verify_app_store_metadata.sh` checks the built Debug simulator app for 1.0 bundle id/version/build metadata, required permission usage strings, and exact source/built privacy manifest contract.
- `Scripts/test_app_store_metadata_verifier.sh` self-tests the App Store metadata verifier's rejection paths for bundle/version drift, missing permission strings, tracking-enabled source/built privacy manifests, and extra required-reason API entries.
- `Scripts/test_archive_build_verifier.sh` self-tests the Release archive verifier's contract checks with synthetic archives, including rejection for wrong bundle id, tracking-enabled privacy manifests, and missing permission text.
- `Scripts/prepare_app_store_upload.sh` validates the App Store export options and prints the signed archive/upload commands by default; it only uploads when explicitly run with `DRY_RUN=0`.
- `Scripts/test_prepare_app_store_upload.sh` self-tests the upload dry-run guardrails, export-method/team/build-number validation, and incomplete App Store Connect API-key rejection.
- `Scripts/run_app_store_submission_preflight.sh` prints the current release candidate, upload dry-run status, local submission-material checks, public URL publication status, public-release gate status, the remaining launch-owner evidence checklist, and missing dated evidence skeletons without uploading or changing external state unless `CREATE_EVIDENCE_SKELETONS=1` is explicitly set.
- `Scripts/test_app_store_submission_preflight.sh` self-tests the preflight script's incomplete-evidence, local-material-check, public-URL-check, missing-skeleton, skeleton-create, and require-public-ready behaviors.
- `Scripts/verify_public_privacy_policy_artifact.sh` validates the Markdown privacy policy and deployable `AppStore/Public/privacy.html` artifact, including basic static-page metadata and disallowed markup checks, before the public URL is recorded.
- `Scripts/test_public_privacy_policy_artifact.sh` self-tests the privacy policy verifier's rejection paths for placeholders, unsafe markup, missing required privacy claims, duplicate headings, and insecure links.
- `Scripts/verify_public_support_page_artifact.sh` validates the deployable `AppStore/Public/support.html` artifact for App Store support or marketing URL use.
- `Scripts/test_public_support_page_artifact.sh` self-tests the support page verifier's rejection paths for placeholders, unsafe markup, missing support claims, duplicate headings, and App Store submission pointer drift.
- `Scripts/verify_public_static_artifacts.sh` checks the whole `AppStore/Public/` publish directory, allowing only the expected static HTML artifacts and rejecting external links, insecure URLs, form/script/embed markup, and placeholders.
- `Scripts/test_public_static_artifacts_verifier.sh` self-tests the public static artifact verifier's rejection paths for unexpected publish files, external links, missing relative link targets, and placeholders.
- `Scripts/verify_public_url_publication.sh` fetches the final public privacy, support, and marketing URLs from the release evidence file and verifies that the hosted pages still contain the expected CalPal 1.0 privacy/support claims without placeholders or unsafe markup.
- `Scripts/test_public_url_publication_verifier.sh` self-tests the hosted public URL verifier with local fixtures, including missing URLs, non-HTTPS URLs, placeholder content, missing privacy claims, and unsafe markup.
- `Scripts/verify_local_only_runtime.sh` checks the live runtime privacy configuration, rejects default remote endpoints/URLSession networking, and flags common analytics/crash/attribution SDK references for the 1.0 local-only release.
- `Scripts/test_local_only_runtime_verifier.sh` self-tests local-only runtime rejection paths for non-local remote AI policy, HTTP endpoints, URLSession networking, Swift package dependencies, and analytics/crash SDK markers.
- `Scripts/verify_built_app_privacy_surface.sh` checks the built app executable and bundle for accidental endpoints, sample URLs, URLSession markers, and common analytics/crash/attribution SDK markers.
- `Scripts/verify_app_store_submission_consistency.sh` checks that App Store draft copy, readiness docs, privacy policy, public privacy page, and release evidence templates agree on version/build and privacy claims.
- `Scripts/test_app_store_submission_consistency.sh` self-tests the App Store material consistency verifier's rejection paths for build drift, missing privacy/support claims, public artifact pointer drift, and missing handoff warnings.
- `Scripts/verify_app_store_metadata_fields.sh` checks App Store Connect draft field limits for name, subtitle, promotional text, description, TestFlight notes, review notes, and the 100-byte comma-separated keyword field.
- `Scripts/test_app_store_metadata_fields.sh` self-tests metadata field rejection paths for overlong subtitles, keyword spacing, short keywords, overlong keyword bytes, and HTML in plain-text fields.
- `Scripts/create_release_evidence_artifacts.sh` creates dated repo-local evidence skeletons for signed upload, TestFlight device smoke, screenshot review, metadata, and privacy answers.
- `Scripts/test_release_evidence_artifact_generator.sh` self-tests the evidence generator's check-only, write, overwrite, and invalid-date guards.
- `Scripts/generate_release_handoff_report.sh` keeps `AppStore/ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md` synchronized with the current project version/build and public release evidence file.
- `Scripts/verify_canonical_release_gate.sh` verifies the active 1.0 version/build, keeps `run_v10_release_gate.sh` as the canonical gate, and ensures the old v0.3 entrypoint remains only a shim.
- `Scripts/verify_demo_screenshot_artifacts.sh` verifies the Light/Dark demo screenshots are referenced by the App Store draft, readable PNGs, portrait, matching dimensions, large enough for review evidence, and not identical files.
- `Scripts/test_demo_screenshot_artifacts_verifier.sh` self-tests screenshot verifier rejection paths for identical Light/Dark images, missing App Store draft references, mismatched dimensions, and non-PNG artifacts.
- `Scripts/verify_smoke_automation_contract.sh` checks the documented smoke-test accessibility identifiers against the app source and regression tests.
- `Scripts/test_smoke_automation_contract_verifier.sh` self-tests the smoke automation contract verifier's rejection paths for missing contracts, empty contracts, and documented IDs that are absent from source/tests.
- The built app bundle and unsigned Release archive are checked for 1.0 version metadata, Calendar/Microphone/Speech permission descriptions, and the exact local-only privacy manifest contract by `Scripts/verify_app_store_metadata.sh` and `Scripts/verify_archive_build.sh`; the manifest must declare no collected data, no tracking, no tracking domains, and only the UserDefaults `CA92.1` required-reason API.
- `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` is the final public-submission evidence record; `Scripts/verify_public_release_readiness.sh` intentionally fails until signed upload, completed TestFlight real-device smoke evidence, public privacy URL, screenshot review, and App Store Connect metadata/privacy answers are recorded. The verifier reads the current Xcode marketing/build version and requires completed repo-local evidence artifacts plus ISO dates for the manual gates.
- `AppStore/APP_STORE_CONNECT_SUBMISSION.md` contains the 1.0 product page draft, review notes, privacy-answer rationale, and screenshot artifact list.
- `--calpal-demo` provides a deterministic screenshot/demo launch path without changing the normal live-calendar launch path.
- The deterministic parser has an expanded launch sample set for realistic English and Chinese calendar commands.
- Real microphone transcription still needs manual QA on a physical device with real calendars before public App Store release.
- The 2026-05-28 production-polish checkpoint is documented in `AppStore/ProductionPolish/2026-05-28/README.md`; its automated verification boundary is iOS Simulator only.
