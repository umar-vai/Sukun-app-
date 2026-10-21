# Phase 2 — Real JWT Staging Role Acceptance Runbook (2026-10-20)

**Status update (21 October 2026):** The live `PATIENT_ONLY` gate passed on trusted main commit `9197275a` via [Actions run #39541838856](https://github.com/umar-vai/Sukun-app-/actions/runs/39541838856), with real Patient A/B JWTs, mandatory clinical fixtures and cross-patient read isolation. **Admin and Google OAuth Member login and Flutter UI browser acceptance remain pending.** This is a staging-only authenticated REST/RLS smoke test, not a full Flutter UI/browser journey.

## Why it exists

Earlier Phase 2 synthetic database transactions verified Admin prescription -> reviewed plan -> publish -> Patient Today -> complete -> progress, Patient A/B isolation and idempotency. Those transactions used SQL-simulated JWT claim contexts and rolled back. A real Supabase Auth session + Data API RLS test is still essential.

## Environment and scope

- Staging-only Supabase project **`qacklgqvxvjjzsimjoip`**; rejects an unexpected project ref.
- Runs from trusted GitHub `main` by explicit manual dispatch only; no public PR run may receive credentials.
- No APK, no migration, no database inserts/updates/deletes, no service-role secret, no cross-origin patient-data screenshot. The existing Flutter Pages preview is `https://umar-vai.github.io/Sukun-app-/`; this workflow does not deploy the browser app and does not touch `sukunlife.com` or a future `app.` subdomain.
- The **public** staging publishable key comes from existing approved Flutter Web staging configuration and may be used in a browser. All login passwords/identifiers must be synthetic GitHub Actions Secrets, not `vars`, logs, public client or chat messages.

## Easier first step: Patient A/B only (three GitHub Secrets)

These existing staging accounts were verified in the staging database: **Patient A has an active synthetic plan** and **Patient B has no plan**. The owner confirmed they share one synthetic test password. This is not a claim that the password has successfully authenticated: it must be tested by the real GoTrue/Edge HTTP gate.

In repository **Settings → Secrets and variables → Actions**, add exactly these three **Repository secrets**:

| Secret name | What to enter |
| --- | --- |
| `SUKUN_STAGE_PATIENT_A_ID` | Patient A's staging Patient ID or phone as accepted by the Patient Login screen |
| `SUKUN_STAGE_PATIENT_B_ID` | Patient B's staging Patient ID or phone |
| `SUKUN_STAGE_PATIENT_SHARED_PASSWORD` | The shared *synthetic-only* password; never put it in source, screenshots or chat |

The other Admin/Member secrets are **not required** when running with `qa_mode=PATIENT_ONLY`. Their verification remains pending. Do not modify or reset any Google OAuth user.

After this PR is merged, open Actions → **Phase 2 Synthetic Staging Auth/RLS Gate** → Run workflow → branch `main` → `qa_mode: PATIENT_ONLY` → confirmation `STAGING_ONLY`.

The test uses actual Staging Edge Patient Login, token exchange and authenticated REST calls. It requires **distinct patient identities**, exactly one owned active Patient A plan, readable A prescription/task/completion/plan-action fixtures, **no visible plan for Patient B**, and no privileged roles for either patient. It checks that neither patient can see the other's patient identity, that Patient B cannot read A's clinical records or plan actions, and that Guest cannot read private rows. Missing A fixtures fail closed instead of printing an inconclusive message and passing. No clinical rows are modified. A real browser session/UI test is still pending.

## Admin and Google OAuth Member follow-up gates

Live Staging role/provider inventory (21 October 2026, non-identifying aggregate SQL):
- 2 Patient accounts: password-based Auth identities.
- 1 `super_admin`: synthetic email/password Auth identity.
- 2 `member`: **Google OAuth only**; neither Member has an Auth password.

The `PATIENT_ADMIN` mode reuses Patient A/B's already-configured secrets and requires only `SUKUN_STAGE_ADMIN_EMAIL` and `SUKUN_STAGE_ADMIN_PASSWORD` in GitHub Actions Secrets. It verifies real Admin Auth and Patient A's active clinical plan access, without incorrectly requiring a Member password.

The `FULL` mode now supports a **short-lived** Staging Google OAuth Member access JWT via the protected GitHub Actions repository secret `SUKUN_STAGE_MEMBER_ACCESS_TOKEN`. Obtain the token only through an authorized Staging OAuth session and approved secure credential workflow; do not paste it into chat, code, browser URLs, logs or public Pages. Access tokens expire; update the protected secret when it expires and repeat the manual run. The gate checks the token with Staging GoTrue and DB-issued `member` role and fails closed if expired, invalid, privileged or able to read clinical data.

The legacy Member email/password path remains supported for future separately approved synthetic email Member accounts; **it cannot authenticate the existing OAuth-only Member identities**.


| Secret | Staging account |
| --- | --- |
| `SUKUN_STAGE_PATIENT_A_ID` | Patient A's patient-code/identifier; must own an active synthetic plan |
| `SUKUN_STAGE_PATIENT_A_PASSWORD` | Patient A password |
| `SUKUN_STAGE_PATIENT_B_ID` | Different Patient B identifier |
| `SUKUN_STAGE_PATIENT_B_PASSWORD` | Patient B password |
| `SUKUN_STAGE_ADMIN_EMAIL` | Synthetic Super Admin login email |
| `SUKUN_STAGE_ADMIN_PASSWORD` | Synthetic Super Admin password |
| `SUKUN_STAGE_MEMBER_ACCESS_TOKEN` | **Preferred for existing OAuth Member:** short-lived synthetic Staging Google OAuth access JWT, protected Actions Secret |
| `SUKUN_STAGE_MEMBER_EMAIL` | **Alternative only:** separately provisioned synthetic email/password Member email |
| `SUKUN_STAGE_MEMBER_PASSWORD` | **Alternative only:** matching separate synthetic Member password |

**Do not transmit these values to ChatGPT.** Add them directly in GitHub repository Settings -> Secrets and variables -> Actions -> Repository secrets. The chosen A account must own an active Staging care plan and the selected accounts must have canonical server-issued database roles. All four must be distinct users. Never use Production credentials.

## How to run the Admin / FULL staging gates

1. Merge the reviewed gate PR **only after CI passes**.
2. To test Admin first, add the protected Staging Admin email/password secrets, then manually run **Phase 2 Synthetic Staging Auth/RLS Gate** on `main` with `qa_mode=PATIENT_ADMIN` and confirmation `STAGING_ONLY`.
3. For the complete four-role test, provide the **short-lived** synthetic OAuth Member JWT secret from an authorized Staging session. Manually run `qa_mode=FULL` on trusted `main` with confirmation `STAGING_ONLY`.
4. A/B authenticate through the actual Staging `patient-sign-in` Edge Function and GoTrue token exchange; Admin uses Staging GoTrue password login; OAuth Member uses its authorized short-lived access JWT validated by GoTrue `/auth/v1/user`. All role checks use server-issued Staging `user_roles` through REST.
5. The release gate **fails** if either patient has an additional privileged role; Patient A lacks prescription/task/completion/action fixtures or exactly one own active plan; B has a visible plan, can read A's patient, plan, action, prescription, task or completion; A can read B's patient; Member/Guest can read clinical records; or Admin cannot access A's plan. The fixture contract is intentionally strict.
6. No tokens, names, emails, passwords, database IDs or response bodies are printed, stored in artifacts or sent to public Pages.

## What success proves — and does not prove

| Test | Outcome |
| --- | --- |
| Authentic Staging Patient A/B login | Verified on run #39541838856 |
| Staging Admin + Patient live JWT | Pending manual `PATIENT_ADMIN` run |
| Google OAuth Member live JWT | Pending manual `FULL` run |
| Server-issued role lookup and distinct identities | Verified when manual run passes |
| Authenticated REST read isolation for known A data | Verified when manual run passes |
| Anonymous/member clinical access empty or denied | Verified when manual run passes |
| UI Create -> Draft -> Preview -> Publish in Flutter browser | **NOT** verified by this workflow |
| UI Today -> Done -> Progress, reconnect and reload | **NOT** verified by this workflow |
| Browser device acceptance (Safari mobile, Chrome desktop) | **NOT** verified by this workflow |
| Runtime write-idempotency from live browser tokens | **NOT** verified (covered separately by rolled-back SQL/RPC tests) |

The workflow runs network-free unit tests before calling Staging; **19 targeted regression tests** now run automatically on PR/main CI, even if secrets are not set. Successful offline CI does not establish new Admin/Member login or browser E2E results. A failed manual gate is a **release blocker**. If secrets are absent, the workflow fails with a generic message and does not attempt login.

## Next browser acceptance

Use the same Flutter code and approved isolated staging build (never create a second public site). With synthetic roles, follow `docs/qa/PHASE2_PATIENT_WEB_ACCEPTANCE_2026_10_20.md`, record commit SHA + sanitized result for G2-G8, and keep all failed cases open until tested. The source PR and CI success are not browser verification.
