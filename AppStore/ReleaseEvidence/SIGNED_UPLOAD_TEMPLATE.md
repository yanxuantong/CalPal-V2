# CalPal 1.0 Signed Upload Evidence

Result: TODO
Build: TODO
Date: TODO
Archive path: TODO
Upload method: TODO
App Store Connect evidence: TODO
Uploader: TODO

## Checklist

- [ ] `DRY_RUN=0 bash Scripts/prepare_app_store_upload.sh` completed without error.
- [ ] The uploaded build number matches the Xcode project build.
- [ ] App Store Connect shows the build as uploaded or processing.
- [ ] No unexpected export, signing, validation, or upload warnings remain.

## Notes

`Scripts/create_release_evidence_artifacts.sh` fills the canonical archive path and upload method from `Scripts/prepare_app_store_upload.sh`. Do not change `Result` to `PASS` until `DRY_RUN=0 bash Scripts/prepare_app_store_upload.sh` completes and the exact uploaded build is visible in App Store Connect.
