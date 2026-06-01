# CalPal 1.0 App Store Connect Draft

This draft is for App Store Connect and TestFlight preparation. It reflects the current 1.0 implementation: local EventKit calendars, speech input, deterministic parser fallback, Apple on-device intelligence when available, local preferences, no developer-hosted backend, no tracking, and no third-party analytics SDK.

Re-check every answer if analytics, crash reporting, accounts, sync, cloud AI, subscriptions, push notifications, or third-party SDKs are added.

## Product Page

Name:

CalPal

Subtitle:

Private AI calendar commands

Promotional text:

Turn voice or text into reviewable Apple Calendar changes. CalPal keeps your calendars in control and asks before sensitive updates.

Description:

CalPal is a private calendar assistant for Apple Calendar users. Speak or type a calendar command, review what CalPal understood, and confirm before sensitive changes touch your schedule.

Use CalPal to:

- See a clean daily agenda built from your existing calendars.
- Create calendar events from natural language.
- Review create, update, and delete actions before they are saved.
- Use text or manual entry when speech or on-device intelligence is unavailable.
- Open the relevant date in Apple Calendar from result cards.
- Keep lightweight preferences on device.

CalPal is not a replacement calendar. It is a focused command layer for people who already trust Apple Calendar as their source of truth.

Keywords:

calendar,assistant,schedule,planner,voice,agenda,productivity,events

Category:

Productivity

Support URL source:

Deploy `AppStore/Public/support.html` to the final public HTTPS support URL before public submission.

Marketing URL source:

Use the same public CalPal support/product page as the marketing URL for 1.0 unless a separate product site is published before submission. The source artifact is `AppStore/Public/support.html`.

Age rating notes:

No user-generated public content, web browsing, gambling, commerce, medical advice, or unrestricted internet access.

## Version Information

Version:

1.0

Build:

10

What to Test in TestFlight:

1. Complete onboarding and grant Calendar Full Access.
2. Confirm today's agenda loads from Apple Calendar.
3. Start the first voice command and grant Speech Recognition and Microphone permissions when prompted.
4. Create an event by voice: "Meeting with Alex tomorrow at 3 PM."
5. Confirm the event appears in CalPal and Apple Calendar.
6. Create an event by text using Chinese input: "明天下午三点和 Alex 开会."
7. Tap a result card's Open in Calendar action and confirm Apple Calendar opens near the event date.
8. Open an event from the agenda and stage a title or location update.
9. Confirm modify and delete flows require review, especially for recurring events.
10. Deny Speech Recognition on a fresh install and verify text/manual fallbacks.
11. Check Light Mode, Dark Mode, Dynamic Type, Reduce Motion, and Reduce Transparency.

## App Review Notes

CalPal uses Apple Calendar as the source of truth. It requests Calendar Full Access to show the user's agenda and to create, modify, or delete events only after user-directed commands and review flows.

Speech Recognition and Microphone permissions are used for optional voice calendar commands. Text entry and manual entry remain available if speech permission is denied or unavailable.

The app has no account login, no developer-hosted backend, no tracking, no third-party analytics SDK, and no advertising SDK. Lightweight preferences, such as the preferred writable calendar, are stored locally with UserDefaults. The app bundle includes `PrivacyInfo.xcprivacy` declaring UserDefaults required-reason API usage with reason `CA92.1`.

For a deterministic demo path, launch with `--calpal-demo`. Normal launches use live EventKit, speech authorization, onboarding, and device capability checks.

## Privacy Answers Draft

Data collection:

Select that the app does not collect data from this app.

Rationale:

The current implementation accesses calendars, microphone audio, speech transcription, and local preferences only to perform user-requested calendar actions on device. The app does not operate a developer-hosted backend and does not send this data to a developer server, third-party analytics service, advertising network, or tracking service.

Tracking:

No.

Data linked to user:

None collected by the developer.

Data not linked to user:

None collected by the developer.

Privacy policy summary:

CalPal uses Calendar access to show and modify events when requested by the user. Microphone and Speech Recognition are used only for optional voice commands. Local preferences are stored on device. CalPal does not track users, does not sell data, and does not upload calendar content to a developer server in 1.0.

Privacy policy draft:

Use `AppStore/PRIVACY_POLICY.md` as the 1.0 source and deploy `AppStore/Public/privacy.html` as the public privacy-policy page. A public HTTPS URL is still required before final App Store submission.

Support page draft:

Use `AppStore/Public/support.html` as the 1.0 support URL source. It covers Calendar Full Access recovery, voice-permission fallback, text entry and manual creation fallback, privacy posture, and the support contact configured on CalPal's App Store product page.

## Permission Purpose Strings

Calendar Full Access:

CalPal needs full calendar access to show, create, modify, and delete events only when you ask.

Calendar:

CalPal uses your calendars as the source of truth.

Microphone:

CalPal uses the microphone for voice calendar commands.

Speech Recognition:

CalPal uses speech recognition to transcribe calendar commands.

## Screenshots

Current generated baseline screenshots:

- `Artifacts/AppStoreScreenshots/calpal-demo-home.png`
- `Artifacts/AppStoreScreenshots/calpal-demo-home-dark.png`

These are iPhone 17 1206 x 2622 PNGs generated by:

```sh
SIMULATOR_UDID=00269E0B-5D12-406C-B4CC-C38E637767E6 bash Scripts/capture_demo_screenshots.sh
```

Before public submission, generate the final App Store screenshot set across the required display sizes and review the captions/product framing.

## Local Verification

Run:

```sh
bash Scripts/run_v10_release_gate.sh
```

This verifies script syntax, simulator tests, App Store metadata in the built app bundle, Release archive sanity, built/archive privacy surface, and screenshot artifacts. Missing screenshots are generated automatically unless `CAPTURE_SCREENSHOTS=0` is set.

For a release-build archive sanity check without App Store signing, including the archived app privacy surface, run:

```sh
bash Scripts/verify_archive_build.sh
```

To prepare the signed App Store Connect upload command without uploading, run:

```sh
bash Scripts/prepare_app_store_upload.sh
```

The script validates `AppStore/ExportOptions-AppStore.plist` against the current project version, build, bundle identifier, and development team. It prints the signed archive and upload commands by default. Re-run with `DRY_RUN=0` only when the Apple Developer account or App Store Connect API key is available and the upload should actually be sent to Apple.

To verify the deployable privacy-policy artifact before publishing the App Store privacy URL, run:

```sh
bash Scripts/verify_public_privacy_policy_artifact.sh
```

To verify the deployable support-page artifact before publishing the support or marketing URL, run:

```sh
bash Scripts/verify_public_support_page_artifact.sh
```

To verify this draft stays consistent with the privacy policy, public privacy page, readiness docs, and release evidence templates, run:

```sh
bash Scripts/verify_app_store_submission_consistency.sh
```

To verify App Store Connect field lengths and keyword formatting before copy/paste:

```sh
bash Scripts/verify_app_store_metadata_fields.sh
```

For the final public-submission evidence check after signed upload and TestFlight device smoke, fill `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` and run:

```sh
bash Scripts/verify_public_release_readiness.sh
```

Before filling the final evidence fields, create dated repo-local artifacts and complete them:

```sh
bash Scripts/create_release_evidence_artifacts.sh --date YYYY-MM-DD
```

Signed upload, screenshot review, metadata, and privacy-answer templates live in `AppStore/ReleaseEvidence/`; the TestFlight device-smoke template lives at `AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md`. The public-release verifier requires generated artifacts to be complete, not template files, inside this repository, and to match the build/date/device fields recorded in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`.

## Official Reference Links

- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple App Store Connect app privacy management: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Apple required-reason API manifest guidance: https://developer.apple.com/documentation/BundleResources/describing-use-of-required-reason-api
