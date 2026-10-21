# Existing Flutter Pages — optional isolated Staging QA mode (2026-10-21)

This is an **opt-in configuration**, not a new website, new app, new repository, or automatic switching of the existing Pages site.

## Verified infrastructure

- Existing real Flutter web destination: https://umar-vai.github.io/Sukun-app-/
- Supabase Production (must not change): `vydfafumxptanpkmtrpr`
- Isolated synthetic Staging: `qacklgqvxvjjzsimjoip`
- Patient A/B authenticated REST/JWT isolation: **passed** in Actions run [#39541838856](https://github.com/umar-vai/Sukun-app-/actions/runs/39541838856) on main `9197275a`.
- Admin, OAuth Member and real Flutter UI browser E2E: **not yet verified**.

## What the change does

The existing `.github/workflows/functional-web-pages.yml` now recognizes a **GitHub Actions repository variable**, `SUKUN_PREVIEW_USE_STAGING`.

| Value | Approved main Pages deployment behavior |
| --- | --- |
| Unset / `false` | Existing Production/guest preview policy unchanged |
| `true` | Build **the same Flutter codebase** using the fixed **Staging** Supabase URL and its **public** publishable key; no Production DB switch or writes |

When staging mode is explicitly selected, public Member password signup, Email OTP, and Phone OTP remain disabled. Google OAuth is offered **only if** public Staging GoTrue settings show `external.google == true`. This is *not* proof that provider redirect/consent or browser sessions work.

The runtime configuration is recorded as `backend_mode: staging` in `preview-build.json`; the existing Pages pipeline still checks its exact main commit SHA by HTTP before declaring deployment successful. It does not embed test credentials, OAuth tokens, service-role keys, AI keys, or patient data in Flutter JS.

**Critical security gate:** All real-backend Pages deploys, Production **and Staging**, must pass the anonymous Data API privacy smoke before publishing. The existing gate checks synthetic clinical data, roles, private patient tables and related resources return no anonymous rows (401/403 is allowed). A failed check keeps the previous site, not an unsafe new build.

## Activation — operator/user approval required

Do **not** flip the Pages site to Staging without user approval: the public GitHub Pages URL will display the Staging resources/role flows instead of its prior Production preview behavior.

1. In the same repository, **Settings → Secrets and variables → Actions → Variables**, set `SUKUN_PREVIEW_USE_STAGING=true`. This is a non-secret boolean variable. GitHub connector currently cannot edit Actions repository variables.
2. Trigger an **approved main CI-successful push** to rebuild and deploy to the **same** Pages URL. Merely saving the variable does not rebuild the currently deployed JS bundle.
3. Verify the live `https://umar-vai.github.io/Sukun-app-/preview-build.json` has the exact successful main SHA and `backend_mode: staging`. Confirm successful deploy/HTTP smoke workflow job separately.
4. Use **only synthetic Staging accounts** for desktop/mobile Web QA G2–G8 (see `PHASE2_PATIENT_WEB_ACCEPTANCE_2026_10_20.md`). Record role checks, interaction results and sanitized browser findings, without capturing credentials or real patient data.
5. If any role or browser gate fails, keep release blocked. Restore the previous mode by setting the variable to `false` and performing a **new approved main CI-successful deployment**. A variable change alone is not rollback.

## Boundaries

- Existing public `sukunlife.com` and the old internal dashboard: **unchanged**.
- No `app.` subdomain changes or DNS changes.
- No automatic APK/AAB/IPA, no Production SQL/Edge/Auth modifications.
- Publishing a public Staging client remains a security-sensitive step even with RLS; do not use Production or personal clinical data for QA.
