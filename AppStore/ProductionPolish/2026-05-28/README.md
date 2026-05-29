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
- Added an aggregate Settings readiness summary so automated-ready items cannot be confused with remaining manual App Store/TestFlight gates.
- Updated the processing card copy for transcription, model parsing, and EventKit saving states.
- Replaced the non-functional `Automation Mode` picker with a read-only `Safety Mode` row. CalPal currently has one real safety behavior: Auto Review before modify/delete/recurring/ambiguous mutations.
- Added a final empty-command guard before the AI/parser pipeline so blank text or empty transcripts cannot trigger accidental calendar work.
- Prevented duplicate sends from the text-entry sheet after the first valid submit.
- Connected the empty-agenda state to the manual event form with a visible `Create Manually` action instead of only mentioning the fallback in copy.
- Added parse-route observability so successful result cards can distinguish Apple Intelligence generation from local parser fallback or fallback after a Foundation Models failure.
- Tightened speech-unavailable recovery so `Create Manually` is not offered when Calendar access is denied and the manual save path would fail.
- Added stable UI automation identifiers for unavailable-state recovery actions.
- Added stable UI automation identifiers for each Settings readiness checklist item.
- Hardened processing cancellation so late speech transcripts cannot re-enter the command pipeline after the user cancels.
- Cleared stale command feedback when a new command stage begins so old result/error cards do not remain visible during new work.
- Added stable UI automation identifiers for the processing card and its Cancel action.
- Added stable UI automation identifiers for common sheet dismiss actions across text entry, manual create, correction, confirmation, candidate selection, event detail, and calendar chooser flows.
- Added stable UI automation identifiers for the home Settings and Back to Today actions.
- Added a machine-checked smoke automation contract for critical accessibility identifiers and wired it into the local release gate.
- Guarded Speech authorization completion so late denied/restricted results are ignored after recording cancellation.
- Guarded Speech startup completion so cancellation during async recognizer startup cannot leave transcription running behind an idle UI.
- Added foreground resume refresh so capability readiness and agenda content recover after users return from iOS Settings permission changes.
- Added scene lifecycle cancellation so active recording or command processing stops when CalPal becomes inactive or leaves the foreground.
- Preserved completed result feedback across scene interruptions by pausing the auto-dismiss timer while CalPal is inactive, resuming it after foreground activation, and returning the command state to idle when the result clears.

## Apple Reference Notes

- Apple Human Interface Guidelines: Loading and progress guidance informed the move from generic "Checking calendar..." feedback to state-specific progress copy. Reference: https://developer.apple.com/design/human-interface-guidelines/loading
- Apple Human Interface Guidelines: Destructive buttons should visually communicate destructive impact; recurring delete/apply confirmations now make the selected scope explicit in both copy and action labels. Reference: https://developer.apple.com/design/human-interface-guidelines/buttons
- Apple Foundation Models documentation: `LanguageModelSession` is the real on-device generation surface, so release docs and Settings should distinguish that route from deterministic fallback. Reference: https://developer.apple.com/documentation/FoundationModels/LanguageModelSession

## Remaining Production Gaps

- Simulator confirms routing and local flows, but Foundation Models generation still needs an owner-run real-device smoke pass before App Store submission because Simulator can lack required system ML resources. Codex verification for this checkpoint remains Simulator-only.
- App Store Connect metadata, screenshots, privacy URL, signed archive upload, and TestFlight distribution remain manual release gates.
- The current MVP does not yet compete on task management, widgets, calendar-set filtering, availability links, travel/weather context, or automatic replanning. These are roadmap items, not blockers for a narrow MVP.
- Localization is only partial. The parser handles English and Chinese examples, but the visible UI is mostly English.

## Verification Plan

- Run targeted unit tests for `V2UsabilityRegressionTests` on iOS Simulator.
- Run each XCTest suite on iOS Simulator. The full suite currently covers 96 tests.
- Build the app for an iOS Simulator destination with code signing disabled.
- Run `Scripts/verify_smoke_automation_contract.sh` to confirm documented smoke-test identifiers still exist in source/tests.
- Do not run any real-device install, launch, or debug command in this checkpoint.

## Verification Results

- `V2UsabilityRegressionTests`: 40 passed, 0 failed.
- `PreferenceSummaryStoreTests`: 1 passed, 0 failed.
- `NaturalLanguageCalendarParserTests`: 13 passed, 0 failed.
- `CalendarMutationPolicyTests` + `LightDarkUIPresentationTests`: 9 passed, 0 failed.
- `MVPBugFixRegressionTests`: 14 passed, 0 failed.
- `VisualSnapshotRenderingTests`: 5 passed, 0 failed.
- Targeted draft-form guardrail suite: 20 passed, 0 failed.
- Targeted recovery-path suite: 27 passed, 0 failed.
- Targeted just-in-time permission suite: 3 passed, 0 failed.
- Targeted agenda-failure action suite: 2 passed, 0 failed.
- Targeted permission-drift recovery tests: passed for access-denied search, confirmation mutation, unavailable action metadata, and pipeline recovery.
- Targeted writable-calendar tests: passed for read-only preferred-calendar fallback and no-writable-calendar recovery.
- Targeted manual-form calendar target tests: passed for selected-calendar display state and default-writable fallback copy.
- Targeted draft normalization tests: passed for trimming title/location/notes before save and rejecting whitespace-only titles before repository writes.
- Targeted patch normalization tests: passed for trimming update patches before EventKit mutation, preserving clear-field intent, and rejecting no-op patches after normalization.
- Full Simulator XCTest: 96 passed, 0 failed.
- Simulator build: passed with `CODE_SIGNING_ALLOWED=NO`.
- Smoke automation contract verification: passed.
- Local v0.3 release gate: passed with `CAPTURE_SCREENSHOTS=0`.
- Release script syntax checks: passed for screenshot capture and local release gate scripts.
- Demo screenshot capture: passed on iPhone 17 Simulator using the built app's `CFBundleIdentifier`; generated light and dark screenshots at 1206x2622.

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

## Follow-Up Pass - Release Script Robustness

- Demo screenshot capture now reads the built app's `CFBundleIdentifier` from `Info.plist` instead of relying on a hard-coded bundle id.
- The local release gate now rejects screenshot artifacts that are readable but too small to be credible App Store review evidence.

## Follow-Up Pass - Permission Drift Recovery

- Mock calendar access now fails reads and writes when authorization is denied, matching the real EventKit permission contract more closely in tests.
- Existing-event search and confirmation-time update/delete failures now route Calendar access denial to iOS Settings plus CalPal diagnostics instead of a generic retry/manual path.
- Unavailable-state actions now use system-icon labels, making recovery buttons easier to scan and closer to standard iOS action affordances.

## Follow-Up Pass - Writable Calendar Fidelity

- Mock calendar writes now mirror the EventKit repository's writable-calendar selection: preferred writable calendar first, default writable fallback next, and failure when no writable calendar exists.
- Save attempts with only read-only calendars now route to CalPal diagnostics instead of suggesting manual retry, because manual creation cannot succeed without a writable EventKit calendar.
- Regression coverage locks both the read-only preferred-calendar fallback and the no-writable-calendar recovery path.

## Follow-Up Pass - Manual Form Calendar Target

- Manual and correction event forms now show the target calendar row before save, reducing uncertainty about where the event will be written.
- Drafts without an explicit selected calendar show `Default writable calendar`, matching EventKit's write-target fallback behavior.
- Regression coverage locks selected-calendar display state and the fallback target copy.

## Follow-Up Pass - Draft Save Normalization

- Drafts are normalized in the command pipeline before EventKit writes: title, location, and notes are trimmed, and blank optional fields become absent values.
- Whitespace-only titles are rejected before reaching the calendar repository, keeping manual, correction, and AI-generated save paths on the same validation contract.
- Regression coverage locks both successful normalization and pre-repository rejection for invalid titles.

## Follow-Up Pass - Patch Save Normalization

- Modify confirmations now normalize update patches before EventKit writes, trimming title, location, and notes before repository mutation.
- Blank optional patch fields are preserved as explicit clear operations for location and notes; blank titles still normalize to no title change.
- Patches that become empty after normalization are rejected with a `No Changes` failure instead of mutating EventKit with blank text.
- Regression coverage locks trimmed patch updates, clear-field intent, and no-op patch rejection.

## Follow-Up Pass - Confirmation Review Completeness

- The confirmation review card now shows title, start/end time, location, and notes patch details before any update is applied.
- Blank location and notes changes are displayed as explicit `Clear location` / `Clear notes` intents instead of disappearing from the review UI.
- Regression coverage locks the confirmation summary model and accessibility summary for optional-field clear intent.

## Follow-Up Pass - Event Detail Review Guardrail

- Event detail quick updates now show inline review readiness: missing title, no changes, or the number of changes ready for review.
- The `Review Update` action is disabled when the edited title is blank, preventing users from entering a confirmation flow that would later fail as a no-op or invalid update.
- Regression coverage locks title-required, unchanged, and ready-to-review states.

## Follow-Up Pass - Draft Save Readiness Feedback

- Manual create and correction forms now show inline save readiness for missing title, invalid time range, saving state, and ready-to-save state.
- Save actions share the same readiness model as the visible hint, keeping disabled toolbar actions explainable in context.
- Regression coverage locks blocked-save messages and ready/saving state transitions.

## Follow-Up Pass - Text Command Send Readiness

- Text command entry now shows inline send readiness for empty input, sending state, and ready-to-send state.
- Main and toolbar send actions share the same readiness model, making disabled send buttons explainable before the parser pipeline is entered.
- Regression coverage locks empty, sending, and ready command-entry states.

## Follow-Up Pass - Calendar Chooser Clarity

- Calendar chooser rows now expose writable/read-only status directly instead of relying only on disabled-row behavior.
- The chooser sheet now includes an explicit Cancel action and stable row identifiers for UI automation.
- Regression coverage renders writable and read-only chooser rows so the status affordance remains visible.

## Follow-Up Pass - Confirmation Before-Context Completeness

- Confirmation `Before` cards now include event time, calendar, location, notes, and repeating-event status when present.
- Location and notes are trimmed before display, keeping review copy aligned with the normalized save path.
- Regression coverage locks the confirmation detail model and accessibility summary for recurring events with location and notes.

## Follow-Up Pass - Recurring Scope Confirmation Clarity

- Recurring modify/delete confirmations now show a scope-specific impact card after the segmented control.
- The primary confirmation button changes from generic copy to explicit labels such as `Delete This Event` or `Delete This and Future Events`.
- Regression coverage locks the recurrence-scope action labels and warning copy so future changes keep destructive scope visible.

## Follow-Up Pass - Calendar Target Account Clarity

- Manual-create, correction, and default-calendar readiness copy now include the calendar account/source when it is known.
- Draft write targets render as `Calendar · Account`, reducing ambiguity when users have duplicate calendar names across iCloud, Google, or other accounts.
- Regression coverage locks selected-calendar and policy-applied draft summaries so the pre-save review copy matches the actual writable target.

## Follow-Up Pass - No-Match Fallback Target Consistency

- Modify/delete commands that find no matching event now build their correction fallback draft with the same preferred writable calendar logic as create commands.
- The `No Matching Event` correction sheet can show the actual `Calendar · Account` target before the user saves a fallback event manually.
- Regression coverage locks the no-match correction path against losing preferred-calendar and account/source context.

## Follow-Up Pass - Saved Result Target Feedback

- Create and update success cards now include the saved event's `Calendar · Account` target in the result summary.
- The post-save confirmation now closes the loop with the same target clarity shown before saving.
- Regression assertions cover both auto-created events and confirmed updates so result cards cannot silently drop the write target.

## Follow-Up Pass - Destructive Result Context

- Delete success cards now include the deleted event's time, calendar, and account when the pre-delete event context is available.
- Recurring delete results include the selected recurrence scope, so the final destructive feedback matches the confirmation choice.
- Regression assertions lock deleted-event result copy for parser-route preservation, calendar/account context, and recurrence-scope context.

## Follow-Up Pass - Candidate Selection Account Context

- Ambiguous modify/delete candidate rows now display `Calendar · Account` instead of calendar title only.
- Candidate accessibility summaries include the account/source, reducing the chance of selecting the wrong duplicate event by VoiceOver.
- Regression coverage locks the candidate event account summary used by the row and accessibility label.

## Follow-Up Pass - Agenda Row Account Context

- Agenda event rows now display `Calendar · Account · Time` instead of calendar title plus time only.
- Agenda row accessibility summaries include the account/source before users open event detail and update options.
- The calendar/account summary now lives on `CalendarEvent`, keeping agenda, candidate selection, confirmation, and result feedback aligned.

## Follow-Up Pass - Event Detail Clear-Intent Readiness

- Event detail quick updates now surface clear intents in the inline readiness hint before opening the confirmation sheet.
- Clearing optional fields such as location or notes is described as part of the review state instead of only appearing later in the confirmation card.
- Regression coverage locks the clear-count copy for quick-update readiness feedback.

## Follow-Up Pass - Readiness Summary Clarity

- Settings now shows an aggregate readiness summary before the itemized checklist.
- The summary distinguishes ready automated checks from remaining manual release gates, including TestFlight and owner-run real-device review items.
- Regression coverage locks the summary counts and copy so green automated checks do not imply App Store submission readiness.

## Follow-Up Pass - Speech Recovery Gate

- Speech runtime failures now keep `Type Instead` as the primary fallback but only offer `Create Manually` when Calendar access is available.
- If Calendar access is denied, the secondary recovery action opens iOS Settings instead of routing to a manual form that cannot save.
- Regression coverage locks the denied-calendar recovery path for speech runtime failures.

## Follow-Up Pass - Recovery Automation Anchors

- Unavailable-state recovery actions now expose stable accessibility identifiers derived from `UnavailableAction`.
- The same identifier contract is shared by model tests and SwiftUI buttons, so UI automation can target `Type Instead`, `Create Manually`, diagnostics, iOS Settings, or dismiss actions without relying on localized button text.
- Regression coverage locks the unavailable-action identifier contract.

## Follow-Up Pass - Readiness Automation Anchors

- Each Settings readiness checklist item now exposes a stable accessibility identifier derived from its readiness id.
- Release smoke tests can target specific gates such as Calendar access, Foundation Models route, Open in Calendar, or Store materials without relying on visible copy.
- Regression coverage locks the readiness-item identifier contract.

## Follow-Up Pass - Speech Cancellation Guard

- Cancelling processing now cancels the active speech-finish task, clears the recording identity, and calls the speech service cancellation hook.
- Speech transcript completion is guarded by the same command generation contract as parser/model work, so a late transcript cannot re-enter the command pipeline after cancellation.
- Regression coverage simulates a speech service that ignores task cancellation and still proves the late transcript is suppressed.

## Follow-Up Pass - Command Feedback Lifecycle

- Starting a new recording, transcription, parser, or apply stage now clears prior result and error feedback before showing processing state.
- Any pending result auto-dismiss task is cancelled when a new command stage begins, keeping old feedback timers from affecting the next command lifecycle.
- Regression coverage locks that stale result/error cards disappear while a new command is parsing.

## Follow-Up Pass - Processing Automation Anchors

- The processing card now exposes a stable accessibility identifier.
- The processing Cancel action now exposes a stable accessibility identifier, making Simulator UI smoke tests able to cancel parsing/applying work without relying on visible copy.
- Regression coverage locks the processing-card identifier contract.

## Follow-Up Pass - Sheet Dismissal Automation Anchors

- Common modal dismiss actions now expose stable accessibility identifiers across text entry, manual create, correction, confirmation, candidate selection, event detail, and calendar chooser sheets.
- Confirmation keeps separate identifiers for the toolbar cancel and the in-content secondary cancel action, preserving their different UX meanings for UI smoke tests.
- Regression coverage locks the sheet-dismiss identifier contract.

## Follow-Up Pass - Home Action Automation Anchors

- The home Settings action now exposes a stable accessibility identifier for release smoke navigation into Settings.
- The Back to Today action now exposes a stable accessibility identifier, independent of localized button copy.
- Regression coverage locks the home-action identifier contract.

## Follow-Up Pass - Smoke Automation Contract

- `SMOKE_AUTOMATION_CONTRACT.md` now lists the critical accessibility identifiers that Simulator release smoke tests may rely on.
- `Scripts/verify_smoke_automation_contract.sh` checks the contract against `CalPal/` and `CalPalTests/`, failing when documented identifiers drift out of source/tests.
- `Scripts/run_v03_release_gate.sh` runs the smoke contract check as part of the local release gate.

## Follow-Up Pass - Speech Authorization Cancellation Guard

- Speech authorization completion now checks the active recording identity before updating UI state.
- Cancelling a recording before the system permission callback returns leaves the command surface idle and does not present a stale unavailable sheet.
- Regression coverage simulates delayed denied authorization and proves the canceled voice attempt does not enter parser work or show late feedback.

## Follow-Up Pass - Speech Startup Cancellation Guard

- Speech startup completion now re-checks the active recording identity after `startTranscription` returns.
- If the user cancels while recognizer startup is still in flight, CalPal calls the speech cancellation hook again so a late-started audio session cannot remain active behind an idle command surface.
- Regression coverage simulates delayed recognizer startup and proves no parser work, result, error, or sheet appears after cancellation.

## Follow-Up Pass - Foreground Permission Recovery

- App foreground activation now refreshes capability readiness and reloads the agenda when Calendar access has become available.
- The foreground path does not request Calendar or Speech permissions; it only reconciles state after the user returns from iOS Settings or another app.
- Regression coverage locks the Settings-return recovery path by flipping mock Calendar authorization from denied to allowed and proving agenda reload without permission prompts.

## Follow-Up Pass - Scene Interruption Active Work Cancellation

- App inactive and background transitions now cancel active recording or command processing through the home model's lifecycle contract.
- Recording cancellation stops Speech capture before the app is interrupted or no longer visible, matching the product's privacy-first voice behavior.
- Processing cancellation reuses the command-generation guard so late parser/model/calendar results cannot update the UI after the app has been interrupted.
- Regression coverage locks both active-recording cancellation and late command-result suppression from the scene-interruption path.

## Follow-Up Pass - Interrupted Result Feedback

- Scene interruptions now pause the completed-result auto-dismiss timer while preserving the visible success card.
- Foreground activation resumes the auto-dismiss timer, so users who briefly leave CalPal still see the confirmation feedback when they return, and stale confirmations clear after the app is visible again.
- Result dismissal now also returns the command state to idle, preventing an invisible `.completed` state from lingering after the success card is gone.
- Regression coverage injects a short result-dismiss delay and proves interrupted completed feedback remains visible while interrupted, then clears and returns to idle after scene activation resumes the timer.
