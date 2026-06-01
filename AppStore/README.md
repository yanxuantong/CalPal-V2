# CalPal 1.0 App Store Launch Checkpoint

This folder contains the 1.0 App Store and TestFlight release materials.

- `APP_STORE_READINESS.md` - 1.0 launch-readiness checklist and release gates.
- `APP_REVIEW_READINESS_RUNBOOK.md` - ordered launch-owner runbook for the remaining App Store review submission steps.
- `APP_STORE_CONNECT_SUBMISSION.md` - App Store Connect copy, review notes, privacy answer draft, and screenshot references.
- `APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` - final public-submission evidence record.
- `PRIVACY_POLICY.md` - privacy policy draft to publish before final submission.
- `Public/privacy.html` - deployable static privacy policy page for the public App Store privacy URL.
- `Public/support.html` - deployable static support page for the public App Store support or marketing URL.
- `ReleaseEvidence/` - templates for signed upload, screenshot review, metadata, and privacy-answer evidence artifacts.
- `ReleaseEvidence/LOCAL_RELEASE_HANDOFF.md` - generated handoff report that summarizes current local evidence and remaining external gates.

Run the local release gate from the repository root:

```sh
bash Scripts/run_v10_release_gate.sh
```

`Scripts/run_v10_release_gate.sh` is the canonical 1.0 release gate. The older `Scripts/run_v03_release_gate.sh` entrypoint is retained only as a deprecated compatibility shim.

For a narrower App Store copy/privacy consistency check:

```sh
bash Scripts/verify_app_store_submission_consistency.sh
bash Scripts/verify_app_store_metadata_fields.sh
```

For a narrower built app metadata/privacy-manifest check:

```sh
bash Scripts/verify_app_store_metadata.sh
bash Scripts/test_app_store_metadata_verifier.sh
```

For a narrower local-only runtime check:

```sh
bash Scripts/verify_local_only_runtime.sh
bash Scripts/test_local_only_runtime_verifier.sh
```

For a narrower built app privacy-surface check:

```sh
bash Scripts/verify_built_app_privacy_surface.sh
```

For a narrower demo screenshot artifact check:

```sh
bash Scripts/verify_demo_screenshot_artifacts.sh
bash Scripts/test_demo_screenshot_artifacts_verifier.sh
```

For a narrower smoke automation contract check:

```sh
bash Scripts/verify_smoke_automation_contract.sh
bash Scripts/test_smoke_automation_contract_verifier.sh
```

For a narrower release-document placeholder boundary check:

```sh
bash Scripts/verify_release_placeholder_boundaries.sh
```

For a narrower public support-page artifact check:

```sh
bash Scripts/verify_public_privacy_policy_artifact.sh
bash Scripts/test_public_privacy_policy_artifact.sh
bash Scripts/verify_public_support_page_artifact.sh
bash Scripts/test_public_support_page_artifact.sh
```

To refresh the release handoff report after local evidence changes:

```sh
bash Scripts/generate_release_handoff_report.sh
```

To print the launch-owner preflight checklist without uploading or mutating external state:

```sh
bash Scripts/run_app_store_submission_preflight.sh
```

Set `CREATE_EVIDENCE_SKELETONS=1` on that command if the dated release evidence files for the current day have not been created yet.

To generate dated skeletons for the remaining external release evidence:

```sh
bash Scripts/create_release_evidence_artifacts.sh --date YYYY-MM-DD
```

The local release gate also runs `Scripts/test_release_evidence_artifact_generator.sh`, which verifies the generator's check-only mode, dated writes, overwrite refusal, and invalid-date handling.
It also runs `Scripts/test_prepare_app_store_upload.sh`, which verifies the upload preparation guardrails without sending anything to Apple.

The app's Settings screen includes a separate Reset Local Diagnostics action so device-local QA counters can be cleared independently from local preferences.

Before final App Store submission, publish `Public/privacy.html` to an HTTPS URL and record that URL in `APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` and the privacy-answer evidence artifact. Publish `Public/support.html` to the App Store support or marketing URL before completing metadata evidence.
The privacy verifier checks both the privacy claims and the static page's basic publication structure, including document language, viewport metadata, description metadata, one H1, and no script, iframe, form, or insecure HTTP markup. The static-artifacts verifier also checks the full `Public/` directory, rejects unexpected publish files, and requires local relative links to resolve before the pages are uploaded to HTTPS hosting.

After signed upload, TestFlight real-device smoke testing, final screenshot review, public privacy-policy publication, and App Store Connect metadata/privacy answers are complete, fill `APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` and run:

```sh
bash Scripts/verify_public_release_readiness.sh
```
