# Sukun Life — 2026-10-09 Phase 0 audit baseline

Source of truth: user-provided Sukun_Life_Full_Development_Brief(1).md (2026-10-09).
This is the **new roadmap**, distinct from the older GitHub scaffold phase numbering.

## Baseline and scope
- Project: Sukun Mobile App; Supabase project ref `vydfafumxptanpkmtrpr`.
- Existing website and dashboard must remain untouched.
- Phase 0: app/backend/security/architecture audit.
- Phase 1: security hardening, backup, access, monitoring.
- Phase 2: stabilize existing patient/prescription/daily actions/progress.
- Phase 4: general user OTP/email/Google sign-in (preparatory Auth review may run in Phase 1).
- No production SQL mutations were performed during this baseline audit.

## Verified read-only findings (2026-10-09)
1. Project reports ACTIVE_HEALTHY, PostgreSQL 17.
2. All 25 public tables have RLS enabled; this is a configuration observation, **not** proof of complete authorization.
3. Security Advisor reports eight authenticated-callable `SECURITY DEFINER` functions: `admin_search_patients`, `create_prescription`, `create_prescription_attachment`, `ensure_patient_reminder_tasks`, `ensure_patient_tasks`, `record_task_completion`, `register_notification_device`, `remove_notification_device`. All deny anon EXECUTE. Inspected function excerpts show admin-role or patient ownership guards, but complete body/behavioral negative tests still required. Do **not** revoke authenticated EXECUTE blindly; patient features require some of these RPCs.
4. Auth leaked-password protection is disabled (security warning). Enable using Dashboard/Auth settings and verify.
5. Two server-internal AI tables `ai_generation_requests` and `ai_provider_slot_health` have RLS enabled and no client policies. Confirm service-role-only model and no unwanted REST exposure before changing anything.
6. Selected RLS policies show owner/admin predicates for `patients`, `prescriptions`, `profiles`, and `user_roles`; negative identity-isolation tests not yet run.
7. Performance Advisor identified four foreign keys without covering indexes, plus many apparently unused indexes. **Do not drop indexes merely because usage is zero** in an early project.

## Next gated actions
- P0-A: Review entire bodies/call grants of definer functions, storage policies, private helpers, and auth claims; perform safe cross-patient / anon / staff denial tests in staging.
- P0-B: Review Flutter auth/navigation state handling and current provider configuration, including legacy patient ID login.
- P1-A: Enable leaked password protection (production configuration), review session/rate-limits, MFA requirements, email delivery and recovery.
- P1-B: Confirm automated backups and conduct staging restore drill; secure storage and private media policies.
- P1-C: Fix verified vulnerabilities in version-controlled migrations, apply to staging, run tests, then carefully deploy.
- P2: Patient flow stabilization and actual device QA.
- P4: OTP + email + Google onboarding and general-user role with backward-compatible patient accounts.
- Review GitHub CI and tests before considering any public release.

## Progress reporting
A checkpoint is **complete** only when its evidence and test result are recorded. Never interpret an advisor warning automatically as an exploit, nor an RLS toggle as proof of isolation. This document records Phase 0 baseline only; release remains blocked pending QA.
