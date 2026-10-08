# Production Security & Performance Advisory Triage (READ ONLY)

Captured: 2026-10-08 13:21 Asia/Dhaka. Project: Sukun Mobile App / vydfafumxptanpkmtrpr.
Source: connected Supabase Security Advisor and Performance Advisor. No production writes, no secrets, no patient rows read.
Important: advisory != verified exploit. Do not alter grants or drop indexes automatically.

## Security Advisor snapshot

### WARN: 8 executable SECURITY DEFINER functions

The advisor reports authenticated EXECUTE permissions on these definer RPC functions:
1. admin_search_patients
2. create_prescription
3. create_prescription_attachment
4. ensure_patient_reminder_tasks
5. ensure_patient_tasks
6. record_task_completion
7. register_notification_device
8. remove_notification_device

Severity: release security REVIEW REQUIRED (P1), not a finding of confirmed unauthorized access.
Why it matters: a definer function may operate with privileged rights; being callable by authenticated users can be intentional if it performs robust ownership/role checks inside.
Required evidence: review each current deployed function body and GRANT, compare with repository migration, verify explicit auth/role/patient ownership checks and idempotency; negative tests with patient A vs B, guest/anon, and authorized admin; approved exclusions if secure.
Never revoke permissions blindly—doing so could disable core patient completion or notification enrollment flows.
Advisor remediation: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

### WARN: Leaked password protection disabled

One advisor warning states this Supabase Auth option is disabled.
Required: identify the real authentication path for patient passwords vs admin Auth, assess applicability, impact, policy and auth UX before changing configuration. Security owner sign-off needed.
Remediation: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

### INFO: 2 RLS-enabled tables with no policies

Tables: public.ai_generation_requests and public.ai_provider_slot_health.
This may intentionally deny direct anon/authenticated API access while server-only operations handle these tables. Verify service-role access, exposed API grants and legitimate app reads; do not add permissive RLS policies solely to silence lint.
Remediation: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

### Baseline

All 25 PUBLIC base tables have RLS enabled. That does NOT prove their policies or SECURITY DEFINER RPCs are safe. RLS isolation and definer review remain release gates.

## Performance Advisor snapshot

- INFO: 4 unindexed foreign-key findings (one in ai_generation_requests, three involving content collection owner relations).
- INFO: 39 unused indexes reported. The database is recently created and usage counters may have limited observation time. DO NOT drop indexes because of this warning alone.
- Action: query plans and expected production workload analysis, identify critical resource/search/index needs, and only then make additive performance changes.
- Remediation: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys and https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index

## Triage actions and ownership

- [ ] DB/security owner review current deployed function definitions, grants and RLS policies with authorized test roles.
- [ ] Test all 8 authenticated definer RPCs against unauthorized patient/guest/admin cases (isolated staging with dummy data; do not query PHI).
- [ ] Determine whether the leaked-password warning applies to the current patient/admin auth architecture.
- [ ] Capture exact advisor snapshot/remediation and accepted-risk rationale.
- [ ] Benchmark required index patterns for server-side resource filtering and new notification inbox.
- [ ] Re-run advisors after authorized code/schema change and record newly introduced warnings.
- [ ] Security owner sign-off before G6. No production change has been made.

Relationship to G0: advisory snapshot captured; *security review and authorized sign-off remain open*. Store evidence outside the repository if screenshots/logs might contain identifiers.
