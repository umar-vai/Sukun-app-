# Routine Template Release Gate

This document describes **reusable, nonclinical** routine templates.

## Data boundaries
- `routine_templates` and `routine_template_steps`: Super Admin creates Draft and publishes; signed-in users can only read Published entries.
- `personal_routines` and `personal_routine_actions`: user-owned records, independently protected by ownership RLS.
- `care_plans` and prescriptions: a different, clinician-authorized workflow. No routine template operation updates it.
- Anonymous users cannot list templates. Never ship service-role keys in Flutter Web.

## Safe activation checklist
1. Commit additive migration and run its rollback-only pgTAP RLS checks in a disposable Supabase backend.
2. Verify `private.is_super_admin()` authorization, owner isolation, and that unpublished/draft steps are hidden from normal users.
3. Apply the **same reviewed migration** to the designated Supabase project through an explicit migration operation, separately from merging GitHub code.
4. Recheck live tables, grants, policies and RPC access; do not use production patient data as fixtures.
5. Only after backend readiness, merge and deploy the Flutter Admin editor and signed-in opt-in tab.
6. Verify with authorized synthetic Admin and Member sessions: draft → add step → publish → copy to personal routine → check isolation. Verify that clinical plans remain unchanged.
7. Existing sukunlife.com remains untouched; use only the approved GitHub Pages Flutter Web preview during development.

**Notes:** Web browser reminders may require an open tab unless browser push is confirmed available. Copying a template is explicit and does not schedule a clinical action automatically.
