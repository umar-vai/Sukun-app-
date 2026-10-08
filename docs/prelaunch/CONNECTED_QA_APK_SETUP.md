# Sukun Life — sign-in enabled Android QA APK

Status 2026-10-08: Configurable build workflow committed; **not yet provisioned or deployed**. The default CI artifact intentionally has no backend and can only preview UI.

## Why login was disabled

The ordinary GitHub CI job ran `flutter build apk --debug` with no `--dart-define=SUPABASE_URL` and no client publishable key. `AppEnvironment.isSupabaseConfigured` returned false, so the login button was disabled. **That is not a password or patient-ID error.** An APK compiling successfully does not mean it can connect to production or staging.

## Safe connected QA setup

In GitHub repository `umar-vai/Sukun-app-` > **Settings > Secrets and variables > Actions**:

Add **Repository secrets** (never paste values into chat, repository code, issue comments, public screenshots or Actions inputs):

- `SUKUN_QA_SUPABASE_URL`: the selected Supabase project's HTTPS URL.
- `SUKUN_QA_SUPABASE_PUBLISHABLE_KEY`: that project's **publishable/anon client key**. Never use the service-role key or server tokens.

Configure **Repository variables**:

- `SUKUN_QA_APP_ENVIRONMENT`: `staging` (default if absent).
- For staging: use a separate safe test backend and dummy patient accounts. The QA job intentionally blocks use of the existing production URL when target is `staging`.
- If an **authorized release operator explicitly chooses production** for QA with **dedicated dummy/test accounts only**, set `SUKUN_QA_APP_ENVIRONMENT=production` and **`SUKUN_QA_ALLOW_PRODUCTION=true`**. The workflow verifies that the URL matches the approved existing production project. Never run destructive tests, expose PHI, or send unsanctioned notification loads to production.

## Where to get a working APK

The new `.github/workflows/qa-connected-android.yml` is triggered for trusted, same-repository PRs to main. When correctly configured, look in the **Connected Android QA APK** workflow run's **Artifacts** for:

`sukunlife-android-connected-qa`

The old regular CI artifact is now explicitly named:

`sukunlife-offline-ui-preview-no-login`

It will **never** support login; do not use it for authentication QA.

**Important:** The connected QA build is not automatically available unless the two repository secrets exist. A successfully completed workflow with a message `Backend-connected APK not built` means no connected APK was produced. Only share a real artifact after verifying it was uploaded. The workflow may run from a PR before merge; do not merge to main solely to enable QA.

## Tests before launch

1. Build using configured client-safe keys and confirm `APP_ENVIRONMENT`/Supabase URL are correct.
2. Install connected APK on an Android test phone. Test admin and patient sign-in using dummy accounts, forced password change, log out and re-login.
3. Verify role isolation across two dummy patients and one authorized admin, including resource access and notification inbox.
4. Confirm original public site and legacy dashboard have not changed.
5. Verify Bangla font wrapping at 360dp/large accessibility fonts, Today, resource browser, approvals and failure/retry paths.
6. Test that the app behaves sensibly offline, with no raw SQL/backend error exposed.
7. Test Firebase notifications **separately** after Firebase client-safe identifiers are configured: connected Supabase alone does not make push messaging available.
8. Reconcile live database migrations (especially notification inbox RPC), review web-preview AI document flow, prove rollback readiness and complete manual iOS acceptance before release.

## Troubleshooting

- Disabled login and note saying only UI preview: connected URL/key weren't provided to the build, not invalid password.
- Button enabled but sign-in fails: verify backend environment, test account, authentication function deployment and legitimate RLS permissions without exposing credentials.
- Connected workflow skipped: configure repository secrets; this connector cannot set Actions secrets on the user's behalf.
- A password was shown in a screenshot: **change it immediately if real** and do not reuse it in QA screenshots.

Public publishable/anon keys are meant to be included in clients and **do not grant elevated permissions**. Protect service-role secrets, never weaken RLS, and never put server AI/Firebase service-account credentials into Flutter.
