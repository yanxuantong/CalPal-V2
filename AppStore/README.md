# CalPal v0.3 App Store Checkpoint

This folder contains the v0.3 App Store and TestFlight release materials.

- `APP_STORE_READINESS.md` - v0.3 readiness checklist and release gates.
- `APP_STORE_CONNECT_SUBMISSION.md` - App Store Connect copy, review notes, privacy answer draft, and screenshot references.
- `APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` - final public-submission evidence record.
- `PRIVACY_POLICY.md` - privacy policy draft to publish before final submission.

Run the local release gate from the repository root:

```sh
bash Scripts/run_v03_release_gate.sh
```

After signed upload, TestFlight real-device smoke testing, final screenshot review, public privacy-policy publication, and App Store Connect metadata/privacy answers are complete, fill `APP_STORE_PUBLIC_RELEASE_EVIDENCE.md` and run:

```sh
bash Scripts/verify_public_release_readiness.sh
```

