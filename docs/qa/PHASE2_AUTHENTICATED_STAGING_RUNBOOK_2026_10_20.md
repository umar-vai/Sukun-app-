# Phase 2 — Real JWT Staging Role Acceptance Runbook (2026-10-20)

**Status: gate implemented in source, live credential run NOT completed.** This is a staging-only authenticated REST/RLS smoke test. It does not replace a full Flutter UI/browser journey.

## Why it exists

Earlier Phase 2 synthetic database transactions verified Admin prescription -> reviewed plan -> publish -> Patient Today -> complete -> progress, Patient A/B isolation and idempotency. Those transactions used SQL-simulated JWT claim contexts and rolled back. A real Supabase Auth session + Data API RLS test is still essential.

## Environment and scope

- Staging-only Supabase project **`qacklgqvxvjjzsimjoip`**; rejects an unexpected project ref.
- Runs from trusted GitHub `main` by explicit manual dispatch only; no public PR run may receive credentials.
- No APK, no migration, no database inserts/updates/deletes, no service-role secret, no cross-origin patient-data screenshot. The Flutter Pages preview `https://app.sukunlife.com/` remains unchanged.
- The **public** staging publishable key comes from existing approved Flutter Web staging configuration and may be used in a browser. All login passwords/identifiers must be synthetic GitHub Actions Secrets, not `vars`, logs, public client or chat messages.

## Set these eight repository Actions Secrets (synthetic accounts only)

| Secret | Staging account |
| --- | --- |
| `SUKUN_STAGE_PATIENT_A_ID` | Patient A's patient-code/identifier; must own an active synthetic plan |
| `SUKUN_STAGE_PATIENT_A_PASSWORD` | Patient A password |
| `SUKUN_STAGE_PATIENT_B_ID` | Different Patient B identifier |
| `SUKUN_STAGE_PATIENT_B_PASSWORD` | Patient B password |
| `SUKUN_STAGE_ADMIN_EMAIL` | Synthetic Super Admin login email |
| `SUKUN_STAGE_ADMIN_PASSWORD` | Synthetic Super Admin password |
| `SUKUN_STAGE_MEMBER_EMAIL` | Synthetic General Member login email |
| `SUKUN_STAGE_MEMBER_PASSWORD` | Synthetic General Member password |

**Do not transmit these values to ChatGPT.** Add them directly in GitHub repository Settings -> Secrets and variables -> Actions -> Repository secrets. The chosen A account must own an active Staging care plan and the selected accounts must have canonical server-issued database roles. All four must be distinct users. Never use Production credentials.

## How to run

1. Merge the reviewed gate PR after its CI tests pass.
2. In GitHub Actions, open **Phase 2 Synthetic Staging Auth/RLS Gate**, choose **Run workflow**, branch **main**.
3. Enter exactly `STAGING_ONLY` for `staging_only_confirmation`.
4. The script authenticates A/B using the actual `patient-sign-in` endpoint + Supabase refresh-token exchange and Admin/Member using GoTrue password login. It validates identities and database roles from live Staging and reads clinical data through REST using **real bearer tokens**.
5. The release gate **fails** if B can read A's patient, plan, prescription, task or completion; if Member/Guest can read clinical records; or if Admin cannot access A's plan. A's active synthetic plan is mandatory.
6. No tokens, names, emails, passwords, database IDs or response bodies are printed, stored in artifacts or sent to public Pages.

## What success proves — and does not prove

| Test | Outcome |
| --- | --- |
| Authentic Staging Patient A/B, Admin and Member login | Verified when manual run passes |
| Server-issued role lookup and distinct identities | Verified when manual run passes |
| Authenticated REST read isolation for known A data | Verified when manual run passes |
| Anonymous/member clinical access empty or denied | Verified when manual run passes |
| UI Create -> Draft -> Preview -> Publish in Flutter browser | **NOT** verified by this workflow |
| UI Today -> Done -> Progress, reconnect and reload | **NOT** verified by this workflow |
| Browser device acceptance (Safari mobile, Chrome desktop) | **NOT** verified by this workflow |
| Runtime write-idempotency from live browser tokens | **NOT** verified (covered separately by rolled-back SQL/RPC tests) |

The workflow runs network-free unit tests before calling Staging; those tests also run automatically on CI, even if secrets are not set. A failed manual gate is a **release blocker**. If secrets are absent, the workflow fails with a generic message and does not attempt login.

## Next browser acceptance

Use the same Flutter code and approved isolated staging build (never create a second public site). With synthetic roles, follow `docs/qa/PHASE2_PATIENT_WEB_ACCEPTANCE_2026_10_20.md`, record commit SHA + sanitized result for G2-G8, and keep all failed cases open until tested. The source PR and CI success are not browser verification.
