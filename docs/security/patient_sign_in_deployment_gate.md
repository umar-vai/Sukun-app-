# Patient sign-in production parity / Phase 1 security gate

**Tracking:** #62. **Status as of 2026-10-12:** GitHub source includes request-size limits and a persistent limiter, but the inspected deployed `patient-sign-in` Edge Function was still version 7 without either protection. The live database inspection did not return `public.check_patient_login_rate_limit(text,text)`. Do **not** infer deployment from local CI success.

## Why this is a release blocker

An unauthenticated login endpoint needs explicit protection against repeated attempts. `verify_jwt = false` is expected for an initial sign-in endpoint; enabling gateway JWT verification would break the login flow, **not** solve brute-force controls.

Do not publish a code-only function update. The current GitHub handler deliberately fails closed when either `SIGN_IN_RATE_LIMIT_SECRET`, an approved trusted client-IP header, or the limiter RPC is missing; changing just one dependency could temporarily return 503 for every patient.

## Non-destructive verification before any deployment

1. On an isolated, disposable test Supabase project, apply `docs/security/patient_sign_in_rate_limit_staging.sql` and run `docs/security/patient_sign_in_rate_limit_verify.sql`. These are **not** confirmed deployed in production. CI's local-database simulation is only one signal.
2. Review `private.patient_login_attempts` permissions, role claims and `public.check_patient_login_rate_limit` EXECUTE grants. Verify `anon` and `authenticated` cannot invoke it; `service_role` only.
3. Verify the actual hosted gateway **sets or sanitizes** `cf-connecting-ip`. A caller must not be able to choose the limiter IP key by forging this header. Do not add a blind `x-forwarded-for` fallback. Do not print raw IPs, credentials, bearer tokens or patient identifiers to logs.
4. Provide a random server-only `SIGN_IN_RATE_LIMIT_SECRET` (at least 32 characters) via Supabase function secrets. Do not commit it or expose it in Flutter Web.
5. Deploy to the isolated staging function with the SQL installed. Use synthetic patient accounts to test valid sign-in, invalid password, unknown identifier, request body exceeding 4 KiB (413), and 8-per-identity / 30-per-IP limits per 15-minute window (429). Verify error bodies reveal neither account existence nor sensitive context.
6. Check login availability and existing Flutter Web compatibility. If ready to promote, take an approved backup/rollback checkpoint, install the SQL migration in the target environment, configure the secret and trusted gateway requirement, and deploy the matching function version in the same controlled window.
7. After promotion, fetch the actual deployed Edge Function source/version (not just GitHub source). Re-run synthetic 413/429/success and cross-patient negative checks through the same `https://umar-vai.github.io/Sukun-app-/` browser client. No real patient credentials or bulk auth attacks.
8. Repeat Security Advisor, check function error rates and patient sign-in availability. Roll back only via reviewed, compatible steps; do not remove the limiter table blindly if live traffic uses it.

## Read-only SQL checks (safe on live DB)

```sql
select to_regprocedure('public.check_patient_login_rate_limit(text,text)') is not null
  as limiter_function_installed;
select to_regclass('private.patient_login_attempts') is not null
  as limiter_storage_installed;
```

**Not sufficient alone:** these checks do not prove that the function secret is configured, the gateway IP is trusted, or the deployed Edge Function actually invokes the limiter.

## Current verification distinctions

- GitHub source: limiter + bounded body reader present.
- GitHub CI: local SQL verification configured in `.github/workflows/ci.yml`; current PR CI result must be checked separately.
- Supabase live DB/function: no limiter RPC found; deployed v7 sign-in source lacks new guards at inspection.
- Browser: user's manual 8/8 basic QA passed, but no automated 413/429 staging or production probes were performed.
- Native packaging/public website: intentionally out of scope.

**Release rule:** Hold Phase 1 exit until both deployed function and DB are in parity and staging probes pass. Never turn this into an APK build or a change to `sukunlife.com`.
