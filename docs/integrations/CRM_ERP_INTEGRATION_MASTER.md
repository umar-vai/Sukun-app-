# CRM/ERP integration: master document (SukunLife side)

Date: 2026-11-20. Status: backend, contracts and WhatsApp activation logic implemented
and tested locally; the Flutter UI is being built in a separate session
(`claude/family-flutter-ui`); live CRM and live WhatsApp verification are NOT done (see
section 9). Nothing here has been applied to Production.

## 1. Owner decisions this implements

Separate databases; CRM stays the place where raqis write prescriptions;
no permanent password leaves the CRM; one login per family with many patient
profiles; the same login on many phones with a per-device profile; family
members may see each other's patient-visible progress; official templates are
mastered in SukunLife and mirrored to the CRM; CRM finalised prescriptions flow
in, app progress flows back. The two databases are never merged and the CRM
never gets table access: only the signed API below.

## 2. Audit findings (Phase 0, from the real schema and code)

| Area | Finding | Consequence |
| --- | --- | --- |
| Patient identity | `patients.user_id` is unique, 1 patient = 1 auth user. `private.current_patient_id()` is the single choke point used by 7 RLS policies and 4 helper functions, and 5 patient RPCs look the patient up with `p.user_id = auth.uid()`. | Family support is an additive authorization layer, not a data merge. |
| CRM ids | `patient_external_refs (source_system, external_id)` already exists, unique, Super Admin RLS. | Reused for `crm_patient` and `crm_customer`. No new id table. |
| Care plans | `care_plans` versioned, one active per patient (partial unique index); publishing flips the old plan to `inactive`, and an existing trigger cancels its future pending tasks and scheduled reminders. | A CRM revision is simply a new plan version. History is kept by existing design. |
| Prescriptions | `prescriptions` has `source_type='imported'` and `source_external_id`; `prescription_versions` keeps versions. | CRM prescription id maps to `source_external_id`; CRM version maps to `prescription_versions.version`. |
| Tasks | `record_task_completion` is idempotent on `client_event_id`; statuses `pending, completed, snoozed, skipped, missed, cancelled`. | Progress states are reused unchanged. |
| Templates | `care_templates` holds the 51 official templates (admin editable, audited). Placeholders `{বার} {দিন} {মিনিট}`. | Exported as is; placeholders become declared parameters. No content edited. |
| Auth | Patients sign in with a patient code and password through `patient-sign-in`; temporary passwords are set by an admin and `profiles.requires_credential_change` forces a change. No SMS provider is configured. | One-time activation needs a provider decision (section 9). |
| Notifications | `notification_devices` already carries `installation_id` and `patient_id` per device. | Per-device profile selection needs no new table. |
| Roles | `private.is_care_staff()` = super admin or raqi. | Integration actor is a dedicated staff service user. |
| Gaps found | Personal routines and 40-day challenge are keyed by auth user, not by patient, so a shared login shares them across profiles. | Decision needed, flagged in section 9. Not changed. |
| Tooling | No Flutter SDK, Supabase CLI or Docker in this session. | SQL verified on plain PostgreSQL 16 with a Supabase stand-in (`scripts/local_db`); Edge code verified with Deno fmt/check/test. Flutter is unverified. |

## 3. What was built

| Piece | Where | Verified |
| --- | --- | --- |
| Family tables, authorization primitives, in-place RLS/RPC patches, staff family RPCs | `supabase/migrations/20261120090000_family_accounts.sql` | 47 SQL checks; no change in the pass/fail result of any existing test |
| Template catalog export (versioned, paged, incremental) | `.../20261120100000_integration_template_catalog.sql` | SQL checks, JSON Schema, sample file |
| Inbox/outbox, CRM id linking, prescription import, progress RPCs | `.../20261120110000_crm_integration_core.sql` | 61 SQL checks |
| HMAC auth + gateway Edge Function | `supabase/functions/crm-integration/` | 9 unit tests, `deno fmt/check` clean; not deployed |
| JSON Schemas, fixtures, validator | `docs/integrations/schemas`, `fixtures`, `scripts/integrations` | 20 contract checks; fixtures also replayed through the real SQL import |
| One-time WhatsApp activation: tables and RPCs, `account-activate` public function, `POST /patients/provision` | `.../20261120120000_account_activation.sql`, `supabase/functions/account-activate/`, `crm-integration/provision.ts` | 28 SQL checks, 17 + 2 function unit tests (token, phone, WhatsApp request shape, passwords); delivery itself untested |
| Local test harness | `scripts/local_db/` | used for everything above |

## 4. Architecture

```
CRM backend --HMAC-signed HTTPS--> Edge Function crm-integration
   GET  /templates        -> integration_export_template_catalog   (read only)
   POST /patients/link    -> integration_link_patient              (maps ids, family)
   POST /prescriptions    -> integration_apply_prescription_event  (idempotent, versioned)
   GET  /progress         -> integration_patient_progress          (single adherence rule)
Flutter app --existing RLS/RPC--> record_task_completion
   AFTER INSERT trigger -> integration_outbox (only CRM-linked patients)
Scheduler --Bearer--> POST /outbox/dispatch --signed--> CRM webhook (retry, backoff, dead letter)
```

All `integration_*` functions are `SECURITY DEFINER`, executable by
`service_role` only; the inbox and outbox tables have RLS on and no policy.

## 5. Failure scenarios

| # | Scenario | Behaviour | Recovery / audit |
| --- | --- | --- | --- |
| 1 | CRM sends the same event twice | Stored result returned with `replayed: true`; no second plan | inbox row |
| 2 | Older version arrives late | `stale`, HTTP 409, current version returned, nothing overwritten | inbox row `stale` |
| 3 | CRM request times out | CRM retries the same `event_id`; safe (case 1) | inbox |
| 4 | Sukun applied, CRM missed the answer | Same as 3 | inbox shows `applied` |
| 5 | CRM offline when progress changes | Completion succeeds; event waits in outbox; retries with exponential backoff (1 min up to 6 h), dead letter after 12 tries | `integration_outbox.status` |
| 6 | App offline | Existing offline queue; completions keyed by `client_event_id` | existing |
| 7 | Family member switches profile | Device selection is per device; server validates every call | `notification_devices` |
| 8 | Two phones complete at once | Row lock on the task; second gets a clear error; replay is idempotent | `task_completions` |
| 9 | CRM id conflict | `identity_conflict` (409) or `family_mismatch`; never merged | `integration_inbox` rejected row; reconcile by hand |
| 10 | Template edited meanwhile | Plan actions copy title and instruction at import, so history is a snapshot; an old `template_revision` is accepted with a warning | result `warnings` |
| 11 | Prescription cancelled | Active plan becomes inactive, future tasks and reminders cancelled, prescription archived, completions kept | audit `integration.prescription_cancelled` |
| 12 | Phone number changed | Identity never uses the phone; ids only | n/a |
| 13 | Activation link expires or is reused | Link lives 24 h, single use; any bad, used, revoked or expired token gets the same generic error; resend revokes the old link | `account_activations`, audit `integration.activation_*` |
| 14 | Unauthorised CRM request | 401 generic answer, no detail | log line without payload |
| 15 | Family user reads another family | RLS returns nothing; forged profile id gives 42501 | pgTAP |

## 6. Security review

- Secrets only in Edge Function secrets: `CRM_INTEGRATION_KEYS` (JSON key id to secret, at least 32 characters, two keys active during rotation), `CRM_INTEGRATION_ACTOR_USER_ID`, `CRM_DISPATCH_SECRET`, `CRM_PROGRESS_WEBHOOK_*`. The service-role key never leaves the function.
- Signature binds method, path, query, body hash, timestamp (±5 min) and request id; constant-time compare; one generic 401.
- Replay: a replayed POST can only repeat an idempotent event; timestamp window limits reuse.
- No permanent password and no staff-only note exists in any contract (the schema rejects `staff_only_note` and password fields).
- Progress events carry ids and states only: no name, phone or prescription text.
- Not built: rate limiting on `crm-integration` (relies on the HMAC and platform limits). Add a database counter before go-live if the CRM host is internet-exposed beyond the planned caller.

## 7. Deployment checklist (none of this has been done)

1. Create a dedicated staff service auth user (raqi role) and store its id as `CRM_INTEGRATION_ACTOR_USER_ID`.
2. Generate two 48 byte secrets, set `CRM_INTEGRATION_KEYS`, give the matching secret to the CRM team over a secure channel.
3. Staging first: apply the three migrations, deploy `crm-integration`, run the fixtures, confirm the signed path (see handoff) against the deployed runtime.
4. Approval for Production migration (rule in `docs/PRODUCTION_ENVIRONMENT.md`): dry run in a rolled-back transaction, then apply, then record it in that file.
5. Set `CRM_PROGRESS_WEBHOOK_*` once the CRM exposes its endpoint; schedule `POST /outbox/dispatch` every 1 to 5 minutes.

## 8. Rollback

See `TESTING_AND_ROLLOUT.md`. The migrations alter no row of any existing table.
Policies and five RPCs are rewritten in place; the previous definitions are in
the earlier migrations.

## 9. Not done, and what is needed

| Item | Why | Needed from the owner |
| --- | --- | --- |
| WhatsApp provider setup | Delivery needs a WhatsApp Business account, an approved message template with one body variable (the link), and the secrets `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACTIVATION_TEMPLATE`, `APP_ACTIVATION_BASE_URL`, plus `graph.facebook.com` allowed by the environment network policy. Until set, provisioning reports `delivery: not_configured` and nothing is faked | Business account and template approval |
| App activation screen | The web or app page at `<APP_ACTIVATION_BASE_URL>/activate#token=...` that posts `{token,new_password}` to `account-activate` | Part of the Flutter session |
| Flutter family UI (phase 3) | Running in a separate session on branch `claude/family-flutter-ui` (owner approved) | Review its draft PR |
| Personal routines and 40-day challenge under a shared login | They belong to the auth user, so all family profiles would share them | Decide: shared per login, or per profile |
| Push "care plan updated" after an import | The existing send-notification path is called from the admin app | Decide whether the gateway may call it |
| Live CRM verification | No CRM access | CRM team test run |
