# Parser, AI Path, and UI Smoke Test

Date: 2026-05-23
Simulator: iPhone 17 Pro, iOS 26.4, UDID 6545C4BC-C24D-45EC-880A-4C7157F5D730
Build: Debug, scheme CalPal, derived data `/tmp/CalPalIPhone17ProSmoke`

## Scope

- Verify that calendar text parsing attempts Apple Foundation Models before local fallback.
- Verify English and Chinese text commands for the workout-at-10PM case.
- Verify Today button behavior and date strip selection sizing.
- Cross-check created events in Apple Calendar.

## Commands Tested

- English: `I want to schedule workout today at 10 pm for one hour`
- Chinese: `我想要在今天晚上 10 点钟 workout 做一个小时`

## Findings

- Foundation Models path is now attempted first when `SystemLanguageModel.default.availability` is allowed and `supportsLocale` accepts the command locale.
- Regression coverage includes an injected Foundation Models generator test proving model output wins over fallback output. The test returns a 9:00 PM AI result for an English command whose fallback would parse as 10:00 PM; the result remains 9:00 PM.
- The simulator entered the Foundation Models call, but `LanguageModelSession.respond` failed with a system Foundation Models generation error:
  - `com.apple.SensitiveContentAnalysisML Code=15`
  - `NSCocoaErrorDomain Code=4865 "The data couldn't be read because it is missing."`
- This appears to be a simulator/system model-resource failure, not a text parser routing failure.
- Local fallback remains available and now parses both English and Chinese workout commands as:
  - title: `workout`
  - start: May 22, 2026, 10:00 PM
  - end: May 22, 2026, 11:00 PM

## UI Results

- Today button is hidden when the selected day is today.
- Selecting a non-today date shows the return button with accessibility label `Return to today`.
- Date strip day cells keep a stable fixed width/height during selection changes.

## Evidence

- `calpal-bilingual-workout-events.jpg`: CalPal agenda after English and Chinese command creation.
- `apple-calendar-workout-events.jpg`: Apple Calendar day view showing the generated `workout` events at 10:00 PM.

## Verification

- `xcodebuild` via XcodeBuildMCP `test_sim`, full suite: succeeded.
- `CalPalTests/NaturalLanguageCalendarParserTests/testFoundationModelsParserPrefersModelResultOverFallbackDate`: succeeded.
- `xcodebuild` via XcodeBuildMCP `build_run_sim`: succeeded.
- English text command: created `workout` event, 10:00 PM-11:00 PM.
- Chinese text command: created `workout` event, 10:00 PM-11:00 PM.
- Apple Calendar cross-check: generated `workout` events visible at 10:00 PM.

## Remaining Device Gate

Foundation Models could not complete inside this simulator because of missing system ML resources. A real-device smoke test on an Apple Intelligence-capable device is still required to prove successful non-fallback Foundation Models generation.
