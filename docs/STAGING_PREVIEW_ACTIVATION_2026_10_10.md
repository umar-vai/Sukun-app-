# Sukun Life — Isolated Staging Web Preview Activation Gate

**Updated:** 10 October 2026  
**Tracks:** Phase 1 Security / Phase 2 Patient QA / Phase 4 General User Authentication  
**Canonical app:** `umar-vai/Sukun-app-` → same existing GitHub Pages site  
**Production project (NEVER a preview backend):** `vydfafumxptanpkmtrpr`

## Verified starting point

- The **same actual Flutter application** runs from `app/lib/main_web.dart`.
- The existing Pages pipeline has passed CI, Flutter Web compilation, Chrome widget regressions, Pages deployment, and its HTTP commit marker gate at main commit `354eeb92`. That run emitted `backend_mode: local`, so it does **not** demonstrate authenticated Patient/Admin/Member functionality.
- At the time of this audit the connected Sukun Supabase account has **one production project** and **no database preview branches**. An isolated staging project or branch must first be explicitly approved and provisioned.
- No production patient records, passwords, files, Gemini secrets, service-role key, or Firebase sender credentials may be copied into public Pages, synthetic test fixtures, or the browser bundle.
- GitHub PR builds always use backend-free local mode and never publish; only a successful current-main CI push can trigger Pages deployment.

## Stage 1 — Explicit environment and cost gate (operator)

1. Choose the **authorized Supabase organization** and review the actual cost of a dedicated test project or a branching environment. Creating a new paid resource requires explicit operator approval. Do not assume a branch is free: it can incur compute costs.
2. Provision a **clean isolated environment**; do not clone the production patient database or storage.
3. Apply the repository's relevant migrations to staging, including the **member-role/sign-up** schema, then deploy compatible staging-only Edge Functions. Verify live application of each migration/function rather than relying on a committed SQL file.
4. Use synthetic Guest, Member, Patient A, Patient B, and Super Admin identities. Never use live clinical records.
5. Verify DB row-level security, cross-patient negative tests, admin grants, login rate limiting, redirect allowlist, approved resources and storage permissions.
6. Configure supported Supabase Auth providers, redirect URLs, quotas and abuse protection in the staging console only. Google requires its own OAuth configuration. **SMS OTP may require a paid provider and is not enabled automatically.**

## Stage 2 — GitHub Actions variables (repository operator)

Configure under **Settings → Secrets and variables → Actions → Variables** for the existing app repository; the build accepts only staging refs and a public publishable key.

| Variable | Required staging value |
|---|---|
| `SUKUN_PREVIEW_SUPABASE_PROJECT_REF` | Actual isolated staging Supabase ref, **not** `vydfafumxptanpkmtrpr` |
| `SUKUN_PREVIEW_SUPABASE_URL` | `https://<staging-ref>.supabase.co` |
| `SUKUN_PREVIEW_SUPABASE_PUBLISHABLE_KEY` | Staging **public** `sb_publishable_...` key only |
| `SUKUN_PREVIEW_ENABLE_MEMBER_SIGNUP` | Optional `true` or `false`, default false |
| `SUKUN_PREVIEW_ENABLE_EMAIL_OTP` | Optional `true` or `false`, default false |
| `SUKUN_PREVIEW_ENABLE_PHONE_OTP` | Optional `true` or `false`, default false |
| `SUKUN_PREVIEW_ENABLE_GOOGLE_OAUTH` | Optional `true` or `false`, default false |

**Never add a service-role or secret key to these variables.** Publishable keys are public browser credentials; sensitive operations must remain protected by server-side grants and RLS.

The Pages builder:
- rejects the known production ref or a mismatched ref/URL, incomplete staging configuration, unsupported key form, or invalid flag values;
- defaults all four auth feature flags to **false**;
- refuses enabling any auth preview flag unless the backend environment is **staging**;
- never activates these opt-in flags for PR artifacts or local guest builds;
- records safe non-secret `backend_mode` and `auth_features` flags in `preview-build.json` for diagnostics.

The presence of a correctly formatted publishable key does **not** confirm Auth providers, schema, test users, or RLS are configured; these need independent live checks.

## Stage 3 — Safe staged rollout and browser QA

1. Verify staging DB, functions, RLS and synthetic credentials before setting any feature flag.
2. Configure the three staging connection variables with **all four auth flags false**. Merge a reviewed CI-green change to main. Verify `preview-build.json` has the exact approved commit and `backend_mode: staging` on the **existing** Pages URL.
3. Confirm actual browser rendering and Patient ID/password login, admin email login, sign-out, token persistence, expiration, and first-login password change with synthetic identities.
4. After member migrations and confirmed-email/provider setup, set `SUKUN_PREVIEW_ENABLE_MEMBER_SIGNUP=true`; trigger a tested main deployment and run isolated Member sign-up + role verification. An Auth user must not be able to self-assign Admin or Patient roles.
5. Separately opt in to `SUKUN_PREVIEW_ENABLE_EMAIL_OTP`, `...PHONE_OTP`, or `...GOOGLE_OAUTH` **only after** each corresponding provider is enabled and the redirect/abuse/cost controls are verified. Avoid turning all four on at once.
6. Exercise: Admin creates Patient A → prescription → reviewed plan → publish → Patient A marks Done/Skip/Snooze → progress; Patient B cannot see Patient A's data, even via direct resource/API ID.
7. Verify resource browsing, audio/video fallback, notification inbox, offline completion conflict handling and mobile/desktop browsers; record screenshots only with synthetic data.
8. Capture per-gate evidence: committed SHA, GitHub CI run, Pages deployment log/URL, live staging backend version, real browser smoke results, and any pending production gate.

## Rollback and production isolation

- To disable one experimental provider flow, set its matching `SUKUN_PREVIEW_ENABLE_*=false`, then deploy through approved CI/main. Settings changes alone do not rebuild the public Flutter bundle.
- To return to a guest-only preview, clear **all three staging connection variables** and set all four auth flags false, then deploy through the tested main workflow.
- A failing CI/build/deploy must leave the previous preview intact. Verify host content, not only workflow logs.
- Do not apply test member-auth migrations or a rate-limiter experiment to Production; do not change `sukunlife.com`, the existing internal dashboard, `app.sukunlife.com`, or native packages under this gate.

## Immediate blocker

Before a fully authenticated Pages preview can be called complete, the user/operator must authorize the **Supabase staging organization and actual expense**, approve its creation, and provide supported GitHub Actions variable setup. Until that point, current Pages remains a safe **guest-capable local build**.
