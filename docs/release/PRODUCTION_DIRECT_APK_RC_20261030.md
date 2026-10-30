# Sukun Life — Production Direct APK release candidate gates (30 October 2026)

## Decision
A production **direct-download signed APK** is now the first controlled Android
release path, without waiting for Play Console. Use the existing one Flutter
codebase, unchanged `sukunlife.com` and legacy dashboard, and the existing
approved app preview destination. The first public APK is **not yet released**.
Production client uses Supabase `vydfafumxptanpkmtrpr`; never bundle patient
data, Gemini keys, Firebase service account or Supabase service-role credentials.

## What the owner reported
The earlier connected **debug** Staging Guest APK was around 200 MB, lagged on
a midrange Android phone, offered no Google login and failed to play some
audio. This is hardware feedback about that installed APK, not a measured
production release benchmark. A Flutter debug build can be considerably
larger/slower than optimized release AOT; do not promise that release mode
alone fixes audio-source/network or widget-frame issues.

## Actual gaps and PR changes
1. Prior manual `android-sideload-release.yml` supplied Production Supabase
   but **no Firebase Android client identifiers**; app's runtime correctly
   would not initialize FCM. Now fail closed on four Production Firebase values
   with a sender/app-id consistency check. No service-account credentials in
   client.
2. Prior direct APK compile passed `ENABLE_GOOGLE_OAUTH` based on a post-QA
   approval flag, and never passed `ENABLE_MEMBER_SIGNUP`. Now compile both
   account entrypoints for the **internal** Production release candidate.
   Public channel still requires verified Google OAuth and Production member
   signup readiness. These compile flags do **not** prove backend provider,
   OAuth signing fingerprints, email confirmation or login on device.
3. Keep an actual **release AOT universal APK** for device coverage, not the
   previous debug QA package. Capture signed byte size, fail above an
   initial 130 MiB universal APK ceiling. Actual target is a materially
   smaller measured installed/downloaded footprint; consider ABI split
   only with a verified architecture-aware installation/update feed.
4. Direct update `android.json` remains `enabled=false` until an actual
   signed APK release asset exists, with verified SHA-256, exact size,
   incremented version code and package. Android updater verifies its
   downloaded artifact and requires an explicit Install tap; Android OS must
   still approve install. Never silently install updates.
5. Carry the same Firebase/Member/Google production client config forward
   to the later Play review AAB workflow, without publishing to Play.
6. Add offline synthetic negative/positive release guards and a static
   updater non-auto-installer regression, running on PR release-policy CI.

## Owner-only GitHub Actions release inputs (do not paste into chat)
Protected Environment `android-sideload-release`, with required reviewer:

Actions secrets:
- `SUKUN_SIDELOAD_KEYSTORE_BASE64`, `SUKUN_SIDELOAD_STORE_PASSWORD`,
  `SUKUN_SIDELOAD_KEY_ALIAS`, `SUKUN_SIDELOAD_KEY_PASSWORD`
- `SUKUN_PRODUCTION_SUPABASE_URL`,
  `SUKUN_PRODUCTION_SUPABASE_PUBLISHABLE_KEY`
- `SUKUN_PRODUCTION_FIREBASE_SENDER_ID`,
  `SUKUN_PRODUCTION_FIREBASE_ANDROID_API_KEY`,
  `SUKUN_PRODUCTION_FIREBASE_ANDROID_APP_ID`

Actions variables:
- `SUKUN_ANDROID_PACKAGE_NAME=com.sukunlife.app`
- `SUKUN_ANDROID_LAST_VERSION_CODE` (actual highest distributed)
- `SUKUN_SIDELOAD_CERT_SHA256` (approved **app signing** certificate)
- `SUKUN_PRODUCTION_FIREBASE_PROJECT_ID` (verified Production Firebase app)
- `SUKUN_ANDROID_GOOGLE_OAUTH_TESTED=true` **only after real signed APK
   Google OAuth device QA**; required for public channel
- `SUKUN_PRODUCTION_MEMBER_SIGNUP_READY=true` **only after production
   signup/email verification/rate limiting acceptance**; required for public

**Play migration:** Protect the direct APK app-signing key for future updates.
The eventual Play end-user **app-signing** certificate must be compatible with
the direct APK if installed users should migrate in place. A separate Play
**upload key** does not guarantee compatibility. Plan Play App Signing
enrollment/certificate continuity with the account owner before public
distribution. Do not assume a Play-managed APK can update an unrelated
self-signed direct package.

## Release candidate acceptance: owner/engineering/QA
- [ ] Core CI Flutter format/analyze/tests, web role/browser and Production
      guest RLS checks PASS at same reviewed source SHA.
- [ ] Production Auth verified on real signed Android: Guest,
      General User register/Google login/logout/session restore, personal
      routines create/edit/check-in, Patient ID login and cross-Patient denial,
      Super Admin console access only after role confirmation.
- [ ] OAuth redirect `com.sukunlife.app://login-callback` and signing cert
      registered with Google provider; no auto-link to legacy Patient records.
- [ ] Android public FCM project verified, explicit topic consent, correct
      Notice UUID tap, OFF/unsubscribe on isolated audience, no mass broadcast.
- [ ] Native media: 18 public production audio source links currently reference
      `files.ruqyahbd.org`. Check real HTTP MIME/range/reliability, retries,
      background playback and 3G/4G switching. The 18/18 database URLs being
      HTTPS does **not** prove accessible streams.
- [ ] Measure cold start, screen frame drops, list/reader scroll and audio
      memory/buffering on at least one lower/midrange Android handset;
      battery usage and repeated navigation; fix verified regressions.
- [ ] Record signed release SHA-256, APK size and update-from-prior-version
      success (same signer + higher code) after installing on a device.
- [ ] Privacy, account deletion/support, health/safety content and publisher
      rights reviewed; Production RLS/security adviser and backup gates.
- [ ] Deploy verified signed APK to a reviewed official GitHub Release asset;
      *only then* enable the existing `app/web/updates/android.json` release
      feed with real digest/size/URL and validate real host availability.
      Updating the manifest is NOT automatic user publication.
- [ ] Pilot 10–30 consented users, 100–300 only after support/telemetry,
      monitoring, privacy and rollback sign-off. No unrestricted public
      rollout until release owner authorizes it.

## Work status at creation
Code under review only. No APK/AAB was built in this PR. Signing secrets and
Firebase project matching cannot be read from the connected GitHub/Supabase
read-only interfaces; no verification should be claimed for them. Existing
Staging debug successful notice tests remain distinct from Production
release-device acceptance.
