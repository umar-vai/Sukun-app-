# Patient Sign-In — Production Limiter Release Gate (20 October 2026)

## Verified read-only baseline

- One Flutter source repo: `umar-vai/Sukun-app-`; preserve the existing Pages preview. No APK/AAB/IPA and no changes to `sukunlife.com` or the legacy dashboard.
- Production Supabase: `vydfafumxptanpkmtrpr`. ACTIVE `patient-sign-in` **v7** still has no call to `check_patient_login_rate_limit`. It accepts unbounded valid attempts at the custom handler level; other Supabase platform/GoTrue limits are separate and have not been used to declare this secure.
- Production database already has `private.patient_login_attempts`, `public.check_patient_login_rate_limit(text,text)`; only `service_role` has EXECUTE. Do **not** reapply/reset production migrations just to deploy the handler.
- Isolated staging: `qacklgqvxvjjzsimjoip`, ACTIVE `patient-sign-in` **v2** with persistent limiter call; same database table/RPC access constraints verified.
- Main source `supabase/functions/patient-sign-in/index.ts` already includes 4 KiB request cap, HMAC-based IP and identifier buckets, 429 on limiter denial, 503 fail-closed on missing secret/RPC failure and the existing patient-credential flow.
- This PR hardens canonicalization of the trusted proxy IP input to prevent aliases (notably expanded IPv6) from splitting one IP-based bucket. **Source change is not a deployment.**

## Blocking safety gates for deploying to production

1. **Source/CI:** Require green TypeScript/Deno tests (including `rate-limit.test.ts` and `request-body.test.ts`), SQL/RLS checks and Flutter Web compatibility from the reviewable branch. Review the full diff and dependencies, including exact function files/deno.json.
2. **Trusted ingress:** On **staging**, verify the actual Supabase-hosted gateway populates `cf-connecting-ip` with the true client IP and rejects/overwrites a **caller-supplied forged value**. A test that merely constructs a `Request` with this header is *not* proof of trusted ingress. If the gateway does not guarantee it, **stop** and redesign the safe IP signal before deploying. Do not silently fall back to spoofable `x-forwarded-for`.
3. **Secret:** An authorized operator confirms a separate high-entropy `SIGN_IN_RATE_LIMIT_SECRET` is configured for each environment **without echoing it**. Missing/short secret causes fail-closed 503; never make the secret public or log it.
4. **Staging smoke:** Use disposable identities only. Verify invalid body 400, oversized body 413, ordinary wrong credentials 401, threshold 429 with safe retry, and temporary limiter/backend outage 503; verify a valid synthetic patient login still works. Do **not** flood production or touch real patient credentials.
5. **Database:** Confirm existing `check_patient_login_rate_limit` runs from actual staging `service_role` REST context and anon/authenticated EXECUTE remains denied; successful requests increment only HMAC buckets (not plaintext IP/Patient ID). Confirm no cross-user data is exposed.
6. **Deployment:** Save the currently deployed production v7 handler files and function metadata privately for rollback. Deploy the exact reviewed source + dependent `rate-limit.ts`, `request-body.ts`, `validation.ts`, `auth-identity.ts`, `deno.json` with `verify_jwt=false` only because this is a pre-auth patient login endpoint. Preserve existing CORS, identifier normalization, password migration behavior and response contract.
7. **Post-deploy:** Verify new ACTIVE function version/content, synthetic 400/413/401/429/503 behavior, legitimate sign-in and existing Flutter Web Patient login/API parsing; inspect aggregate status/error telemetry without storing patient identifiers, passwords, or tokens. Roll back immediately if legitimate sign-in fails or error rates rise. **Never equate deployed with browser accepted.**

## Other outstanding Phase 1 gates

- Review nine callable `SECURITY DEFINER` functions for correct per-user authorization; do not blanket-revoke patient functions.
- Evaluate enabling Supabase Auth leaked-password protection with appropriate account plan/operator.
- Two-patient authorization regression through direct REST/RPC and actual browser remains a separate gate.
- Do not deploy production login handler solely because this PR's CI passes.

## Evidence sources

- Production and staging live `get_edge_function` + read-only database privilege inspections on 20 October 2026.
- GitHub main source and `supabase/migrations/20261015133400_production_parity_core_functions.sql`.
- Supabase guidance: https://supabase.com/docs/guides/functions/auth-headers and https://supabase.com/docs/guides/functions/examples/rate-limiting

## Staging deployment evidence — 20 October 2026

- Staging `qacklgqvxvjjzsimjoip` `patient-sign-in` was updated from **ACTIVE v2** to **ACTIVE v3** using the reviewed `rate-limit.ts` from this PR. The other five deployed function files were preserved unchanged, and `verify_jwt=false` was retained for this pre-authentication endpoint.
- The connected Supabase read-back confirmed **ACTIVE v3**, an exact byte-for-byte match between its deployed `rate-limit.ts` and the reviewed PR source, and the existing `check_patient_login_rate_limit` RPC call still present in `index.ts`.
- On staging a **synthetic rollback-only database** test exercised the existing persistent limiter: attempts 1–8 for one synthetic identity were allowed and attempt 9 denied. A follow-up query confirmed **zero** synthetic bucket rows after rollback. This is SQL-level behavior, **not** an HTTP proxy/spoofing test or a successful patient sign-in.
- GitHub PR check run [39304408331](https://github.com/umar-vai/Sukun-app-/actions/runs/39304408331) completed **success**, covering Flutter, Backend/Edge, local RLS, resource guards and backend-free Web build at commit `37967e21`. The separate Flutter Web Preview workflow was still running during the status inspection; do not infer its completion from main CI.
- **Still blocked:** trusted edge gateway overwrite/reject behavior for caller-supplied `cf-connecting-ip`, staging endpoint's synthetic HTTP 400/401/413/429/503 compatibility, password-success path, secrets readiness and a production rollout/rollback approval. Do not promote staging v3 to production until those are verified.
- Production project `vydfafumxptanpkmtrpr` remains on the old ACTIVE `patient-sign-in` **v7** and was **not** changed by this staging deploy.
