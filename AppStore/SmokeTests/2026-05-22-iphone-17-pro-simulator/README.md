# iPhone 17 Pro Simulator Smoke Test - 2026-05-22

## Scope

- App: CalPal v0.3 checkpoint
- Git commit at start: `52170c7`
- Simulator: iPhone 17 Pro, iOS 26.4, UDID `6545C4BC-C24D-45EC-880A-4C7157F5D730`
- Build path: `/tmp/CalPalIPhone17ProSmoke/Build/Products/Debug-iphonesimulator/CalPal.app`
- Goal: Run the App Store readiness smoke path in simulator, mimic user operations where possible, fix simulator-discovered issues, and identify real-device-only checks.

## Automated And Manual Simulator Coverage

| Area | Result | Evidence |
| --- | --- | --- |
| Build, install, launch | Pass | XcodeBuildMCP `build_run_sim` succeeded with `CODE_SIGNING_ALLOWED=NO`. |
| First launch permissions | Pass | Speech recognition prompt accepted; Calendar Full Access prompt accepted. |
| Onboarding | Pass | `01-onboarding.jpg`; Continue dismisses onboarding and lands on home. |
| Home agenda | Pass | Empty-day state shown for May 22; date rail and settings control visible. |
| Settings readiness | Pass | Calendar access, writable calendar, speech, on-device parser fallback, privacy manifest readiness rows visible. |
| Speech fallback | Pass with simulator limitation | Tapping the orb on simulator opens `Speech Unavailable` because microphone capture is unavailable; `Type Instead` fallback works. |
| English text command create | Pass | `Meeting with Alex tomorrow at 3 PM` parsed through local fallback correction; saved event appears on May 23 at 3:00 PM. See `02-english-create-agenda.jpg`. |
| Chinese text command create | Pass | `明天下午三点和 Alex 开会` parsed through local fallback correction; saved event appears on May 23 at 3:00 PM. See `04-chinese-create-result.jpg`. |
| Event detail | Pass | Tapping agenda event opens `Event Details`, with title, calendar, time, location, notes, and quick update controls. |
| Modify/review/apply | Pass after fix | Event title update shows `Update Event?`, applies successfully, and agenda refreshes. See `03-update-agenda.jpg`. |
| Delete flow | Pass | Delete command triggers candidate selection, delete confirmation, and agenda removal. See `05-delete-result.jpg`. |
| Open in Calendar | Pass | `Open in Calendar` result action switches to Apple Calendar on Saturday, May 23, 2026. See `06-open-in-calendar.jpg`. |
| Release gate after fix | Pass | `bash Scripts/run_v03_release_gate.sh` completed with `CalPal v0.3 local release gate passed.` |

## Bug Found And Fixed

### Confirmation sheet action visibility

Finding: On the first simulator pass, the update confirmation sheet opened at medium height and placed `Apply Change` near or below the bottom edge for a modify confirmation with before/after content. The action was technically reachable after scrolling or expanding, but it was too easy to miss during a smoke flow.

Fix: `AppSheetHost` now presents confirmation sheets at `.large` height only, so `Apply Change` / `Delete Event` are visible in the initial confirmation context.

Verified: Rebuilt and re-ran an event update after the change. `Update Event?`, before/after text, and `Apply Change` were visible in the initial large sheet, then applying the change updated the agenda.

## Simulator Limitations

- Real microphone capture and live speech transcription were not fully verified. The simulator reported microphone unavailable, and the typed fallback path was used.
- Real-device speech permission behavior still needs confirmation because simulator authorization and physical microphone behavior differ.
- Notification, background, lock-screen, and interruption behavior were not covered in this pass.
- Apple Calendar integration was verified in simulator with EventKit data and `calshow:` navigation, but should still be checked on a real iPhone with the user's actual calendar accounts.

## Real-Device Smoke Test Focus

1. Install the current build on a real iPhone.
2. Complete first launch and grant Speech Recognition, Microphone, and Calendar Full Access.
3. Run one English voice command: `Meeting with Alex tomorrow at 3 PM`.
4. Run one Chinese voice command: `明天下午三点和 Alex 开会`.
5. Confirm each voice command creates the correct event after review.
6. Open Apple Calendar and verify the events exist in the expected calendar.
7. Modify one event in CalPal, apply the confirmation, and confirm Apple Calendar reflects the change.
8. Delete one test event through CalPal and confirm Apple Calendar reflects the deletion.
9. Tap `Open in Calendar` from a result card and confirm it opens Calendar near the event date.
10. Repeat a quick pass in Light Mode and Dark Mode.
11. Deny one permission on a fresh install or via Settings, then confirm CalPal shows a usable fallback instead of crashing.

