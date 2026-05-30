# CalPal Privacy Policy

Effective date: May 22, 2026

CalPal is a private calendar assistant for Apple Calendar users. This policy describes the current 1.0 implementation.

## Data Collection

CalPal does not collect data from this app in 1.0.

CalPal does not operate a developer-hosted backend, account system, advertising SDK, or third-party analytics SDK. Calendar content, voice input, speech transcripts, command text, and local preferences are not uploaded to a CalPal server.

## Calendar Data

CalPal requests Calendar Full Access so it can show your agenda and create, modify, or delete calendar events when you ask it to.

Your Apple Calendar remains the source of truth. CalPal asks you to review sensitive create, update, and delete actions before applying them.

## Voice And Speech

CalPal uses the microphone and Apple's Speech Recognition framework for optional voice calendar commands.

Speech input is used to transcribe calendar commands for the current action. Text entry and manual entry remain available if speech access is denied or unavailable.

## On-Device Intelligence

CalPal may use Apple on-device intelligence when it is available on your device. When it is unavailable, CalPal uses a deterministic local parser fallback.

## Local Preferences

CalPal stores lightweight preferences on device, such as onboarding state, permission-initialization state, and the preferred writable calendar. These preferences are stored with UserDefaults.

The app bundle includes `PrivacyInfo.xcprivacy` declaring UserDefaults required-reason API usage with reason `CA92.1`.

## Tracking

CalPal does not track users in 1.0.

CalPal does not sell data, does not use advertising identifiers, and does not share app data with data brokers or advertising networks.

## Changes

Re-check this policy before each release. If CalPal adds accounts, sync, cloud AI, analytics, crash reporting, subscriptions, push notifications, or third-party SDKs, this policy and the App Store privacy answers must be updated before submission.

## Contact

For privacy questions, use the support contact listed on CalPal's App Store product page.
