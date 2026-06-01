# CalPal 1.0 Local Release Gate Evidence

Build: 10
Date: 2026-05-31
Environment: iPhone 17 Simulator, local unsigned archive build

## Commands

```bash
bash Scripts/run_simulator_ui_smoke.sh
bash Scripts/verify_smoke_automation_contract.sh
bash Scripts/test_public_release_readiness_verifier.sh
CAPTURE_SCREENSHOTS=0 bash Scripts/run_v10_release_gate.sh
```

## Result

- Focused Simulator UI smoke: PASS
- Smoke automation contract: PASS
- Public-release verifier self-test: PASS
- Local 1.0 release gate: PASS
- Unsigned archive verification: PASS

## UI Smoke Coverage

The focused XCUITest launches `--calpal-demo` and covers:

- Demo agenda loads.
- Settings readiness, privacy boundary, and local diagnostics are reachable.
- The command orb opens typed command entry.
- Text command send state is enabled after input.
- Empty-day manual create opens the manual event form.
- Back to Today returns to the populated agenda.

## Screenshot Artifacts

- `Artifacts/AppStoreScreenshots/calpal-demo-home.png`: 1206 x 2622
- `Artifacts/AppStoreScreenshots/calpal-demo-home-dark.png`: 1206 x 2622

## Remaining Public-Release Evidence

This artifact does not prove the external public App Store gates. The final release record still needs signed App Store Connect upload evidence, TestFlight real-device smoke evidence, public privacy-policy URL, final screenshot review, and App Store Connect metadata/privacy-answer confirmation.
