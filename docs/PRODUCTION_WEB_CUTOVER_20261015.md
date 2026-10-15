# Sukun Life production Web cutover — 15 October 2026

## Scope

The user explicitly selected **Production Supabase** (`vydfafumxptanpkmtrpr`) as the primary development backend after the reviewed staging-to-production migration. The one canonical Flutter app remains in `umar-vai/Sukun-app-`. The **existing** GitHub Pages URL `https://umar-vai.github.io/Sukun-app-/` remains the only development preview. The existing public website `https://sukunlife.com`, pre-existing internal dashboard and DNS are untouched; `app.sukunlife.com` is NOT provisioned without separately approved DNS/hosting.

## Production readiness verified before Web config

- Production content: 184 records, including 181 migrated public/review resources; 101 editorial Quran reconciliation audit records. Content and audit checksums matched staging, no existing production content/patient attachments overwritten.
- Backend: published user role and member provisioning; Patient login rate-limit RPC, notification inbox, content review RPCs; prescription AI functions active. **Active Edge != authenticated end-to-end Gemini success.**
- 27 production public-schema tables have RLS enabled. Sensitive patient/AI/audit tables lack anon SELECT privileges; CI independently checks the public Supabase Data API before every Pages deployment.
- Public Supabase publishable key is deliberately browser-visible. The service-role key, Gemini, Firebase sender credentials, patient logins and other secrets must NEVER enter a Pages artifact.
- Production Auth Google provider, email OTP, SMS provider, callback and abuse controls were not independently verified. Corresponding signup flags stay **false by default**.
- The two old preview actions variables `SUKUN_PREVIEW_SUPABASE_PROJECT_REF`, `SUKUN_PREVIEW_SUPABASE_URL` and `SUKUN_PREVIEW_SUPABASE_PUBLISHABLE_KEY` are ignored. The main CI-triggered Pages workflow now targets only approved production ref `vydfafumxptanpkmtrpr` with its verified public publishable key; no staging fallback.

## Deployment gates

1. PR CI: Flutter format/analyze/tests, Edge, pgTAP/RLS and Chrome regressions.
2. PR live read-only anonymous Data API test for production `content_items` and patient-sensitive tables.
3. Approved merge into `main` with successful **push** CI; downstream `workflow_run` must use the current `main` SHA (no stale success).
4. Pages workflow rechecks Production public API, emptiness/denial for all patient, Auth-role, task, attachment, AI and audit tables; build exact Flutter `main_web.dart`; deploy through same existing Pages URL.
5. Pages deployment HTTP checks `preview-build.json` SHA, `index.html` and bootstrap. Inspect `backend_mode=production`; browser manually verify authenticated role flows.
6. If security preflight fails, deployment is BLOCKED. Earlier deployed artifact remains; **do not claim the new production cutover is live**.

## Emergency rollback

`SUKUN_PREVIEW_FORCE_GUEST_ONLY=true` plus a *new* approved main CI run disables backend connectivity for the same real Flutter Web app. It is NOT a solution to RLS/AI/Auth failures; use for emergency isolation only.

## Auth and AI gates still pending

- Confirm production Gemini server-side slot secrets and invoke **synthetic** PDF -> AI actions -> Admin review -> approved Patient Today (no invented instructions). Current production provider health/success has NOT been authenticated end-to-end verified.
- Confirm Google OAuth production redirect + provider settings before setting `SUKUN_PRODUCTION_ENABLE_GOOGLE_OAUTH=true`; similarly `SUKUN_PRODUCTION_ENABLE_MEMBER_SIGNUP`, `SUKUN_PRODUCTION_ENABLE_EMAIL_OTP` and `SUKUN_PRODUCTION_ENABLE_PHONE_OTP` require explicit enabled provider and anti-abuse tests. These controls are repository **variables**, not secrets; provider credentials remain in Supabase.
- Authenticate as separate synthetic Patient A, Patient B and Super Admin to confirm cross-patient RLS and clinical workflow. CI unit/Chrome mocks do not replace a logged-in real-browser test.
- Supabase Security Advisor previously warned about `SECURITY DEFINER` execute grants and leaked-password protection; inspect privileged RPCs and enable Auth leaked-password protection through Supabase Dashboard before public signup.

## Rollout truth table

GitHub merge, CI passed, Pages web built, Pages deployed, HTTP SHA verified, browser role-E2E, production AI-E2E and customer release are **different statuses**. Never conflate them. No native APK/AAB/IPA is built on routine changes.
