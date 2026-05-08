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
- v0.2 adds tap-to-record voice entry, first-use command hint fade-out, created-result agenda focusing, verified EventKit create persistence, and local timezone preservation for wall-clock phrases.

## MVP limitations / follow-ups
- Foundation Models runtime behavior depends on Apple Intelligence availability on the device; when unavailable, the deterministic local parser is used as the privacy-preserving fallback.
- Real microphone transcription still needs device/manual QA with actual calendars and permissions.
- The app icon is a placeholder asset catalog.
- “Open in Calendar” result action is present visually but not yet wired to deep-link into Apple Calendar.
