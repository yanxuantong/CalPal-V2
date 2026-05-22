# CalPal

CalPal is an iOS calendar assistant prototype that turns natural language, text, and voice input into reviewable calendar actions.

This repository currently represents the `v0.3` TestFlight-readiness MVP. The app is built with SwiftUI and EventKit, with a deterministic local parser fallback for environments where Apple on-device language models are unavailable.

## Features

- Daily agenda home screen with calendar context.
- Natural-language event create, update, and delete flows.
- Candidate selection, confirmation, correction, and manual-entry screens.
- Recurring event mutation policy that requires an explicit recurrence scope.
- EventKit-backed live calendar repository plus mock repositories for previews and tests.
- Local preference summary storage.
- Tap-to-record speech entry with double-tap text and manual fallbacks.
- Result cards can jump the agenda preview to the created event's date or open that date in Apple Calendar.
- Event detail sheets let users review an existing event and stage a small update before CalPal asks for confirmation.

## Project Structure

- `CalPal/` - App source code.
- `CalPal/Features/` - SwiftUI feature views and command home state.
- `CalPal/Services/` - Calendar, parser, speech, capability, and preference services.
- `CalPal/Domain/` - Shared calendar and command models.
- `CalPal/PrivacyInfo.xcprivacy` - App privacy manifest for local preferences and tracking declarations.
- `CalPalTests/` - Unit tests for parsing, mutation policy, and preference storage.
- `IMPLEMENTATION_NOTES.md` - MVP assumptions, verification notes, and known follow-ups.
- `AppStore/` - v0.3 App Store checkpoint materials, including readiness, submission, public-release evidence, and privacy policy drafts.

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

Run the local v0.3 gate before TestFlight preparation:

```sh
bash Scripts/run_v03_release_gate.sh
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
```

To verify the generic iOS archive build without signing:

```sh
bash Scripts/verify_archive_build.sh
```

To verify the final public-release evidence after signed upload, TestFlight device smoke, screenshot review, and App Store Connect privacy metadata are complete:

```sh
bash Scripts/verify_public_release_readiness.sh
```

## v0.3 Notes

- Foundation Models runtime behavior depends on Apple Intelligence availability; the deterministic parser is used as a privacy-preserving fallback.
- Voice entry uses tap once to start recording and tap again to finish; the initial "Tap to speak" hint fades after first use.
- Created/updated-event success cards auto-dismiss, can be tapped to focus the agenda preview on the event date, and expose an Apple Calendar open action.
- EventKit create success is verified against the system calendar, and local wall-clock times use the device timezone.
- Settings includes a v0.3 readiness checklist for calendar access, writable calendars, speech, the bundled privacy manifest, Calendar opening, and store-material gates.
- The app target bundles `PrivacyInfo.xcprivacy`, declaring local `UserDefaults` preference storage under Apple's `CA92.1` required reason and no tracking domains.
- `Scripts/run_v03_release_gate.sh` runs syntax checks, privacy policy checks, simulator tests, App Store metadata verification, unsigned archive verification, and screenshot artifact validation; it can auto-create missing demo screenshots.
- The built app bundle is checked for v0.3 version metadata, Calendar/Microphone/Speech permission descriptions, and privacy manifest contents by `Scripts/verify_app_store_metadata.sh`.
- `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` is the final public-submission evidence record; `Scripts/verify_public_release_readiness.sh` intentionally fails until signed upload, TestFlight real-device smoke, public privacy URL, screenshot review, and App Store Connect metadata/privacy answers are recorded.
- `AppStore/APP_STORE_CONNECT_SUBMISSION.md` contains the v0.3 product page draft, review notes, privacy-answer rationale, and screenshot artifact list.
- `--calpal-demo` provides a deterministic screenshot/demo launch path without changing the normal live-calendar launch path.
- The deterministic parser has an expanded v0.3 sample set for realistic English and Chinese calendar commands.
- Real microphone transcription still needs manual QA on a physical device with real calendars before public App Store release.
