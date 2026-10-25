# Sukun Life — Controlled Rich Public Notice Device Pilot (25 October 2026)

Status: **PREPARED, not built or device-verified**. Owner authorized one controlled Android QA test build and a synthetic Super Admin Web QA. No global FCM topic dispatch or public release is authorized.

## Verified code and safety baseline

- Main Flutter source: `umar-vai/Sukun-app-`. Existing Pages: `https://app.sukunlife.com/`.
- Production database reference `vydfafumxptanpkmtrpr`: **not used for synthetic pilot writes**.
- Isolated staging `qacklgqvxvjjzsimjoip`: synthetic role and public-notice schema exists.
- Special-notice public channel `sukun_public_notices`, image, foreground chronometer/countdown, Guest route and secure outbox already merged in #212–#213.
- The production sender's `SUKUN_UNIVERSAL_PUSH_RELEASE_READY` gate **must stay OFF**. The Firebase topic sender must NEVER be used as a single-device test mechanism.
- Synthetic Super Admin *database* Draft → Publish → Guest visibility → Archive RLS tested successfully in an explicit rolled-back staging transaction; zero persistent fixture records.
- GitHub Actions one-shot QA run [#40182450292](https://github.com/umar-vai/Sukun-app-/actions/runs/40182450292) **refused packaging** because QA Firebase client secrets were absent. Browser E2E also refused before signing in because the staging Admin test secrets were missing. **No APK was produced, no test notice published, no broadcast sent.**

## Human operator configuration (GitHub > repo Settings > Secrets and variables > Actions)

Configure these **repository secrets** for the isolated QA environment. Do **not** paste values into code, public Pages, GitHub comments or ChatGPT messages.

- `SUKUN_QA_SUPABASE_URL`: exact `https://qacklgqvxvjjzsimjoip.supabase.co`
- `SUKUN_QA_SUPABASE_PUBLISHABLE_KEY`: the approved staging **public** publishable key, not a service-role key
- `SUKUN_QA_FIREBASE_PROJECT_ID`: Firebase project ID for the test Android client
- `SUKUN_QA_FIREBASE_SENDER_ID`: matching Firebase messaging sender ID
- `SUKUN_QA_FIREBASE_ANDROID_API_KEY`: matching Android app's Firebase public API key
- `SUKUN_QA_FIREBASE_ANDROID_APP_ID`: matching Android app ID for `com.sukunlife.app`
- `SUKUN_STAGE_ADMIN_EMAIL`, `SUKUN_STAGE_ADMIN_PASSWORD`: a dedicated synthetic staging Super Admin, **not** a production or personal account

Configure Actions **repository variable** `SUKUN_QA_APP_ENVIRONMENT=staging`. Confirm that the Firebase app's Android package matches `com.sukunlife.app`. These are **client registration values**, not Firebase Admin service account credentials. Do not configure production credentials as a shortcut.

## After those settings exist: manual, one-build gate

1. On GitHub, open **Actions → Connected Android QA APK → Run workflow** on the latest green `main` branch.
2. Check `approve_native_qa_build=true`; check `rich_notice_pilot=true`.
3. Inspect build logs. Both complete QA Firebase client config and **exact staging** are enforced. A failed preflight produces **no APK**.
4. Only after a successful run, download the private `sukunlife-android-connected-qa` artifact from that run. It is a **debug APK for a trusted device**, not a Play release, not automatically published and has a 3-day retention.
5. Install on an explicitly authorized test Android handset only. Avoid any live patient login/data.

## Manual device acceptance (record sanitized pass/fail evidence)

- Cold launch and staging Guest mode works; no production patient records.
- Notification permission appears only when requested; opt-in/out persists correctly.
- Dedicated Android public-notice channel exists and is enabled.
- Use a **single test-device token only**, sent through an authorized Firebase test-device mechanism (NOT the `sukun_public_notices_v1` topic). No mass push.
- Foreground: BigPicture renders a non-sensitive public sample image and live OS countdown/chronometer when supported.
- Background and locked screen: standard FCM BigPicture/fallback; **do not assume a live OS countdown**.
- Tap foreground/background/cold-start notice: navigates to its validated public UUID; invalid/deleted notices fail closed.
- In-app timer decrements and transitions to `সময় শেষ`; archived notice stops appearing to Guest.
- Android version, notification channel settings and screenshot evidence recorded, without device token, password or patient identifiers.

## Synthetic Web Admin acceptance still needed

Once staging Admin secrets are configured, run the dedicated authenticated staging pilot browser workflow, using **the same Flutter source with isolated staging**. Confirm image upload → draft → preview → publish → Guest notice → archive/cleanup, and any test artifacts are removed. Do not call the database-only RLS transaction a verified Flutter Admin browser UI test.

## Release boundary

Native-device verification and security approval are distinct from CI pass, APK artifact creation, Pages deploy and FCM provider acceptance. Do not enable global topic push, open public releases, or modify `sukunlife.com`, DNS, existing dashboard or patient records in this QA stage.
