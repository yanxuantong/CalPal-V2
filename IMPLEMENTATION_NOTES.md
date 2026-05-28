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
- Settings now separates the `Foundation Models route` readiness signal from the deterministic parser fallback, so a fallback-ready environment does not imply Apple Intelligence generation has been verified.
- The processing card now describes the active work more specifically: transcription, Apple Intelligence/fallback parsing, or EventKit saving.
- The previous Settings `Automation Mode` picker was removed because its `Full Access` option did not drive runtime behavior. Settings now shows a truthful read-only `Safety Mode` row for the current Auto Review policy.
- Blank text/transcript submissions are rejected before the AI/parser pipeline, valid text submissions are trimmed, and the text-entry sheet prevents duplicate sends after the first submit.
- The empty-agenda surface now includes a real `Create Manually` action that presents the manual event form.
- Calendar command parses now retain a route label. Auto-applied result cards can show whether Apple Intelligence generated the parse, the deterministic parser handled it directly, or Foundation Models failed/unavailable and CalPal fell back locally.
- Parser-route labels are preserved through correction, confirmation, candidate selection, and confirmed modify/delete results, so sensitive review flows do not lose AI-vs-fallback evidence.
- Settings section deep links now honor the requested section, diagnostics/readiness can be refreshed in place, and section identifiers are stable for UI automation.
- Corrected-draft saves retain the original parser route on the final result card; manual event creation stays route-neutral.
- Candidate selection now shows source command context, parser route, cancel affordance, recurring signals, and stable row identifiers before a target event can be selected.
- Confirmation cancellation is handled as a normal no-op in `CommandHomeModel`, so cancel does not call the command pipeline or show a failure card.
- Manual-create and correction forms now guard against duplicate save taps and keep start/end edits in a valid time range.
- Calendar-access failures now provide actionable Settings/Try Again recovery and avoid sending users into manual-create flows that cannot save without EventKit access.
- Permission recovery now distinguishes CalPal diagnostics from iOS system Settings; denied Calendar/Speech permissions can route to the system Settings URL.
- Permission timing is now staged: onboarding completes before Calendar access is requested, and Speech/Microphone prompts remain just-in-time for the first voice command.
- Agenda failure actions now distinguish permission denial from generic load failure: denied opens iOS Settings, while non-permission failure opens in-app diagnostics.
- Release scripts now derive the demo screenshot bundle id from the built app and validate minimum screenshot dimensions.
- Calendar permission drift during existing-event search or confirmation-time mutation now routes to iOS Settings, with mock repositories enforcing denied access across read and write methods.
- Mock calendar writes now enforce writable-calendar selection like EventKit, and no-writable-calendar saves route to diagnostics instead of manual retry.
- Manual and correction forms now show the target calendar before save, with fallback copy for EventKit's default writable calendar behavior.
- Draft saves now normalize title, location, and notes in the command pipeline before EventKit writes, and whitespace-only titles are rejected before repository mutation.
- Modify patches now normalize title, location, and notes before EventKit writes; blank location/notes are preserved as explicit clear operations, while patches that become empty after normalization fail as `No Changes`.
- Confirmation review now shows location and notes changes, including explicit clear intents, before update mutations are applied.
- Event detail quick updates now show inline review readiness and disable review when the edited title is blank.
- Manual-create and correction forms now show inline save readiness and use the same readiness model to gate their save actions.
- Text command entry now shows inline send readiness and uses the same readiness model for main and toolbar send actions.
- Calendar chooser rows now show writable/read-only status, include stable row identifiers, and provide an explicit Cancel action.
- Competitive reference notes and release gaps live in `AppStore/ProductionPolish/2026-05-28/README.md`.
