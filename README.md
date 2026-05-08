# CalPal

CalPal is an iOS calendar assistant prototype that turns natural language, text, and voice input into reviewable calendar actions.

This repository currently represents the `v0.1` MVP. The app is built with SwiftUI and EventKit, with a deterministic local parser fallback for environments where Apple on-device language models are unavailable.

## Features

- Daily agenda home screen with calendar context.
- Natural-language event create, update, and delete flows.
- Candidate selection, confirmation, correction, and manual-entry screens.
- Recurring event mutation policy that requires an explicit recurrence scope.
- EventKit-backed live calendar repository plus mock repositories for previews and tests.
- Local preference summary storage.
- Press-and-hold speech entry with text/manual fallbacks.

## Project Structure

- `CalPal/` - App source code.
- `CalPal/Features/` - SwiftUI feature views and command home state.
- `CalPal/Services/` - Calendar, parser, speech, capability, and preference services.
- `CalPal/Domain/` - Shared calendar and command models.
- `CalPalTests/` - Unit tests for parsing, mutation policy, and preference storage.
- `IMPLEMENTATION_NOTES.md` - MVP assumptions, verification notes, and known follow-ups.

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
xcodebuild -project CalPal.xcodeproj -scheme CalPalTests -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' CODE_SIGNING_ALLOWED=NO test
```

If the exact simulator is unavailable, list installed destinations and substitute a valid iOS simulator.

## v0.1 Notes

- Foundation Models runtime behavior depends on Apple Intelligence availability; the deterministic parser is used as a privacy-preserving fallback.
- Real microphone transcription and real EventKit mutations still need manual QA on a physical device with real calendars.
- The app icon is currently a placeholder.
- The "Open in Calendar" result action is present visually but not yet wired to Apple Calendar deep linking.
