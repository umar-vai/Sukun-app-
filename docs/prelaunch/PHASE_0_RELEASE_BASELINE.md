# Sukun Life — Prelaunch Phase 0: Release Baseline & Gate G0

Date: 2026-10-08 (Asia/Dhaka)
Branch: chore/prelaunch-phase0-audit-20261008
Purpose: freeze an auditable baseline before correctness, Bengali UX, admin, patient, notification and release work.
Status: IN PROGRESS / G0 NOT YET PASSED. This is a read-only audit plus documentation change; NOT an implementation, production backup, deployment, or release approval.

## 1. Product and change-control boundaries

- Repository: https://github.com/umar-vai/Sukun-app-
- Existing public Sukun Life website and existing internal dashboard are OUT OF SCOPE and must not be changed.
- The standalone Flutter app has guest/public, patient and super-admin modes.
- Preserve server-enforced Supabase RLS, audited content verification, prescription provenance, clinician/admin approval, plan versioning, sensitive-data privacy and notification safety.
- No AI-generated instruction can be published without explicit human verification.
- This Phase 0 branch must remain documentation-only, isolated from ongoing web-preview PR #2.
- Do not merge an unfinished or draft PR or apply production migrations while working on Phase 0.
- No secret values, patient identities, prescriptions, tokens, push payloads, device identifiers or private production records may appear in the evidence package.

## 2. Baseline captured (read-only)

### Repository

| Item | Observed |
|---|---|
| Default branch | main |
| main commit | 83622430e391a8f658e0396293954870e2899366 |
| Parallel branch | web-preview at fdeff6765c497c49cd027d213501f002d3be3326 |
| Parallel PR | #2: Web preview setup; OPEN, DRAFT, not merged; targets main |
| PR #2 scope | 54 changed files, including AI review, prescription document upload/extraction, resource picker, Flutter web preview, backend tests and migrations |
| main source inventory | 26 named feature screen files, plus resource browse sub-screens and guest/admin homes |
| Flutter test files in main | 25 (presence verified; not executed during this audit) |
| GitHub migration files | main: 14; web-preview: 17 |
| GitHub CI | main has .github/workflows/ci.yml; no local Flutter/Dart SDK in this audit runtime |

PR: https://github.com/umar-vai/Sukun-app-/pull/2

Do not assume a GitHub branch/PR SHA is the same binary now installed on patient phones. Capture the actual Android application version/build SHA, iOS TestFlight/build SHA (if applicable), web preview deployment SHA, Firebase client configuration and corresponding backend schema before declaring the release baseline authoritative.

### Live production backend metadata

Read-only project: Sukun Mobile App, ref vydfafumxptanpkmtrpr; state ACTIVE_HEALTHY at inspection.
- 25 PUBLIC base tables observed and RLS enabled on all 25. This is metadata-only; no RLS isolation test was executed here.
- 37 applied migrations listed by the live project, versus 14 migration files in main and 17 in web-preview. Counts and timestamps are not directly comparable: reconcile deployed migration identities, existing baseline/history and schema differences before any new migration or rebase; do not reset production.
- 6 ACTIVE Edge Functions:
  - patient-sign-in v7
  - patient-change-password v6
  - admin-create-patient v7
  - prescription-to-actions v10
  - send-notification v3
  - prescription-document-to-actions v20
- Previous web-preview diagnostic document refers to document v15. Live document function is now v20; prior diagnosis is historical and requires renewed status verification.
- No user/clinical rows, secret or private log content were read for this report.

Live notification_events and notification_devices are infrastructure tables; they do not establish a complete patient-facing read/unread inbox or history UI by themselves.

### Source and visual acceptance

- docs/VISUAL_QA_REPORT.md describes earlier visual review, including selected Android 14 device testing, but does not prove current post-change flow correctness or all device acceptance.
- No central app/lib/l10n ARB resources in either main or web-preview inspected trees.
- app/lib/app/app.dart constructs MaterialApp.router without app-localization delegates or supportedLocales.
- app/pubspec.yaml has no direct flutter_localizations dependency or Flutter generate:true configuration.
- PatientScaffold and AdminScaffold currently expose English navigation labels.
- app/lib/core/widgets/async_states.dart contains English loading/error/retry fallback copy.
- app/lib/core/notifications/reminder_schedule.dart includes English local reminder text.
- Many presentation widgets display raw error.toString() or snapshot.error.toString().

Heuristic grep-like source survey of 28 UI presentation files (26 named screens plus resource browsing and role home): 33 occurrences of error-toString patterns, 207 direct Text(single-literal) patterns and 239 English-leading field-literal patterns. These are pattern occurrences, NOT distinct text strings, not a claim that all are visible, and not a complete translation count. The router adds another raw error-toString path. Manual review, extracted ARB keys and native screen accessibility exploration must produce the final exhaustive inventory.

## 3. Phase 0 screen/state inventory

Use docs/prelaunch/BANGLA_UI_AND_SCREEN_INVENTORY.md for the detailed owner/role/surface list.

Every surface must cover: initial/loading; data; empty; filter-no-results; permission/unauthorized; offline; backend/network failure; retry; unsaved edits; save success/failure; duplicate tapping; navigation/back; small screen; large text; screen-reader label. Relevant surfaces also require Arabic RTL, media, timezone and notification event tests.

Role domains: authentication; guest/public home; admin dashboard/patients/prescriptions/plans/AI review/CMS; patient Today/My Plan/resources/progress/profile; public Qur'an/Hadith/Dua/Ruqyah/resource player; prayer/Qibla; notification permission/local push/foreground/background/deep-link.

## 4. Baseline defects and Phase 1+ work

The issue-by-issue register with priority, evidence, reproduction and acceptance tests is in docs/prelaunch/PRELAUNCH_BUG_REGISTER.md.

Immediate release blockers:
- SUK-P0-001: editing an existing every-N-days action can normalize interval to daily.
- SUK-P0-002: general resource browse truncates to first 1,000 published records then applies client-side text/category filtering, creating incomplete results in a large library.
- SUK-P1-003: raw technical exceptions flow to visible error UI.
- SUK-P1-004: incomplete Bengali language architecture and technical English UI text.
- SUK-P1-005: no end-user notification inbox/deep-link/read-state workflow established.
- SUK-P1-006: admin plan and action creation requires repeated full-screen navigation.
- SUK-P1-007: existing document-AI live function/repo-state reconciliation and end-to-end proof unresolved.

Defect validation must distinguish SOURCE-CONFIRMED, DEVICE-REPRODUCED and HYPOTHESIS/NOT IMPLEMENTED; do not assert all bugs reproduce on a phone without evidence.

## 5. Workflow-measurement baseline (not yet empirically measured)

Measure a real admin doing a complete prescribed-care task: open patient -> record prescription -> create versioned draft -> add 5 mixed-frequency actions with media links -> review all -> publish -> confirm patient view.
Record: physical taps, distinct screens, backtracks, time, validation mistakes, unapproved-action blockers and first-attempt task completion. Do this once on CURRENT production-like build before UI overhaul and again after Phase 3; target >=30% fewer navigation/tap interactions without reducing review safety. Do not invent a baseline number from static route counts.

Patient test: sign in -> understand next action -> complete or snooze -> open assigned resource -> return -> understand updated progress; capture success without coaching and time-to-first-action.

## 6. Safe rollback and snapshot preconditions

NOT DONE by this audit:
- Production snapshot/restore-point verification by an authorized operator, including completion of a restore drill.
- Baseline export of deployed migration checksums and function bundles at a known timestamp.
- Capture versioned care-plan/task/reminder invariants as aggregate, de-identified metadata only.
- Confirm rollback support for published plan versions, re-indexing/notification changes, mobile rollout version pin and App Store/Play Store rollback constraints.
- App deployment SHA and build provenance.
- Verify migration-to-code parity for PR #2 schema additions.

Before ANY production writes: validate access, point-in-time backup support, rollback owner, additive migration, RLS and PHI exclusion, staged dry run and a documented stop condition. Do not copy production patient data into test environment without approved controls.

Rollback owners:
- Engineering/release operator: TBD (name/approval pending)
- Clinical/source-review owner: TBD
- Bengali microcopy approver: TBD
- Security/privacy approver: TBD

## 7. Gate G0 checklist

- [x] Source main SHA and PR #2 draft SHA/status recorded.
- [x] Live Supabase project, public-table RLS metadata, migration and function inventory recorded.
- [x] Key source-level defect/risk register created.
- [x] Screen/role/Bengali copy inventory seeded.
- [x] Documentation-only isolated branch prepared; no production mutation.
- [ ] Release binary / preview / production function deployment provenance and migration parity confirmed.
- [ ] Current AI pipeline v20 verified with authorized, redacted end-to-end test.
- [ ] Admin/patient actual tap-count, path and completion metrics measured on device.
- [ ] Screen states, text, dialogs, bottom sheets and TalkBack/VoiceOver verified with device screenshots (sanitized).
- [ ] Backup, recovery point, restore dry run and rollback operator sign-off recorded.
- [ ] Engineering, clinical, Bengali content and privacy ownership assigned.
- [ ] Gate G0 accepted by release owner.

Decision at capture: **NO-GO for release approval; Phase 0 partially complete.** Do not start broad UI rewrite against an unverified production schema; isolated correctness test and fix design may proceed in a separate branch, but no live production deployment until baseline preconditions are resolved.

## 8. Next execution order after G0

1. Freeze/merge strategy for PR #2 (preserve and review rather than silently overwrite).
2. Tests and fixes for schedule round-trip and resource 1,000-item truncation.
3. Central Bengali localization (bn_BD default), approved glossary, error-code mapping, visible-copy lint.
4. Admin quick-action workspace with safety-preserving review; patient resource and Today improvements.
5. Notification center with owner-only RLS, dedupe, delivery diagnostics and safe deep links.
6. Regression, accessible Bengali UAT and signed release artifact/rollback checks.

Source references:
- docs/PRODUCTION_ENVIRONMENT.md
- docs/VISUAL_QA_REPORT.md
- docs/PRESCRIPTION_AI_DIAGNOSTIC_2026_10_08.md (on web-preview)
- docs/FINAL_UI_REFERENCE.md
- docs/VISUAL_ACCEPTANCE_GATE.md
- https://docs.flutter.dev/ui/internationalization
