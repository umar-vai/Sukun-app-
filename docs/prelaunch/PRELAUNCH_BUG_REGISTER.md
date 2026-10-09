# Sukun Life — Prelaunch Defect Register

Captured: 2026-10-08. Branch: chore/prelaunch-phase0-audit-20261008.
This is the canonical Phase 0 risk register. Do not close entries from source inspection alone. P0/P1 require passing regression evidence and authorized acceptance.

Severity: P0 = integrity/privacy/crash safety; P1 = essential workflow broken/confusing; P2 = usability polish.
Evidence: CODE-CONFIRMED = proven source path and effect/risk; REQUIRES-DEVICE = user complaint or plausible runtime issue needing reproduction; MISSING-FEATURE = release-scope feature not implemented.
Owner for every item: Engineering TBD; clinical/copy/privacy sign-off where noted.
Screenshot/device reproduction currently: NOT CAPTURED. Tests reported below are acceptance criteria, NOT tests already run.

## SUK-P0-001 — Existing action frequency interval changes on edit

Status: OPEN / CODE-CONFIRMED risk. Severity: P0.
Source: app/lib/features/care_plans/presentation/plan_action_editor_screen.dart, _populate and _submit; app/lib/features/care_plans/domain/plan_action.dart.
Repro in controlled test: save existing action with frequency daily interval 2 or 3; edit title only; save; read frequency_rule. Editor retains frequency type but not interval and constructs ActionFrequency.daily() with default interval=1. Compare persisted value.
Expected: unrelated edits preserve exact frequency, weekdays, time, dates, resource, review status and reminders. No inference of unknown time.
Fix contract: restore/display the original interval and allow explicit update; enforce unchanged round-trip unless selected.
Tests: unit/widget 2,3,7-day interval, weekly days, null-time, linked media; integration save/read; no unexpected task/reminder regeneration. Clinical reviewer must approve behavior.
Blocking: G1/G6. Branch: fix/care-plan-schedule-roundtrip.

## SUK-P0-002 — Resource search/categories truncated by first 1,000 records

Status: OPEN / CODE-CONFIRMED scalability defect. Severity: P0 pending reproduction at scale.
Source: app/lib/features/resources/data/supabase_resources_repository.dart browseResources: order/limit(1000) before client-side category and text filtering.
Repro: 1,001+ authorized published fixtures, target only record 1,001. Search by unique title/category; compare direct authorized query vs UI returned results.
Expected: complete, permission-safe server-filtered pagination/cursor; stable sort; no hidden records; no false empty results.
Tests: 1,001 and 2,000+ published items, last-page search/category, guest/patient permitted content, archived/assigned/staff_only denial and RLS. Owner includes DB/security reviewer.
Blocking: G1/G6. Branch: fix/resources-query-and-navigation.

## SUK-P1-003 — Internal exception text can leak to users

Status: OPEN / CODE-CONFIRMED presentation path. Severity: P1; escalates to P0 if sensitive info exposed.
Source examples: login_screen.dart, create_patient_screen.dart, patient_home_screen.dart, resource_browse_screens.dart, app_router.dart (error?.toString); AppErrorState renders incoming message unchanged.
Repro: inject benign network/backend failures via fake repos in widget tests; inspect visible Text and Semantics.
Expected: localized Bengali error code -> actionable, role-appropriate friendly message; no raw HTTP code, SQL, UUID, function name, token, stack trace or provider quota displayed. Diagnostic trace to protected logs only; no PHI.
Tests: widget test network/offline/validation/auth/unavailable resource/AI fallback; static lint to reject raw .toString usage in visible widgets.
Blocking: G1/G2/G6. Branch: feat/bangla-localization-and-error-ui.

## SUK-P1-004 — Technical English/hardcoded copy lacks central Bengali localization

Status: OPEN / CODE-CONFIRMED missing architecture. Severity: P1.
Source: app/lib/app/app.dart lacks l10n delegates/locales; app/pubspec.yaml lacks direct flutter_localizations/generate; no ARB files in main or web-preview trees; admin/patient nav + reminder_schedule and shared states have English.
Repro: navigate all screens with Bangla-first tester or screen reader; capture unfamiliar technical copy and translate meaning.
Expected: bn_BD default, centralized Flutter gen_l10n/ARB, simple action-oriented words, Bengali validation/help/errors/notifications/accessibility, Arabic text preserved, dates/time and plurals localized, no user-facing technical strings.
Tests: l10n generation, key parity, compile-time use, untranslated-key CI scanner + real device review.
Blocking: G2/G6. Branch: feat/bangla-localization-and-error-ui.

## SUK-P1-005 — Notification history/inbox interaction absent

Status: OPEN / MISSING-FEATURE. Severity: P1 for user-requested launch scope.
Source: app/lib/app/router/app_router.dart, patient_scaffold.dart and patient_profile_screen.dart; current notification_coordinator handles local/FCM sync/permission but no role-scoped inbox route or read/unread UI.
Repro: receive two notifications; try to find read/unread history or open a specific notification from an in-app inbox; verify absence before claiming runtime bug.
Expected: grouped own-message history, read/unread, link to own task/plan, expired-target fallback, delivery vs display state, permission/error UI.
Tests: RLS patient A vs B; foreground/background/killed app deep link; duplicate and offline; accessibility.
Blocking: G5/G6. Branch: feat/notification-inbox.

## SUK-P1-006 — Admin structured-action flow is excessively navigational

Status: OPEN / CODE-CONFIRMED design constraint, device measurements pending. Severity: P1.
Source: patient_detail_screen.dart -> create_care_plan_screen.dart -> care_plan_builder_screen.dart -> plan_action_editor_screen.dart; AI review imports drafts and separate action approval still required.
Repro: add and approve five actions; count total taps, distinct screens, returns and errors. Baseline NOT MEASURED.
Expected: inline quick action editor, templates for safe structure (no guessed clinical content), accessible linked-resource search, one workspace, sticky blockers, one safe final publish confirmation and audit history. Preserve source verification/explicit approval.
Tests: task-based UX benchmark target >=30% reduction in navigation/taps versus measured baseline; clinical approval path always enforced.
Blocking: G3/G6. Branch: feat/admin-patient-workspace.

## SUK-P1-007 — Production document-AI v20 behavior not reconciled to draft PR and prior diagnostic

Status: OPEN / ENVIRONMENT STATE CONFIRMED, FUNCTIONAL RESULT UNVERIFIED. Severity: P1 or P0 if unsafe output shown.
Source: docs/PRESCRIPTION_AI_DIAGNOSTIC_2026_10_08.md on web-preview describes v15 and unresolved model parsing; current production lists prescription-document-to-actions v20, prescription-to-actions v10. Draft PR #2 contains AI/parser changes.
Repro: authorized redacted document exercise with trace categories and full human review; do not use real patient data in logs.
Expected: recognized input -> validated suggestions -> unapproved draft -> individual review -> safe publish; clear nontechnical Bengali manual fallback on failure; zero model/quota secret exposure.
Tests: rate limit/invalid JSON/empty response, idempotent retry, no double-import, no auto approval; secure log review.
Blocking: G0/G1/G6. Branch: keep isolated in PR #2 until verified and coordinated.

## SUK-P1-008 — Database applied-migration vs source reconciliation

Status: OPEN / EVIDENCE-CONFIRMED inventory mismatch; not proof of schema error. Severity: P1 release-control risk.
Evidence: live migrations 37, main migration files 14, web-preview 17; applied names/versions differ across histories.
Repro: compare schema and migration provenance/checksums in a staging clone; do not rely only on counts.
Expected: documented mapping, no replay of already applied SQL, RLS verified and additive staged rollout/rollback rehearsed.
Tests: migration dry run, pgTAP authorization and schema invariants; no production reset.
Blocking: G0/G6. Owner: DB/release operator.

## SUK-P1-009 — Resource browser screen reloads/retry/refresh and route-context issues

Status: OPEN / CODE-CONFIRMED likely inefficiencies, DEVICE-REPRO NEEDED. Severity: P1.
Source: resource_browse_screens.dart builds some futures directly in build, several errors lack retry; resources_home_screen.dart refresh calls void _refresh in async callback, source route switches to global /resources paths.
Repro: switch filters rapidly, return via back, rotate/rebuild, pull refresh under slow connection, open resource from patient bottom tab.
Expected: one stable request per state, stale-response protection, cache/debounce, retries, preserved shell/back stack and honest loading state.
Tests: widget routing and race tests, delayed/failure repo fixtures, device back navigation.
Blocking: G4/G6. Branch: fix/resources-query-and-navigation.

## SUK-P1-010 — Patient Today duplicates featured next action and list action

Status: OPEN / CODE-CONFIRMED UI duplication. Severity: P2 unless it causes duplicate completion confusion (then P1).
Source: patient_home_screen.dart: day.nextTask appears in featured card and day.tasks loop renders same item again.
Repro: fixture with one next task; count duplicate task controls and completion state.
Expected: one primary completion target, no conflicting multiple buttons; other actions in normal list.
Tests: widget one/many tasks; no duplicate completion events.
Blocking: G4. Branch: feat/patient-resources-and-today.

## SUK-P1-011 — Resource link appears openable without full media validation

Status: OPEN / CODE-CONFIRMED inconsistent checks. Severity: P1.
Source: LinkedResource.canOpen checks nonempty fields, while resolveResourceMedia enforces HTTPS and recognized media type; resource_detail_screen uses canOpen to display CTA.
Repro: published fixture with invalid/unsupported URL; button renders but fails on tap.
Expected: no misleading play/open CTA; friendly localized invalid/expired-link fallback and retry; valid YouTube, audio, PDF handled correctly.
Tests: unit/widget valid, invalid scheme, missing ID, stale link, unsupported type.
Blocking: G4/G6.

## SUK-P1-012 — Notification scheduling silently swallows refresh failures

Status: OPEN / CODE-CONFIRMED silent failure path, device scope unverified. Severity: P1.
Source: notification_coordinator.dart _syncSafely catches all; patient_profile_screen.dart mostly reflects preference/permission, not successful scheduling or delivery state.
Repro: fake repository/local gateway throwing during scheduling or token registration; compare UI claim vs scheduled state.
Expected: not block care task completion; record privacy-safe diagnostic status, retry, accurate Bangla status such as 'মনে করিয়ে দেওয়া চালু আছে, তবে সময় ঠিক করা যায়নি'.
Tests: local permission, exact alarms, timezone change, failure injection, stale reschedule, snooze and disable.
Blocking: G5/G6.

## SUK-P1-013 — Notification language and app-shell accessibility

Status: OPEN / CODE-CONFIRMED. Severity: P1.
Source: reminder_schedule.dart uses English title/body; patient_scaffold.dart/admin_scaffold.dart English nav labels; AppLoadingState/AppErrorState English defaults.
Repro: schedule local reminder and navigate with TalkBack; capture rendered text/semantics.
Expected: plain Bengali action/time reminder, no PHI in lock-screen banner; every nav label, semantics and accessible tap target Bangla.
Tests: native Android/iOS screenshots, screen-reader tests, semantic assertions.
Blocking: G2/G5/G6.

## SUK-P1-014 — No verified full release-binary / backup rollback evidence

Status: OPEN / RELEASE-GATE REQUIREMENT; not asserting backup is absent. Severity: P1.
Source: previous visual report proves selected Android 14 check, not current release binaries or iOS live verification. Phase 0 current runtime has no Flutter/Dart SDK; no builds run.
Repro/collection: match app build SHA and device-installed version; validate backups, restoration drill, signed builds and production deploy hashes via release operator.
Expected: documented build provenance, tested restore, safe rollback/pilot, owner and clinical/security approval.
Tests: Android release and iOS signed device validation; safe staging migration, smoke/acceptance suites.
Blocking: G0/G6.

## Triage / Evidence requirements

Each issue is only marked FIXED after:
1. reproducible before/after evidence (where possible),
2. automated regression and CI or clearly explained inability,
3. sanitized screen captures when UI-facing,
4. role-based human acceptance if clinical/security/Arabic text relevant,
5. no regression to RLS, audit trail or patient schedule,
6. merge SHA/build SHA/deployment notes.

Prioritized order: 001, 002, 003, 007, 008, 004, 009, 011, 006, 005, 012, 013, 010, 014; release gate 014 must remain active from day one. This order is a dependency plan, not a promise that any are fixed.

Referenced production state: docs/prelaunch/PHASE_0_RELEASE_BASELINE.md.
