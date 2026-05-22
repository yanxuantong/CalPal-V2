# CalPal v0.3 App Store Readiness

CalPal v0.3 is the TestFlight-readiness pass for the current MVP. The goal is to make the existing calendar-command loop credible for real users before a public App Store submission.

## Product Positioning

CalPal is a private calendar assistant for Apple Calendar users. Users can speak or type a calendar command, review sensitive changes before they are saved, and fall back to manual entry when AI, speech, or permissions are unavailable.

Primary promise:

> Speak or type. CalPal reviews the calendar change before it touches your schedule.

Do not market v0.3 as a full calendar replacement. It is an agenda-first command layer on top of the user's existing calendars.

## v0.3 Completion Criteria

- The app builds and tests on the shared `CalPal` scheme.
- Calendar create, update, and delete flows remain reviewable before mutation.
- Result cards can focus the in-app agenda and open the event date in Apple Calendar.
- Event rows open an event detail sheet with small update staging.
- Text entry, manual entry, and unavailable-state fallbacks remain reachable.
- Settings includes a v0.3 readiness checklist that separates automated readiness from real-device and store-material gates.
- The app target bundles `PrivacyInfo.xcprivacy` with the local UserDefaults required-reason API declaration and no tracking domains.
- Light and Dark Mode surfaces render without blank or obviously broken screenshots.
- The deterministic parser has a regression sample set covering realistic English and Chinese commands.

## Verification Commands

```sh
bash Scripts/run_v03_release_gate.sh
xcodebuild -project CalPal.xcodeproj -scheme CalPal -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project CalPal.xcodeproj -scheme CalPal -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' CODE_SIGNING_ALLOWED=NO test
```

## Demo / Screenshot Mode

Launch CalPal with `--calpal-demo` to use stable mock calendars, skip onboarding, skip permission prompts, and preload the agenda. This mode is for screenshots, demo recording, and TestFlight review preparation only; normal launches still use live EventKit, speech authorization, and onboarding.

Use the repeatable capture script for baseline home screenshots:

```sh
bash Scripts/capture_demo_screenshots.sh
```

The script builds the simulator app, launches with `--calpal-demo`, and writes light/dark screenshots to `Artifacts/AppStoreScreenshots/`. Set `SIMULATOR_NAME` to another installed simulator if `iPhone 17` is unavailable, or `SIMULATOR_UDID` when an exact runtime/device is required.

Verify the built bundle metadata before TestFlight upload:

```sh
bash Scripts/verify_app_store_metadata.sh
```

Verify the generic iOS archive build before signing/upload:

```sh
bash Scripts/verify_archive_build.sh
```

After signed upload and real-device TestFlight smoke are complete, record the evidence in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` and run:

```sh
bash Scripts/verify_public_release_readiness.sh
```

## Current Local Evidence

- `bash Scripts/run_v03_release_gate.sh` passes, covering script syntax, privacy policy checks, simulator tests, App Store metadata verification, unsigned archive verification, and screenshot artifact validation. Missing screenshots are generated automatically by the gate unless `CAPTURE_SCREENSHOTS=0` is set.
- `bash Scripts/verify_archive_build.sh` confirms a Release generic iOS archive can be produced without signing and contains `CalPal.app` plus `PrivacyInfo.xcprivacy`.
- `xcodebuild test -project CalPal.xcodeproj -scheme CalPal -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CalPalV03FinalTests CODE_SIGNING_ALLOWED=NO` passes.
- `bash -n Scripts/capture_demo_screenshots.sh` passes.
- `bash Scripts/verify_app_store_metadata.sh` confirms the built app has version `0.3`, build `3`, Calendar/Microphone/Speech permission usage descriptions, and bundled `PrivacyInfo.xcprivacy` with UserDefaults `CA92.1`.
- `SIMULATOR_UDID=00269E0B-5D12-406C-B4CC-C38E637767E6 bash Scripts/capture_demo_screenshots.sh` builds, installs, launches `--calpal-demo`, and writes `Artifacts/AppStoreScreenshots/calpal-demo-home.png` plus `Artifacts/AppStoreScreenshots/calpal-demo-home-dark.png`.
- The generated iPhone 17 screenshots are 1206 x 2622 PNGs and show a populated demo agenda in Light and Dark Mode.

## Required Real-Device Smoke Test

Run this on a physical iPhone before public App Store submission:

1. Fresh install, first launch, complete onboarding.
2. Grant Calendar Full Access, Speech Recognition, and Microphone permissions.
3. Open Settings and confirm Calendar access plus Writable calendar show as ready in the v0.3 readiness section.
4. Confirm Privacy manifest shows as ready in the v0.3 readiness section.
5. Create by voice: "Meeting with Alex tomorrow at 3 PM."
6. Confirm the event appears in CalPal and the system Calendar app.
7. Tap the result card's Open in Calendar action and confirm Calendar opens near the event date.
8. Create by text using a Chinese command, for example "明天下午三点和 Alex 开会."
9. Open an existing event from the agenda and stage a title or location update.
10. Confirm modify/delete flows still require review, especially for recurring events.
11. Deny Speech Recognition on a second install or reset permissions and verify text/manual fallbacks.
12. Check Light Mode, Dark Mode, Dynamic Type, Reduce Motion, and Reduce Transparency.

## App Store Metadata Draft

Use `AppStore/APP_STORE_CONNECT_SUBMISSION.md` as the canonical v0.3 draft for product-page copy, TestFlight notes, review notes, privacy-answer rationale, permission purpose strings, and screenshot artifact references.

Subtitle:

Private AI calendar commands.

Short description:

CalPal helps you turn voice or text into reviewable calendar changes. It keeps your existing calendars as the source of truth, asks before modifying sensitive events, and falls back gracefully when speech or on-device AI is unavailable.

Keywords:

calendar, assistant, schedule, planner, voice, agenda, AI, productivity

Privacy notes:

- Calendar access is used to show, create, modify, and delete events only when the user requests it.
- Microphone and speech recognition are used for voice calendar commands.
- Lightweight local preferences store the preferred writable calendar.
- `PrivacyInfo.xcprivacy` declares the local UserDefaults preference use under Apple's `CA92.1` required reason and declares no tracking domains.
- On-device Apple intelligence is used when available; deterministic local parsing remains available as fallback.
- `AppStore/PRIVACY_POLICY.md` is the v0.3 privacy policy draft; publish it to a public URL before final App Store submission.

## Public Release Gate

Do not claim public App Store readiness until `bash Scripts/verify_public_release_readiness.sh` passes. That gate requires recorded evidence for the local release gate, signed App Store Connect/TestFlight upload, real-device smoke test, public privacy-policy URL, final screenshot review, App Store Connect metadata/privacy answers, and zero open release blockers.
