# Care team permission foundation — 9 October 2026

**Draft migration; not applied to production Supabase.** Depends on PR #19.

## Scope
- Adds `raqi` and `support_staff` to the app role enum. Members, patients
  and super admins remain unchanged.
- Creates an auditable assignment metadata table with an actor, role and
  active/inactive timestamps. The table records a patient UUID, not medical
  content or treatment.
- Only super admins can create/reassign/deactivate/delete mappings through RLS.
- Raqi/support may only read their own **active** mappings and only when
  their DB user_roles record matches the mapping role.
- Critically, existing patients/prescriptions/care plan RLS is **unchanged**.
  Neither Raqi nor Support gets clinical record access in this phase.
- The UI shows public authenticated home for these roles until a dedicated
  staff workspace and audited server-side APIs are approved.

## Follow-up before staff portal
- Identity-checked, administrator-approved staff onboarding.
- Clear field-level patient visibility requirements for Raqi vs Support.
- Assignment audit / revoke procedures, staff offboarding, MFA and
  incident response, scoped RPCs, explicit negative RLS tests.
- No client-set role, no access based only on visible UI and no service
  role credentials in Flutter.
- Test realistic two-raqi, two-support, same-patient revocation scenarios,
  verify backups before any production migration.
