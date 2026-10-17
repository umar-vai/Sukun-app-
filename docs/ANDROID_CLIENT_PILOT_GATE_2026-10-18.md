# Sukun Life — Android Controlled Client Pilot Gate (18 Oct 2026)

**Scope:** Existing Flutter app, Android **debug QA installation only**, limited client/staff test users. Not a public Play Store release and not a clinical security certification.

## Verified baseline
- Canonical repo: `umar-vai/Sukun-app-`; main commit at preparation: `653f5808189cdf3ed0ffbe30332f1545c9af9e56`.
- Existing Pages preview: `https://umar-vai.github.io/Sukun-app-/`, with CI/Pages HTTP-SHA gate.
- Backend: `vydfafumxptanpkmtrpr`. Patient/plan/action/task features exist. Production `notification_devices` was **0** on 18 Oct: no proof of remote push delivery.
- GitHub's Web Push dispatch is feature-gated OFF until server Firebase setup and device acceptance. Browser reminders cannot be represented as closed-browser delivery.
- Existing Android `release` Gradle target is debug-signed; **do not distribute as Play Store release**.

## Official app icon
The only source is the untouched client logo: `app/assets/brand/sukunlife_logo.png`.
For an explicitly approved native build, run:

```bash
python3 -m pip install 'Pillow==11.3.0'
python3 scripts/generate_android_launcher_icons.py
```

This generates standard + adaptive Android icons on the permitted Sukun Mist background. The original PNG is never changed or replaced. The controlled QA workflow runs this step before packaging. Do not substitute an AI-generated logo. The Android icon on a real phone still requires visual review.

## Secure QA installation
Use **Actions → Connected Android QA APK → Run workflow** with the approval checkbox on the approved revision. Do not run the ordinary UI-only APK and expect patient data to work.

Required GitHub Actions secrets:
- `SUKUN_QA_SUPABASE_URL`
- `SUKUN_QA_SUPABASE_PUBLISHABLE_KEY`

Required repo variables:
- `SUKUN_QA_APP_ENVIRONMENT=staging` (preferred), **or** `production` with `SUKUN_QA_ALLOW_PRODUCTION=true` and synthetic/test accounts only.

Optional *complete* Android FCM client secrets (all four or none):
- `SUKUN_QA_FIREBASE_PROJECT_ID`
- `SUKUN_QA_FIREBASE_SENDER_ID`
- `SUKUN_QA_FIREBASE_ANDROID_API_KEY`
- `SUKUN_QA_FIREBASE_ANDROID_APP_ID`

Client keys alone do **not** enable remote push: the server-side `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_PROJECT_ID`, scoped sender function, token registration and dispatch authorization must all be validated separately. **Do not copy server credentials into the Flutter package or PR.**

## Mandatory acceptance on Android handset
1. Install branded `app-debug.apk`; inspect launcher icon, app name, startup and sign-in.
2. With **synthetic** data, Super Admin creates a new patient. Record the temporary credential in a secure handoff channel; verify forced password replacement.
3. Admin records an approved plan with one timed action, links a public resource, reviews and publishes the plan.
4. Patient logs in and sees *only their own* Today/My Plan/Resources/Progress.
5. Patient opts into reminders, grants Android notification permission (and exact alarm permission where appropriate), then receives one device-local reminder at the configured time.
6. Verify notification tap, screen-locked/delayed delivery, app-closed/restart behavior, correct patient routing, timezone and reboot rescheduling.
7. Verify Done / Snooze / Skip persist after sign-out and sign-in; disable reminders and verify cancellation.
8. Negative-test cross-patient data isolation with a **second synthetic patient** before exposing live patient data.
9. If remote push is required, prove FCM token registration, controlled server send, failed-token cleanup, no sensitive message copy, and notification delivery on a locked physical device **before** claiming FCM readiness.

## Decision
**Pilot build preparation is allowed** by user request. **Client handoff is blocked** until successful backend-connected APK, real device acceptance, isolation check, and source-controlled CI pass. Do not change the existing `sukunlife.com` website or old internal dashboard. Do not merge this branch automatically or deploy backend migrations for the icon work.
