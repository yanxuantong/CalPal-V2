# CalPal Production Polish Checkpoint - 2026-05-28

## Scope

This checkpoint focuses on pre-production reliability and interaction polish for the current CalPal V2 MVP. Verification is Simulator-only; do not install, launch, or debug on a physical iPhone for this pass.

## External Product References

Only App Store-listed products were used as references:

- Fantastical Calendar: mature natural-language calendar input, multi-view calendar surfaces, tasks, widgets, Apple Watch, availability, proposals, parser autocomplete, localization, and accessibility support. Reference: https://apps.apple.com/us/app/fantastical-calendar/id718043190
- Structured: visual daily timeline, drag-and-drop planning, inbox capture, widgets, Live Activities, accessibility, multiple languages, AI day planning, and replan flows. Reference: https://apps.apple.com/us/app/structured-daily-planner-todo/id1499198946
- Motion: AI scheduling with automatic replanning, meeting scheduling, Siri task capture, and a mobile companion model. Reference: https://apps.apple.com/us/app/motion-tasks-ai-scheduling/id1580440623
- Akiflow: unified calendar, tasks, daily agenda, integrations, reminders, and cross-device sync. Reference: https://apps.apple.com/us/app/akiflow-ai-planner-calendar/id1621279084
- Trace: AI calendar and planner with type/speak input, voice commands, screenshot-to-schedule, widgets, routines, and iCloud sync. Reference: https://apps.apple.com/us/app/trace-ai-calendar-planner/id6503812022
- Timepage: highly polished timeline calendar, week view, month heatmap, weather/travel context, widgets, and fast event creation. Reference: https://apps.apple.com/us/app/timepage-calendar-planner/id989178902

## Borrowed Production Patterns

- Keep day navigation stable under fast swipes and reloads. Calendar apps are judged harshly when an older refresh flashes or overwrites the visible day.
- Prefer skeleton placeholders over bare spinners for agenda loading, because the user already knows the surface shape they are waiting for.
- Treat cancellation as a product contract. If the user cancels a command, a late parser or calendar result must not update the visible state.
- Add stable accessibility and UI test identifiers for high-value surfaces: week day chips, loading placeholder, agenda timeline, and event rows.
- Give honest feedback for long-running work. Apple's loading guidance favors contextual progress feedback when work takes more than a moment; the command card now distinguishes transcription, model parsing, and EventKit mutation.
- Keep Foundation Models status separate from fallback status. Apple's Foundation Models documentation describes a real on-device `LanguageModelSession` generation path; users and release reviewers should not read deterministic fallback readiness as proof that generation succeeded.
- Keep the current narrow MVP focus. Competitors win breadth with tasks, widgets, sync, and scheduling links; CalPal's near-term differentiator should remain fast local AI calendar mutation with safe confirmation.

## Implemented In This Checkpoint

- Added generation guards to agenda loading so stale `fetchEvents` responses cannot overwrite the newest selected day.
- Added generation guards to command processing so late AI/parser results are ignored after cancel or a newer command.
- Replaced the agenda loading spinner with a redacted skeleton timeline.
- Added UI automation identifiers for week day chips, agenda timeline, loading placeholder, and event rows.
- Added regression tests for stale agenda loads and canceled late command results.
- Added a shared Xcode scheme and restored the `CalPalTests/*.swift` files to the test target so Simulator tests execute real XCTest cases instead of producing a zero-test success.
- Fixed English weekday semantics so "next Monday" resolves to the next upcoming Monday while Chinese "下周一" continues to mean the following week.
- Relaxed an over-specific visual luminance assertion so the snapshot test guards against blank/identical light and dark renders without encoding a brittle page-level contrast target.
- Split Settings readiness into `Foundation Models route` and `Deterministic parser fallback` so real AI availability and fallback safety are visible as separate release signals.
- Updated the processing card copy for transcription, model parsing, and EventKit saving states.
- Replaced the non-functional `Automation Mode` picker with a read-only `Safety Mode` row. CalPal currently has one real safety behavior: Auto Review before modify/delete/recurring/ambiguous mutations.
- Added a final empty-command guard before the AI/parser pipeline so blank text or empty transcripts cannot trigger accidental calendar work.
- Prevented duplicate sends from the text-entry sheet after the first valid submit.
- Connected the empty-agenda state to the manual event form with a visible `Create Manually` action instead of only mentioning the fallback in copy.
- Added parse-route observability so successful result cards can distinguish Apple Intelligence generation from local parser fallback or fallback after a Foundation Models failure.

## Apple Reference Notes

- Apple Human Interface Guidelines: Loading and progress guidance informed the move from generic "Checking calendar..." feedback to state-specific progress copy. Reference: https://developer.apple.com/design/human-interface-guidelines/loading
- Apple Foundation Models documentation: `LanguageModelSession` is the real on-device generation surface, so release docs and Settings should distinguish that route from deterministic fallback. Reference: https://developer.apple.com/documentation/FoundationModels/LanguageModelSession

## Remaining Production Gaps

- Simulator confirms routing and local flows, but Foundation Models generation still needs a real-device smoke pass before App Store submission because Simulator can lack required system ML resources.
- App Store Connect metadata, screenshots, privacy URL, signed archive upload, and TestFlight distribution remain manual release gates.
- The current MVP does not yet compete on task management, widgets, calendar-set filtering, availability links, travel/weather context, or automatic replanning. These are roadmap items, not blockers for a narrow MVP.
- Localization is only partial. The parser handles English and Chinese examples, but the visible UI is mostly English.

## Verification Plan

- Run targeted unit tests for `V2UsabilityRegressionTests` on iOS Simulator.
- Run each XCTest suite on iOS Simulator. The full suite currently covers 60 tests.
- Build the app for an iOS Simulator destination with code signing disabled.
- Do not run any real-device install, launch, or debug command in this checkpoint.

## Verification Results

- `V2UsabilityRegressionTests`: 20 passed, 0 failed.
- `PreferenceSummaryStoreTests`: 1 passed, 0 failed.
- `NaturalLanguageCalendarParserTests`: 13 passed, 0 failed.
- `CalendarMutationPolicyTests` + `LightDarkUIPresentationTests`: 9 passed, 0 failed.
- `MVPBugFixRegressionTests`: 9 passed, 0 failed.
- `VisualSnapshotRenderingTests`: 4 passed, 0 failed.
- Targeted draft-form guardrail suite: 20 passed, 0 failed.
- Targeted recovery-path suite: 27 passed, 0 failed.
- Targeted just-in-time permission suite: 3 passed, 0 failed.
- Targeted agenda-failure action suite: 2 passed, 0 failed.
- Full Simulator XCTest: 60 passed, 0 failed.
- Simulator build: passed with `CODE_SIGNING_ALLOWED=NO`.

## Follow-Up Pass - Safety Settings

- Removed the unused `AutomationMode` model and the misleading `Full Access` mode from Settings.
- Kept the Settings surface aligned with actual product behavior: EventKit mutations that are destructive, recurring, ambiguous, or modify/delete operations require confirmation.

## Follow-Up Pass - Input And Empty Agenda Guardrails

- Blank or whitespace-only text commands now fail locally with `Command Needed` and do not enter the Apple Intelligence/fallback parser pipeline.
- Valid text commands are trimmed before processing, preserving natural input while keeping parser prompts clean.
- The text-entry sheet disables both send affordances immediately after submission to prevent fast double-taps from launching duplicate commands.
- The empty-agenda screen now offers a real manual-create action, matching the existing fallback language and reducing dead-end friction when AI or permissions are unavailable.

## Follow-Up Pass - AI Route Observability

- Parsed commands now carry a structured route: `foundationModelsGenerated`, `foundationModelsUnavailable`, `foundationModelsFailedOver`, `foundationModelsLocaleUnsupported`, or `deterministicFallback`.
- Auto-applied command results annotate the success card with the route used, so a fallback result is no longer visually indistinguishable from a successful Apple Intelligence generation.
- Regression tests now prove the injected Foundation Models path is preferred over fallback output, unavailable models are labeled as unavailable fallback, failed model generations are labeled as failed-over fallback, and successful pipeline results retain their parser route.

## Follow-Up Pass - Route Preservation Through Review

- Correction, confirmation, and candidate-selection contexts now retain the parser route from the original command.
- Confirmation sheets can show the same route badge before destructive or modifying changes are applied, which keeps the user-facing review surface aligned with the final result card.
- Confirmed modify/delete results preserve the original route instead of losing that evidence after the user approves the change.

## Follow-Up Pass - Settings Recovery Deep Links

- `SettingsView(startSection:)` now honors the requested section and scrolls to the relevant Settings area after load.
- Error recovery actions that open diagnostics can land on the v0.3 readiness section instead of always starting at the top of Settings.
- Settings now refreshes capability readiness on appear and exposes an explicit `Refresh Readiness` action for permission or environment changes.
- Settings sections have stable accessibility identifiers so UI automation can target diagnostics, safety, calendar selection, and local preferences.

## Follow-Up Pass - Correction Route Preservation

- Correction sheets now show the same parser-route badge used by confirmation and result surfaces.
- Saving a corrected draft preserves the original route on the final result card, so low-confidence or missing-field flows keep Apple Intelligence versus fallback evidence after user repair.
- Manual event creation remains route-neutral because it starts from explicit user entry rather than a parser result.

## Follow-Up Pass - Candidate Selection Review Context

- Candidate-selection sheets now include the original source command, parser-route badge, and a short explanation that no calendar change has been applied yet.
- Ambiguous modify/delete choices have operation-specific titles and an explicit Cancel toolbar action.
- Candidate rows now include stable accessibility identifiers, calendar color accents, recurring-event signals, and combined accessibility labels.

## Follow-Up Pass - Confirmation Cancel Behavior

- Cancelling a confirmation is now treated as a normal no-op instead of a failed calendar command.
- The home model no longer enters the command pipeline for `.cancel`, so cancel cannot mutate EventKit and does not show a `Change Cancelled` error card.

## Follow-Up Pass - Draft Form Guardrails

- Manual-create and correction sheets now disable their save action after the first valid submit, preventing fast repeated taps from dispatching duplicate saves.
- Start/end time editing now keeps a valid event range. Moving the start time preserves the existing duration when possible, and invalid end times are repaired to the minimum valid end time.

## Follow-Up Pass - Permission Recovery Paths

- Calendar-access failures now route users to Settings instead of offering manual create as a dead-end fallback, because saving any event still requires EventKit access.
- Agenda denied/failed states now show direct `Open Settings` and `Try Again` actions instead of a passive error card.
- Regression coverage proves calendar-access unavailable command paths no longer expose a manual-create secondary action, and visual snapshots include the agenda recovery state.

## Follow-Up Pass - System Permission Recovery

- Permission recovery now distinguishes iOS Settings from CalPal's in-app diagnostics. Denied Calendar access opens the system Settings URL so users can actually grant access.
- Calendar-denied command flows use `Open iOS Settings` as the primary action and keep in-app diagnostics as the secondary context action.
- Speech permission denial keeps text entry as the primary fallback and adds `Open iOS Settings` as the recovery path.

## Follow-Up Pass - Just-In-Time Permission Timing

- Onboarding now explains that Calendar access is requested after Continue, while voice permissions are requested only when the user uses voice.
- Startup initialization no longer requests system permissions while onboarding is still visible.
- Initial app setup requests Calendar access for the agenda but leaves Speech/Microphone prompts to the first recording attempt.

## Follow-Up Pass - Agenda Failure Action Routing

- Agenda permission-denied states now route their primary action to iOS Settings, where the user can grant Calendar access.
- Generic agenda load failures now route secondary recovery to CalPal diagnostics instead of the system Settings app.
- Regression coverage locks the denied-versus-failed action split so future UI copy cannot silently point to the wrong recovery surface.
