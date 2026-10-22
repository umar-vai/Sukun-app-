# Phase 2 — Patient workflow Web acceptance gate (20 October 2026)

**Status: PARTIAL; NOT RELEASE APPROVED (22 October 2026).** Patient A/B live authenticated REST isolation passed on Staging, and the real Pages Staging build/deploy completed on SHA `2b6e834d483d87045196298ec1a8a4f9aaee370a` (Actions #39753491993). An additional credential-free deployed Chromium acceptance check is being introduced separately; its success must not be presumed from source/CI alone. Admin/Member real JWTs and full clinical browser G2–G8 remain unverified. The user's recent screenshot confirms the Home/routine/resource UI renders, but does not prove a complete patient role or admin-to-patient workflow.

## Environment and safety

- The **actual currently configured GitHub Pages URL**, verified in deploy job #39753491993, is `https://app.sukunlife.com/` (custom Pages domain; no DNS change made by this QA). Its latest verified `main` SHA is `2b6e834d483d87045196298ec1a8a4f9aaee370a` with the approved isolated **Staging** backend. For every future rollout, re-check `/preview-build.json` (`commit` + `backend_mode`) and the Pages HTTP SHA verification before logging in. This is an existing custom Pages configuration, not authorization for Production release or a new domain. Do not create another hosted app, public mockup, or native APK/AAB.
- Use only explicitly identified owner-controlled synthetic **Admin, Patient A, Patient B, General Member** accounts and synthetic care-plan text. Confirm each test account's actual server role before testing. Keep passwords, JWTs, service-role keys and any personal records out of screenshots/logs/public CI artifacts.
- **Only** use isolated Supabase Staging `qacklgqvxvjjzsimjoip` for patient/admin authenticated QA. The currently deployed Pages build uses Staging; do not assume future deployments do without checking the manifest. Authenticated cross-patient read-only REST tests passed for Patient A/B in run #39541838856; clinical Flutter browser flows G2–G8 remain pending. Never redirect or reseed Production.
- Do not bypass Auth/RLS, alter production clinical records, or turn off row-level security to make a browser test pass.

## Credential-free deployed Chromium gate (new, not a clinical E2E pass)

The new `Deployed Staging Browser Acceptance` GitHub Actions workflow runs only after a successful **trusted main Flutter Web Preview** deployment. It checks the deployed manifest's exact main SHA and `backend_mode: staging`, boots real Chromium at desktop and mobile sizes, visits Guest and Login, and checks that anonymous Patient/Admin deep links redirect before displaying protected routes. The browser also rejects any clinical/Auth API request to the Production backend. No login credentials, tokens, clinical data, screenshots, storage or response bodies are collected. Failures block **browser acceptance reporting** and require triage; they are not evidence of clinical user login.

This automation does **not** test Admin prescription publication, Patient completion writes, real Google Member OAuth, session-recovery across devices, or accessibility/readability screenshot acceptance. Keep those G2–G8 gates pending until independently verified with authorized synthetic sessions.

## Required checks in order

| Gate | Evidence required | Status |
| --- | --- | --- |
| G1 Build/deploy | Main CI passes; Pages job deploys; `/preview-build.json` matches exact main SHA | Existing build verified previously; repeat for next change |
| G2 Admin creation | Signed-in synthetic Admin creates/opens test Patient, adds synthetic prescription | Pending browser QA |
| G3 Human approval | Admin drafts actions; deliberately leaves one action unapproved; publishes only explicitly approved actions; audit/version respected | Pending browser QA |
| G4 Patient login and Today | Synthetic Patient A signs in with Patient ID; sees only own active plan, Today, schedule, links and prescription | Pending browser QA |
| G5 Completion and progress | Patient A completes an approved task; duplicate tap does not duplicate event; completion/progress persist after reload | Pending browser QA |
| G6 Role isolation | Patient B cannot fetch Patient A plan/resource via guessed URL or REST/RPC; General Member cannot read clinical resources; Guest cannot open protected screens | Pending authenticated negative tests |
| G7 Recovery and device | Logout/login, Safari mobile width, small viewport, offline completion queue/reconnect, notification fallback, refresh without user data loss | Pending browser QA |
| G8 Content readability | Home next-action time entirely Bengali; Quran Dark Mode selection readable; no duplicate bottom bars; attached resource cards readable | Requires screenshot review |

## Test evidence format

For each check record: exact Web SHA; tested role alias (never Patient ID); device/browser; UTC time; action; pass/fail; sanitized screenshot reference; relevant SQL/RLS test ID. Synthetic content should be removable only after test-run signoff; never reset all production user data.

## Release-blocking failures

- Cross-patient clinical read/write, privilege escalation or accidental publication of unapproved actions.
- Patient sign-in/regression, stale session route leak or data loss.
- Prescription frequency interval/time unexpectedly changes when editing unrelated fields.
- Repeated completion unexpectedly duplicates clinical progress.

Finish **Phase 2 acceptance** before considering a public release. A code commit, a CI green tick and a screenshot are separate evidence types.
