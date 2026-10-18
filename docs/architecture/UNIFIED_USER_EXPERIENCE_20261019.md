# Unified signed-in experience — 19 October 2026

## Product decision
The user approved ONE primary Flutter user experience for normal Members and care-assigned Patients. Super Admin retains a separate management interface. There are no separate Member/Patient primary tabs or mandatory alternate dashboards.

The common signed-in navigation is **Home · Routines · Progress · Resources · Account**. Public Guest navigation remains read-only. Both Member and Patient accounts use the same owner-private personal routine CRUD and history API, with Done/Skip entries stored in `personal_routine_progress` under RLS. Previously created routines are not migrated or deleted.

## Care data is an assignment, not a second user interface
A verified legacy Patient account can additionally open an approved plan, notifications, patient-visible prescriptions and related clinical progress. These cards are contextual content, not a new global navigation. Such records remain available ONLY to a server-authorized patient identity, with separate RLS and server-side checks. Ordinary Members MUST NOT be allowed to see clinical records simply by navigating to a patient URL, impersonating a role, editing metadata or guessing an ID.

**Important:** This UI unification does NOT automatically link existing office patient records to a Google login. Clinical identity matching must be a separate, explicitly reviewed, verified, audited Admin workflow. Never link solely by matching a name or phone number.

## Implementation
- Shared navigation definition is used on Member home, Patient home, Member/Patient deep links and legacy care-detail scaffolds.
- Shared account/profile destination shows the active Supabase session's own display name and email, routine/history links and sign out.
- Shared 7/30 day progress view reads the signed-in owner's marked Done/Skip events. Its ratio is **only the fraction of recorded actions marked Done**, NOT treatment outcome or adherence against every scheduled task.
- Patient legacy ID login, care-plan/prescription views and admin routes are preserved. Admin content/editor/patient management code remains unchanged.
- No DB migration, role consolidation, legacy auth account rewrite, API secret or native build is required for this UI increment.
- Existing `sukunlife.com`, old dashboard, DNS and future app subdomain are untouched.

## Required acceptance before main merge/deploy
1. `dart format --output=none --set-exit-if-changed`, `flutter analyze`, `flutter test`, backend/RLS and Web CI must pass.
2. Browser: independent synthetic Member and Patient use identical five-tab navigation, routine creation, completion, progress reload/history and account sign-out.
3. Browser: a Patient's assigned plan is only visible with that Patient's session; ordinary Member, Guest and Patient B are denied cross-user clinical data and cannot call privileged patient RPCs.
4. Browser: Admin still lands at `/admin/dashboard`, sees existing management navigation and publishes care plans without regression.
5. Old Patient ID login and Google OAuth session restore remain functional. Patient with no plan must see safe empty state.
6. After approved merge, verify exact `main` commit CI, Pages deploy, HTTP deployed SHA and interactive browser roles independently. Do not equate a PR or SQL commit with release.

## Deferred, explicitly not included
- Auth account linking/merging with old office patient files (needs identity verification + audit).
- Combined day-by-day personal and prescribed task checklists (requires shared scheduling semantics and clinical approval).
- Streak/missed-day inference or percent-of-scheduled target (not derivable reliably from just Done/Skip events).
- Any public Production release claim before CI + browser + security gates.
