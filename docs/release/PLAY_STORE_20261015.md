# Sukun Life: Google Play release gate — 15 October 2026

**Status:** preparation in progress; **not** Play-published. The product owner confirms an existing app entry and Production access. We have NOT accessed the Play Console account or verified the application's package identity, upload certificate, current version, declarations or review status.

## Repository facts as of 9 October
- Flutter Android app ID: `com.sukunlife.app`; verify it matches the **existing** Play Console app before any publication.
- Android release used a debug signing key. This release-preparation branch removes that unsafe fallback and refuses release builds without approved signing inputs.
- Android API 36 is now explicit. An INTERNET permission is declared in the release's main manifest.
- Existing application version in `app/pubspec.yaml`: `1.0.0+1`. The next build must use a **higher version code** than every previously uploaded bundle in the Play Console, across all tracks.
- App contains patient data, prescription workflows, public Islamic resources, media, locations, alarms and background playback. All app-content declarations must accurately match features enabled for review.
- No changes in this branch to live Supabase schema, web-preview deployment or patient records.

## Play Console information to verify
1. Dashboard > **App ID / package name** must be exactly `com.sukunlife.app`; if not, stop and reconcile: never relabel an existing Play app casually.
2. Setup > App integrity > **Upload key certificate** SHA-256, **not** Google Play's app-signing certificate.
3. Highest **versionCode** ever uploaded, across internal / closed / production tracks.
4. App review status, country availability, listing assets and release track.
5. Health apps declaration, Data safety, Data deletion URL, Privacy Policy URL, foreground-service type declarations and restricted permissions (if applicable).
6. For Google OAuth, verify Play app signing fingerprint registered in the correct Google/Firebase configuration. Phone SMS requires provider and rate limiting.

## Prepare GitHub (no keys in chat or source)
Create a restricted GitHub Actions environment named **`play-production-prep`**, configured with required reviewers. Populate encrypted **environment secrets**:

- `SUKUN_UPLOAD_KEYSTORE_BASE64`: base64 encoding of the existing Play **UPLOAD key keystore**, never private app-signing key material from Google.
- `SUKUN_UPLOAD_STORE_PASSWORD`
- `SUKUN_UPLOAD_KEY_ALIAS`
- `SUKUN_UPLOAD_KEY_PASSWORD`
- `SUKUN_PRODUCTION_SUPABASE_URL`
- `SUKUN_PRODUCTION_SUPABASE_PUBLISHABLE_KEY` (client-safe key, never service role).

Set **environment variables**:

- `SUKUN_PLAY_PACKAGE_NAME`: exactly the package from Play Console.
- `SUKUN_PLAY_LATEST_VERSION_CODE`: latest uploaded version, an integer.
- `SUKUN_PLAY_UPLOAD_CERT_SHA256`: colon-separated SHA-256 fingerprint of the upload certificate.

All values are read only by a manually triggered workflow protected by the environment. No automatic build on pull requests receives signing secrets.

## Release preparation workflow
When the code is reviewed/merged into a permitted release branch, manually run GitHub Actions > **Play Store Release Preparation** with an approved numeric version such as `1.0.0` and a strictly increasing integer build number. Checks:
- Package ID equals `com.sukunlife.app`.
- Version increases beyond Play Console.
- Upload key fingerprint matches Play Console.
- Flutter analyze and tests pass.
- Signed AAB is produced and `jarsigner` verifies it.
- Review-only AAB attached for 3 days. **NO Play Console submission is made automatically.**

The release signing workflow will fail closed if any required secret or input is missing. This is intentional. If the account has no reusable upload key yet, its key custodian must follow the appropriate Play App Signing setup/reset procedure before any bundle upload.

## Launch blockers (must be verified separately)
- [ ] Existing Play Console package ID & approved upload key match.
- [ ] Release AAB built with Android target API 36 and tested on Android 14–16.
- [ ] OTP, email and Google sign-in; legacy patient login; account linking verified.
- [ ] Cross-user RLS, private prescriptions, Edge Function authorization & rate limiting tested.
- [ ] Account deletion + privacy policy published on a real accessible HTTPS URL and linked inside app.
- [ ] App Data safety and Health apps declaration truthfully completed.
- [ ] Foreground audio, location, notifications and `SCHEDULE_EXACT_ALARM` permissions audited, justified and disclosed if needed.
- [ ] Resource rights and any offline download permissions cleared by CEO/manager.
- [ ] Paid booking and support tested or hidden behind a feature flag (do not claim unavailable features in store listing).
- [ ] Supabase billing, backups, error/usage alerts and real-device performance verified.
- [ ] Human QA on Google Play internal track and final Security/CEO/PM release sign-off.

**15 October is a release target, not a promise of approval by Google Play.** No unreviewed production release should be forced to meet a calendar deadline.
