# CalPal 1.0 Public Release Evidence

This file is the human-verifiable release record for the final public App Store submission gate.

Do not replace `TODO` or unchecked checklist items until the evidence exists. `Scripts/verify_public_release_readiness.sh` treats this file as incomplete while any required item remains open. Evidence fields must point to completed, dated, repo-local artifacts created from the templates in `AppStore/ReleaseEvidence/` and `AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md`; do not point final evidence fields at template files or paths outside this repository.

Publish `AppStore/Public/privacy.html` to the public HTTPS privacy-policy URL and `AppStore/Public/support.html` to the public HTTPS support and marketing URL before completing the App Store Connect metadata evidence.

## Release Candidate

Version: 1.0
Build: 10

## Required Evidence

Local release gate result: PASS
Local release gate command: bash Scripts/run_v10_release_gate.sh
Local release gate date: 2026-05-31
Local release gate artifact: AppStore/SmokeTests/2026-05-31-local-release-gate/README.md

Signed archive upload result: TODO
Signed archive upload build: TODO
Signed archive upload date: TODO
Signed archive upload evidence: TODO

TestFlight real-device smoke result: TODO
TestFlight real-device smoke device: TODO
TestFlight real-device smoke iOS version: TODO
TestFlight real-device smoke date: TODO
TestFlight real-device smoke evidence: TODO

Public privacy policy URL: TODO
Public support URL: TODO
Public marketing URL: TODO

Final screenshot review result: TODO
Final screenshot review date: TODO
Final screenshot review evidence: TODO

App Store Connect metadata result: TODO
App Store Connect metadata evidence: TODO
App Store Connect privacy answers result: TODO
App Store Connect privacy answers evidence: TODO

Open release blockers: TODO

## Real-Device Smoke Checklist

- [ ] Fresh install, first launch, onboarding completes.
- [ ] Calendar Full Access, Speech Recognition, and Microphone permissions can be granted.
- [ ] Settings readiness shows Calendar access and Writable calendar as ready.
- [ ] Settings readiness shows Privacy manifest as ready.
- [ ] Voice create works for: "Meeting with Alex tomorrow at 3 PM."
- [ ] The created event appears in CalPal.
- [ ] The created event appears in Apple Calendar.
- [ ] Result card Open in Calendar opens Apple Calendar near the event date.
- [ ] Text create works for: "明天下午三点和 Alex 开会."
- [ ] Event detail sheet opens from the agenda.
- [ ] Event detail title or location update can be staged and reviewed before save.
- [ ] Modify flows require review.
- [ ] Delete flows require review.
- [ ] Recurring-event modify/delete flows require recurrence scope selection.
- [ ] Speech denied or unavailable state still leaves text/manual fallbacks usable.
- [ ] Light Mode reviewed on device.
- [ ] Dark Mode reviewed on device.
- [ ] Dynamic Type reviewed on device.
- [ ] Reduce Motion reviewed on device.
- [ ] Reduce Transparency reviewed on device.

## Completion Values

Use these exact values when each item is genuinely complete:

- `Local release gate result: PASS`
- `Signed archive upload result: PASS`
- `TestFlight real-device smoke result: PASS`
- `Final screenshot review result: PASS`
- `App Store Connect metadata result: PASS`
- `App Store Connect privacy answers result: PASS`
- `Open release blockers: NONE`

Use these templates for manually completed evidence artifacts:

- `AppStore/ReleaseEvidence/SIGNED_UPLOAD_TEMPLATE.md`
- `AppStore/SmokeTests/REAL_DEVICE_SMOKE_TEMPLATE.md`
- `AppStore/ReleaseEvidence/SCREENSHOT_REVIEW_TEMPLATE.md`
- `AppStore/ReleaseEvidence/APP_STORE_CONNECT_METADATA_TEMPLATE.md`
- `AppStore/ReleaseEvidence/APP_STORE_PRIVACY_ANSWERS_TEMPLATE.md`
