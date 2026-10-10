# Sukun Life — Patient/Admin staging acceptance gate (10 October 2026)

## Scope and environment

Use the **existing Flutter Web App** at
https://umar-vai.github.io/Sukun-app-/ with **isolated** Supabase
`qacklgqvxvjjzsimjoip` (Staging). Production backend
`vydfafumxptanpkmtrpr`, `sukunlife.com`, and the old internal dashboard
are **out of scope and must not be changed**.

Status observed at the start of this block:
- Main SHA `a9e462b87c4d9f5b06130029b971db950ff9a2bc`:
  CI and Pages deployment passed.
- Staging has one Google-authenticated **Member** (no Patient/Admin), zero
  patient rows, zero care plans, zero resources.
- Staging ACTIVE Edge Functions: `admin-create-patient`,
  `send-notification`, `prescription-to-actions`,
  `prescription-document-to-actions`.
- **Critical gate:** Patient sign-in and change-password Edge Functions are
  **not** verified deployed. Do not claim a Patient ID/password login works.
  Previous change-password deployment was blocked by connector policy.
  Do not bypass this safeguard; review and deploy with the authorized
  operator/security process.
- No synthetic real Auth Admin account exists yet.

## Completed/automatable gate

`supabase/tests/canonical_patient_care_e2e_test.sql` runs in the disposable
Supabase CLI database and rolls all fixtures back. It verifies real SQL
functions and row-level security through a complete test path:

1. Synthetic Auth user + database-verified Super Admin role; distinct
   synthetic Patient A, Patient B and public Member.
2. Admin creates a patient-visible prescription; immutable version present.
3. Admin creates a draft care plan linked to the prescription.
4. Admin adds an unresolved action; premature publication is rejected.
5. Admin approves the action; publishes the active plan; audit recorded.
6. Patient A sees only their published prescription and plan.
7. Patient A generates a daily task, completes it by guarded RPC, and sees
   an append-only completion record/progress.
8. Patient B cannot read or complete Patient A's task even with its UUID.
9. Public Member cannot see clinical plans; anonymous visitor cannot read
   private completion records.

This test does not create any real Supabase Auth session and does not prove
browser or mobile sign-in. It **must not** be treated as Production QA.

## Live Staging browser acceptance — operator/credential dependency

Only the Supabase Auth Admin workflow or other approved Auth API should create
usable live test users. **Do not manually insert `auth.users`/`auth.identities`
to provision a live login. Do not post any passwords or tokens in GitHub,
chats, public Pages or screenshots.**

1. **Synthetic Staging Admin:** an authorized operator provisions a dedicated
   test Auth identity using Supabase Staging's dashboard/Auth Admin API and
   grants `super_admin` **only** via the approved database-verified
   administrative process. A newly Google-registered Member alone must not
   grant itself elevated privileges.
2. **Synthetic Patients:** the Admin, once logged in on the real Flutter Web
   Preview, creates two clearly synthetic patients with approved disposable
   telephone/test credentials through the app's existing
   `admin-create-patient` server function (not a hand-made Auth row).
3. **Patient Login:** before using the Patient ID/password workflow, configure
   a **distinct Staging-only** persistent sign-in rate-limit secret and
   complete approved `patient-sign-in`/password-change Function deployment,
   rate-limit tests and browser API compatibility verification. If the
   permission/security gate blocks deployment, **stop** and report it.
4. **Patient A acceptance:** Admin creates a draft prescription and action;
   mark explicit medical/religious instructions as a synthetic fixture and
   require review before publishing. Patient A logs in, changes the
   temporary password, sees their own daily tasks, Done/Skip/Snooze,
   progress, history and notifications.
5. **Patient B negative test:** Patient B tries to access Patient A's
   patient/plan/task IDs through **direct REST/RPC** and through Flutter
   navigation. Expect empty/403/404. Verify no cross-patient updates.
6. **Member negative test:** Google Member attempts `/admin/patients`,
   `/patient/today` and privileged Data API/RPC. Must never gain access.
7. **Session/Logout:** verify Browser Refresh, browser restart, logout,
   repeat login, token expiry/refresh, and direct protected links after
   logout. Note: Supabase's revoked JWT access tokens may remain valid until
   their natural expiration. Do not claim immediate server-side revocation
   without explicit session validation/short TTL enforcement.
8. **Devices:** desktop Chrome and real mobile Chrome/Safari, slow/offline
   network, temporary expired session, narrow widths, Bangla typography.
9. **Evidence:** record Main SHA, staging deployment/function versions,
   main CI, Pages build and exact HTTP commit marker, and **real** browser
   acceptance separately. Never save patient passwords or sensitive
   screenshots in a public issue.

## Security notes

The Staging security advisor currently reports:
- `authenticated_security_definer_function_executable`: nine exposed
  functions intentionally available to authenticated roles. Review every
  function's own role/ownership checks before declaring the warning safe;
  **do not** blanket-revoke these since patient task operations require some
  of them.
- `auth_leaked_password_protection` disabled in Staging — request authorized
  dashboard configuration where supported.
- Two `ai_*` tables have RLS with no policies: intended server-only access
  should be verified.

### Exit criterion

Patient/Admin live sign-in and role-isolated browser E2E remain **BLOCKED**
until the dedicated synthetic users, required Auth Function security secrets,
live deployments and cross-user negative tests are all actually verified.
Database test success alone is not a release approval.

**Web-first only.** No automated APK/AAB/IPA or production deployment.
