# PRD: Prioritized iOS MVP Bug-Fix Plan

## Source
- Requirements source: `.omx/specs/deep-interview-ios-mvp-manual-test-bug-triage.md`
- Mode: `$ralplan` / consensus planning
- Scope constraint: planning artifact; updated after implementation to reflect verified bug-fix decisions.
- Implementation update: 2026-05-08

## Product Goal
Make the first CalPal iOS MVP usable end-to-end after manual testing: users can grant required permissions, start and finish voice capture reliably, create calendar events that persist to the intended calendar at the intended local time, and use a cleaner UI that contains only useful decision/action surfaces.

## Prioritized Root-Cause Groups

### Group A — Voice capture interaction lifecycle (P0/P1)
Bugs: B2, B3
- B2: Long-press talk button ends recording immediately instead of holding until release.
- B3: Recording-state icon shifts position and may invalidate touch/press hit area.
Likely implementation area:
- `CalPal/Features/Command/CommandOrb.swift`
- `CalPal/Features/Command/CommandHomeModel.swift`
- `CalPal/Services/SpeechService.swift`
Root-cause hypothesis:
- `CommandOrb` starts recording from `onLongPressGesture(minimumDuration: 0.12, maximumDistance: 44, pressing:perform:)`, then ends recording when `pressing` becomes false. The recording visual state changes orb size (`orbSize` differs for idle vs recording), and the cancel button/ripple can alter geometry. On device, the long-press may be cancelled when geometry shifts or when the finger drifts beyond maximumDistance, triggering `finishRecording()` before user release.
- `SystemSpeechService` currently stops audio capture whenever the recognizer callback reports any error or final result. Planning should treat early recognizer final/error as diagnostic evidence, but the UI must not intentionally submit before release.
Product decision:
- Tap-to-record is now the binding MVP behavior: one tap starts recording, a second tap finishes and submits the captured audio, and cancel remains explicit.
- Double-tap on the orb opens text input.
- The orb's center and hit target must remain stable between idle and recording states.
- Long-press is no longer the primary interaction because device testing showed early cancellation risk from gesture/geometry changes.

### Group B — Calendar write truth, permissions, and target selection (P0/P1)
Bugs: B5, B1, B6
- B5: Auto Review reports Add to Calendar but does not persist event and shows no error.
- B1: First launch does not request Speech Recognition or Calendar Full Access.
- B6: App lacks Calendar Account/Profile selection and default write target.
Likely implementation area:
- `CalPal/App/AppModel.swift`
- `CalPal/App/AppRootView.swift`
- `CalPal/Features/Onboarding/OnboardingView.swift`
- `CalPal/Features/Settings/SettingsView.swift`
- `CalPal/Features/CalendarChooser/CalendarChooserView.swift`
- `CalPal/Services/EventKitCalendarRepository.swift`
- `CalPal/Services/CommandPipeline.swift`
- `CalPal/Services/PreferenceSummaryStore.swift`
Root-cause hypothesis:
- Permission request is deferred until agenda load or command processing, not first app initialization.
- Selected calendar is only transient in `CommandHomeModel`; default write target is not persisted as a user setting.
- `createEvent` may be writing to a fallback/default calendar, a non-user-expected calendar, or failing without sufficient post-save verification/reporting.
Product decision:
- Calendar Full Access is mandatory for MVP functionality and should be requested/checked at first usable initialization.
- Speech Recognition permission should be requested early enough that the first mic interaction is not the first permission discovery point.
- Settings should include an actionable default writable calendar/account picker.
- Calendar write success must mean an EventKit save succeeded and was verified in the intended calendar; otherwise show a failure.

### Group C — Local timezone correctness in NLP and EventKit dates (P1)
Bugs: B4
Likely implementation area:
- `CalPal/Services/NaturalLanguageCalendarParser.swift`
- `CalPal/Domain/CalendarModels.swift`
- `CalPal/Services/EventKitCalendarRepository.swift`
Root-cause hypothesis:
- Parser/date construction may rely on `Calendar.current` at initialization time, UTC defaults, or model/parser output without explicitly preserving the user's current time zone.
Product decision:
- Prefer `TimeZone.autoupdatingCurrent` / system current timezone without requesting location permission.
- Calendar/date parsing and event creation must use the same intended timezone context.
- Natural-language parsing must preserve local wall-clock intent such as "3 PM" or "下午三点"; model output must not silently convert these phrases to UTC-shifted times.

## 2026-05-08 Implementation Update

### Completed decisions reflected in code
- Voice capture was changed from hold-to-talk to tap-to-record/tap-to-stop in `CommandOrb`; double-tap opens text entry.
- Speech startup now validates the microphone input format before installing an audio tap so simulator/device microphone failures surface as recoverable speech-unavailable UI instead of a crash or silent cancellation.
- EventKit create now verifies the saved event by identifier/date-range lookup in the target calendar before presenting success.
- Parser/model date handling now uses `TimeZone.autoupdatingCurrent` by default, includes the user's local timezone/offset in the Foundation Models prompt, and preserves deterministic local fallback date ranges for clear wall-clock phrases.
- Added a regression test for Chinese local afternoon parsing: `明天下午三点和 Alex 开会` resolves to local 15:00 in the injected timezone.

### Verification evidence
- App text-create smoke test added `明天下午三点和 Alex 开会`; CalPal reported `Added to Calendar` for `3:00 PM-4:00 PM`.
- System Calendar cross-check on the iPhone 17 simulator showed `Meeting with Alex` on Friday May 8, 2026 from 3 PM to 4 PM.
- Generic iOS build passed with `xcodebuild build -project CalPal.xcodeproj -scheme CalPal -destination 'generic/platform=iOS' ... CODE_SIGNING_ALLOWED=NO`.
- Simulator tests passed with `xcodebuild test -project CalPal.xcodeproj -scheme CalPal -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' ... CODE_SIGNING_ALLOWED=NO`.

### 2026-05-08 v0.2 UI interaction update
- The idle command hint (`Tap to speak · double-tap to type`) is now a first-use hint. It fades out after the user starts voice recording or opens text entry from the orb.
- Tapping a created-event result card now focuses the agenda preview on the event's start date before dismissing the result card.
- Version metadata and README are updated for `v0.2`.

### Remaining verification gap
- Physical-device microphone recording still requires manual smoke verification because simulator microphone availability can differ from the reported phone behavior.

### Group D — Transient feedback and non-actionable UI cleanup (P2)
Bugs: B7, B8, B9
Likely implementation area:
- `CalPal/Features/Command/CommandHomeView.swift`
- `CalPal/Features/Command/StatusCards.swift`
- `CalPal/Features/Command/CommandHomeModel.swift`
- `CalPal/Features/Settings/SettingsView.swift`
- `CalPal/Features/Confirmation/ConfirmationView.swift`
Product decision:
- Remove/hide Calendar / AI Local / Speech status icons from the main home screen unless converted into actionable controls.
- Result/Add/Edit feedback should not permanently block agenda visibility; add TTL and tap-to-dismiss fade-out.
- Settings should contain user-changeable controls only; remove pure informational Language & Speech and Appearance Preview sections.

### Group E — App icon appearance variants (P1)
Bugs: B10
Likely implementation area:
- `CalPal/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `CalPal/Assets.xcassets/AppIcon.appiconset/*.png`
Current evidence:
- The app icon set currently contains only one universal 1024x1024 image.
Apple guidance:
- Apple documentation says iOS/iPadOS app icons support Light, Dark, and Tinted styles in asset catalogs; dark variants should be provided through the AppIcon appearance wells and dark icons should use a transparent background where appropriate so the system background can show through.
Product decision:
- Add a dark-mode app icon variant while preserving the existing production icon. Avoid broad icon redesign beyond variant support.

## RALPLAN-DR Summary

### Principles
1. Fix data-loss/blocking bugs before polish.
2. Treat visible success as a contract: if the app says an event was added, EventKit persistence must be verified or errors shown.
3. Preserve native iOS privacy posture: prefer system timezone and EventKit/Speech APIs before new permissions or SDKs.
4. Keep Settings actionable: if users cannot change it, remove it from Settings for this version.
5. Stabilize touch geometry before adding visual embellishment.

### Decision Drivers
1. MVP usability and trust: mic interaction and calendar write path must work reliably.
2. Privacy and permission clarity: request mandatory capabilities at the right time without unnecessary location permission.
3. Testability: each fix must have unit/model tests or render/integration smoke tests that can fail before the implementation.

### Viable Options Considered

#### Option 1 — Root-cause grouped sequential repair (Chosen)
- Pros: attacks P0 blockers first; keeps fixes reviewable; naturally maps to tests; avoids broad rewrites.
- Cons: some P1/P2 UI work waits until after core path fixes.

#### Option 2 — One broad UI/onboarding redesign pass
- Pros: could solve permission prompting, Settings cleanup, and status icon removal together.
- Cons: risks burying the P0 recording/write failures under visual churn; harder to test; violates minimal-change preference.

#### Option 3 — Introduce external calendar/account SDK or location permission early
- Pros: could offer explicit account semantics or geographic timezone inference.
- Cons: unnecessary until native EventKit and system timezone options are exhausted; adds privacy/product risk and requires user confirmation.

Invalidation rationale:
- Option 2 is rejected as the primary lane because the highest user pain is functional failure, not overall layout.
- Option 3 is rejected as the default because the user explicitly prefers no-location timezone handling and dependencies/permissions require escalation.

## Implementation Plan by Lane

### Lane 1: Voice Capture Stability (P0)
1. Replace long-press gesture semantics with tap-to-record/tap-to-stop.
   - First tap starts recording when idle.
   - Second tap finishes recording only when recording is active.
   - Double-tap opens text entry and cancels any pending single-tap action.
2. Make the orb hit region and center invariant:
   - Use a constant outer frame large enough for idle/recording/ripple/cancel affordance.
   - Avoid changing the orb's layout-driving size during recording; animate inner content/scale inside fixed geometry.
   - Keep cancel button from affecting the orb's measured center/hit target.
3. Add diagnostics-friendly state transitions in `CommandHomeModel`:
   - Ignore duplicate begin/finish events.
   - Keep latest error path visible when speech fails.
4. Test first with mocked speech service: begin -> wait -> no finish until release; release -> finish exactly once; cancel -> no submit.

### Lane 2: Calendar Write, Permissions, and Default Target (P0/P1)
1. Add an initialization capability flow:
   - On first launch/onboarding completion or first root appearance, request/check Speech Recognition and Calendar Full Access.
   - Keep the UI honest if either permission is denied/restricted.
2. Extend repository/domain to expose writable calendars with account/source metadata where EventKit supports it.
3. Persist a default writable calendar selection in local preferences/UserDefaults-compatible store.
4. Ensure `createEvent` writes to `draft.calendarID` or the configured default writable calendar, not an arbitrary fallback.
5. Add post-save confidence:
   - At minimum, use EventKit save success and returned event identifier/calendar ID.
   - If feasible, re-fetch by identifier/date range for verification in tests/mocks.
6. Surface failures through `.failure` or `.unavailable`; never show Add to Calendar after failed/ambiguous save.

### Lane 3: Timezone-Aware Parsing (P1)
1. Inject a timezone/calendar provider into parsing instead of hidden globals.
2. Use `TimeZone.autoupdatingCurrent` or a test-injectable equivalent as the default local timezone.
3. Ensure parsed `Date` values and EventKit `EKEvent` start/end dates represent the intended local wall-clock time.
4. Add tests using fixed timezones (e.g., America/Los_Angeles vs UTC) for morning events.
5. Do not request location permission in this lane.

### Lane 4: UI Cleanup and Feedback TTL (P2)
1. Remove `CapabilityStatusBar` from `CommandHomeView` or hide it behind a diagnostics-only path not shown by default.
2. Make result/feedback card transient:
   - Add a TTL auto-clear for `latestResult` and possibly `latestError` if appropriate.
   - Add tap-to-focus on result card when the result has an event; the agenda preview should jump to that event's date, then dismiss the card.
   - Fall back to tap-to-dismiss when the result has no event.
   - Avoid clearing while user is interacting with an important failure unless explicitly tapped.
3. Treat the idle command hint as temporary onboarding copy: fade it out after first orb voice/text use while preserving recording and processing status text.
4. Remove `Language & Speech` and `Appearance Preview` sections from `SettingsView` unless converted into editable controls.
5. Add calendar default picker to Settings as part of Lane 2, so Settings remains useful rather than empty.

### Lane 5: App Icon Dark Variant (P1)
1. Keep existing `AppIcon-1024.png` as the light/any variant.
2. Add a dark app icon variant compatible with current Xcode asset catalog support.
3. Consider a tinted grayscale variant only if quick and compatible; do not block bug fix completion on tinted support unless required by project settings.
4. Verify asset catalog compiles and generated images remain 1024x1024 and visually legible.

## Dependencies and Sequencing
- Lane 1 and Lane 2 are the critical path and can be implemented independently after planning approval.
- Lane 3 depends on parser and event creation interfaces but can be tested with injected timezone before EventKit integration.
- Lane 4 Settings changes should coordinate with Lane 2 so the default calendar picker is retained.
- Lane 5 can be implemented independently after asset catalog requirements are confirmed.

## Acceptance Criteria
1. Tap once starts recording and a second tap finishes recording on the main orb; no transcript attempt occurs before the second tap or explicit cancel.
2. Orb center/hit target is stable across idle and recording states.
3. Fresh install first-run path requests/checks Speech Recognition and Calendar Full Access before core interaction depends on them.
4. Auto Review no-conflict event creation writes to the selected/default calendar, verifies the saved EventKit event, and failure never presents false success.
5. NLP event times match the device/system current timezone without requesting location permission.
6. Settings lists writable calendar targets and persists a default write target.
7. Home no longer shows non-actionable Calendar/AI Local/Speech status icons.
8. Add/Edit result popup/card auto-fades; tapping a created-event result focuses agenda preview on the event date and does not permanently block agenda review.
9. Settings removes non-actionable Language & Speech and Appearance Preview sections.
10. App icon has a dark-mode variant accepted by the asset catalog and build.

## Follow-up Staffing Guidance

### If executed with `$ralph`
Use one persistent sequential owner. Recommended order:
1. Lane 1 voice capture fix + tests.
2. Lane 2 write/permissions/default calendar + tests.
3. Lane 3 timezone + tests.
4. Lane 4 UI cleanup + render tests.
5. Lane 5 icon variant + asset checks.

### If executed with `$team`
Suggested parallel lanes:
- Executor A: `CommandOrb`, `CommandHomeModel`, `SpeechService` gesture/speech lifecycle.
- Executor B: `EventKitCalendarRepository`, calendar models, preference/default calendar persistence, pipeline error handling.
- Executor C: `NaturalLanguageCalendarParser` timezone injection and tests.
- Executor D: `SettingsView`, `CommandHomeView`, `StatusCards`, result TTL/tap-dismiss UI.
- Executor E: AppIcon asset variants and asset verification.
- Verifier/Test Engineer: cross-lane test plan, xcodebuild build/test, manual smoke checklist.

Merge-readiness rule for team execution:
- Lane 1 (B2/B3) and Lane 2 (B5/B1/B6) are release-blocking P0/P1 foundations.
- P2 polish and icon work may proceed in parallel, but must not be considered merge-ready until Lane 1 and Lane 2 are implemented and verified.
- B2/B3 specifically require physical-device verification before completion; simulator-only evidence is insufficient.

Reasoning levels:
- Voice/EventKit/timezone lanes: high.
- UI cleanup/icon lanes: medium.
- Verification lane: high.

## Execution Hints
- `$ralph .omx/plans/prd-ios-mvp-bug-fix-plan.md .omx/plans/test-spec-ios-mvp-bug-fix-plan.md`
- `$team .omx/plans/prd-ios-mvp-bug-fix-plan.md .omx/plans/test-spec-ios-mvp-bug-fix-plan.md`

## Risks
- EventKit account/source semantics may differ between simulator and real devices.
- Speech gesture bug is reported on physical iPhone 17 Pro; simulator tests can catch lifecycle regressions but not fully prove device touch behavior.
- Dark/tinted icon asset catalog support depends on current Xcode/iOS target behavior.
- Automatic permission prompts can feel abrupt; mitigate through onboarding copy or clear fallback UI.
