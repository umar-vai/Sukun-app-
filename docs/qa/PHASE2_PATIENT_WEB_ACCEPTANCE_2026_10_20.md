# Phase 2 — Patient workflow Web acceptance gate (20 October 2026)

**Status: NOT YET APPROVED.** This is a test plan, not a claim that live authenticated browser flows passed. The user's recent screenshot confirms the Home/routine/resource UI renders, but does not prove a complete patient role or admin-to-patient workflow.

## Environment and safety

- Use the existing real Flutter Web preview at `https://app.sukunlife.com/` and the SHA from `/preview-build.json`. Do not create a parallel mockup or ship native APK/AAB.
- Use only explicitly identified owner-controlled synthetic **Admin, Patient A, Patient B, General Member** accounts and synthetic care-plan text. Confirm each test account's actual server role before testing. Keep passwords, JWTs, service-role keys and any personal records out of screenshots/logs/public CI artifacts.
- Prefer isolated Supabase Staging `qacklgqvxvjjzsimjoip` for destructive or adversarial test scenarios. Web preview currently uses production backend config; don't silently redirect or reseed production.
- Do not bypass Auth/RLS, alter production clinical records, or turn off row-level security to make a browser test pass.

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
