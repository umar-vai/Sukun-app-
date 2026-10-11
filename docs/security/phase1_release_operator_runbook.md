# Phase 1 Security Exit — Operator Runbook (Sukun Life)

**Scope:** Existing Flutter Web + Supabase project `vydfafumxptanpkmtrpr`. This is a release *gate*, not a release authorization. GitHub Issue #62 / Draft PR #63. Last reviewed: 2026-10-12.

## Verified baseline

- Repo: `umar-vai/Sukun-app-`; one Flutter codebase and the **existing** GitHub Pages preview only.
- User-reported basic/role QA: 8/8 passed with test accounts.
- GitHub CI run 522: Flutter quality, Edge checks, 18 files/270 pgTAP DB assertions and disposable local patient sign-in HTTP tests all passed; real HTTP responses include 200, 401, 413, 429.
- Live Supabase: deployed `patient-sign-in` version 7 (at audit), without persistent limiter. Both `public.check_patient_login_rate_limit(text,text)` and `private.patient_login_attempts` were absent.
- Eight authenticated-executable `SECURITY DEFINER` RPCs are intentionally present and use an empty search_path with no anon EXECUTE; follow-up negative tests on synthetic Member identity remain required.
- Current hosted IP header provenance is **not verified**. A caller-controlled `cf-connecting-ip` would defeat IP-bucket throttling; do not presume local tests establish trust.

## Mandatory stop conditions

STOP / NO GO if any of these are true:
1. Any production patient information would be copied into an unaudited staging, public GitHub Pages, logs or CI artifacts.
2. Hosted gateway can pass through a user-supplied `cf-connecting-ip` without replacing/removing it, or does not supply the expected header. **Do not** fall back to raw `x-forwarded-for` without a trusted proxy contract.
3. The limiter SQL, service-role grants, server-only secret or Edge Function version does not match.
4. No verified restore capability and operator-approved rollback route for the target environment.
5. Cross-account negative tests, guest/private content boundaries, admin authorization, and web login are not passing in the **target** environment.
6. CI fails, the Pages deployment SHA is unknown, or the tested build differs from the deployed app.

## Remaining steps in order

1. **Hosted staging environment:** Obtain explicit cost/organization approval if Supabase branch creation incurs billing. Branches are not provisioned by this PR. Use migrations and **synthetic** users only. No production data clone.
2. **Trusted network boundary:** Establish from hosted gateway configuration/provider contract that the chosen client IP field is *generated/sanitized* by the gateway. Test missing header and user-spoofed header at staging. A positive local smoke with an injected header does not satisfy this step.
3. **Stage database and function together:** Apply reviewed `docs/security/patient_sign_in_rate_limit_staging.sql` to isolated staging, then verify via `..._verify.sql`. Provide random `SIGN_IN_RATE_LIMIT_SECRET` *only as a hosted Function secret*. Deploy the matching `patient-sign-in` code to staging and check actual deployed version/source.
4. **Staging HTTP checks:** Repeat valid/invalid/unknown patient, bounded body 413, both 429 thresholds, token refresh, success after window expiration, concurrent retries, and browser Patient/Admin login with synthetic identities.
5. **Security:** Review all 8 privileged RPCs and their actual users; do not blindly revoke `authenticated` EXECUTE on APIs the app calls. Check new SQL negative tests, service-role isolation, Auth password exposure protection availability and Admin MFA feasibility. Review PII-safe logs.
6. **Data safety:** Confirm current plan and actual backups/retention in Dashboard (Database > Backups). Supabase documents that paid projects get scheduled backups; **do not assume this project does**. On an isolated disposable database, restore a synthetic snapshot and verify representative schema, RLS policies, and fixture integrity. Do not restore a backup over production.
7. **Monitoring:** Identify on-call operator; capture baseline login success/error/429 rates, DB errors, uptime, backup health and rollback decision thresholds without logging patient IDs, IPs, JWTs, refresh tokens or passwords.
8. **Go/no-go approval:** Capture target migration hash, function source SHA, GitHub commit, CI run, branch, staging test records, backup timestamp and exact operator/rollback approval. Promote compatible DB+secret+function only within the authorized window, with immediate synthetic smoke and monitoring.
9. **Web:** Once main CI/build passes and deployment succeeds, verify the **same** GitHub Pages URL for Guest, General User, Patient and Admin using synthetic data. GitHub build or PR preview is not production deployment.

## Rollback design (test before deployment)

- Keep the last known working hosted Edge Function bundle and CLI deployment instructions outside public client artifacts. Record the previous function version and configuration.
- Prefer a *compatible* rollback of Edge Function **after** verifying that both old and new backend schemas permit it. If rollback of schema would drop security evidence or clinical data, **do not automatically reverse migrations**.
- Stop rollout on real login errors, repeated 503, privileged access failure or abnormal 429. Run operator-approved restore only in an isolated rehearsal unless a separate production incident authorization exists.
- Backups cover databases according to plan/retention; they are not automatically complete snapshots of Storage, Functions, Auth settings or external credentials. Validate each recovery dependency.

## Verification matrix (record concrete evidence)

| Gate | Status as of 2026-10-12 | Evidence / owner |
| --- | --- | --- |
| Disposable local HTTP limiter | PASS | GitHub CI #522 |
| Automated privileged RPC denial | IN CI | PR #63 |
| Hosted IP header trust | BLOCKED | Provider/gateway confirmation required |
| Hosted staging and synthetic HTTP | NOT STARTED | Requires staging availability/cost approval |
| Admin MFA and compromised password protection | PENDING | Auth configuration/operator |
| Backup + isolated restore drill | PENDING | Dashboard/operator |
| Production DB limiter/function parity | NOT DEPLOYED | Live v7; DB check absent |
| GitHub Pages SHA + real browser smoke | NOT VERIFIED for PR | Same existing URL only |
| Production rollout | NOT APPROVED | Separate operator approval |

## Existing public site and native policy

Never modify `sukunlife.com` or the old internal dashboard. Do not create guest-only parallel websites, expose secrets in public Flutter, or package APK/AAB/IPA during routine Web-first security work.
