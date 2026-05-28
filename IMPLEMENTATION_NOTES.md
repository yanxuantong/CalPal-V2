# CalPal MVP Implementation Notes

## Assumptions made during implementation
- The repository did not contain an existing Xcode project, so a minimum viable `CalPal.xcodeproj` was scaffolded.
- EventKit remains the production calendar source of truth through `EventKitCalendarRepository`; previews/tests use `MockCalendarRepository`.
- The live parser is `FoundationModelsCalendarParser`, which checks `SystemLanguageModel.default.availability`, requests guided `@Generable` structured output from `LanguageModelSession`, and falls back to the deterministic bilingual parser if the on-device model is unavailable or fails.
- Tap-to-record voice uses `SFSpeechRecognizer` and `AVAudioEngine`; text/manual fallback is preserved for denied permissions, unavailable locales, no transcript, or simulator/device microphone limits.
- Recurring modify/delete flows require explicit recurrence scope selection before mutation; EventKit maps this to `.thisEvent` or `.futureEvents`.
- The generated Xcode project uses JSON `project.pbxproj` because the installed Xcode 26.4.1 in this environment parsed project files through JSON serialization.

## Build and test commands
```sh
xcodebuild -project CalPal.xcodeproj -scheme CalPal -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project CalPal.xcodeproj -scheme CalPal -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' CODE_SIGNING_ALLOWED=NO test
```

## Verification performed
- Debug simulator build passed on Xcode 26.4.1.
- Unit tests passed for parser intent extraction, bilingual corpus coverage, mutation policy gating, recurrence-scope confirmation, and local preference storage.
- Runtime smoke installed and launched the app on an iPhone 17 iOS 26.4.1 simulator; onboarding appears without an early EventKit permission prompt.
- v0.3 adds tap-to-record voice entry, first-use command hint fade-out, created-result agenda focusing, verified EventKit create persistence, Apple Calendar result deep links, event detail update staging, an in-app readiness checklist, expanded parser readiness samples, and local timezone preservation for wall-clock phrases.

## MVP limitations / follow-ups
- Foundation Models runtime behavior depends on Apple Intelligence availability on the device; when unavailable, the deterministic local parser is used as the privacy-preserving fallback.
- Real microphone transcription still needs device/manual QA with actual calendars and permissions.
- Apple Calendar opening uses the public `calshow:` date URL and opens the relevant date rather than a guaranteed exact-event detail page.
- Public App Store release still needs a signed archive upload, TestFlight device sweep, final screenshot review, public privacy-policy URL, and App Store Connect submission. Record those external gates in `AppStore/APP_STORE_PUBLIC_RELEASE_EVIDENCE.md`; `Scripts/verify_public_release_readiness.sh` is expected to fail until the evidence is complete.

## Production polish checkpoint - 2026-05-28
- Verification boundary: this checkpoint is Simulator-only. Do not install, launch, or debug on a physical iPhone while running automated checks for this pass.
- Agenda loading now uses a generation guard. If a slower `fetchEvents` call returns after the user has selected another day or triggered a newer refresh, the stale response is ignored.
- Command processing now uses a generation guard. If a parser/model/pipeline result arrives after `cancelProcessing()` or after a newer command starts, the late result is ignored.
- The agenda loading surface uses a redacted skeleton timeline instead of a bare spinner, matching the final content shape and reducing visual jump.
- UI automation anchors were added for week day chips, agenda loading, the agenda timeline, and event rows.
- The Xcode project now includes a shared `CalPal` scheme and explicitly includes the XCTest source files in `CalPalTests`, preventing false-positive zero-test runs.
- English "next Monday" now resolves to the next upcoming Monday; Chinese "下周一" keeps the following-week behavior covered by the readiness sample set.
- Competitive reference notes and release gaps live in `AppStore/ProductionPolish/2026-05-28/README.md`.
