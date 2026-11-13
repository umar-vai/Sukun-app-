# Production Environment — Sukun Life App

This file is mandatory operational context for Codex and all coding agents working in this repository.

## Production Supabase project

- Project name: `Sukun Mobile App`
- Project ref: `vydfafumxptanpkmtrpr`
- Production URL: `https://vydfafumxptanpkmtrpr.supabase.co`
- Environment: Production

Treat this project as the current production backend for the standalone Sukun Life mobile app.

## Current deployed production state

### 2026-11-13: one-step resource publishing (Production)

- Owner decision: adding or editing a resource publishes it in one step; no
  draft, review or separate verification, and no required source or
  rights/licensing fields. Qur'an/Hadith are verified by the saving Super
  Admin. See `docs/ISLAMIC_RESOURCES_ARCHITECTURE.md` section 12.
- Applied `supabase/migrations/20261113150000_one_step_resource_publishing.sql`
  as remote version `20261113092444` (`one_step_resource_publishing_20261113`):
  `save_content_item` accepts `published` and edits published rows in place;
  `transition_content_item` `publish` works from any unpublished state; the
  canonical publication constraints and trigger keep only the AI-source ban
  and the Qur'an Arabic / Hadith reference checks;
  `content_items_published_media_rights` dropped.
- Verified before applying in a rolled-back transaction on Production: new
  Qur'an and Hadith published and verified in one call, a published Qur'an
  edited in place, link-only audio published without a rights note, the
  waiting Qur'an review row published; an AI source, a Hadith without its
  reference and a non-admin were refused. After applying: grants unchanged
  (`authenticated` only), no dry-run rows left. Backward compatible with the
  deployed client, which still uses draft, submit and publish.

### 2026-11-13: raqi staff role (Production)

- Applied `20261113115900_app_role_raqi.sql` as remote version
  `20261112223902` and `20261113120000_raqi_staff_role.sql` as
  `20261112224031`. See `docs/RAQI_STAFF_ROLE.md`.
- Verified before applying in a rolled-back transaction on Production (after
  the enum value was committed): a Gmail added by the Super Admin became a
  raqi on first sign-in, listed the 4 patients and read the 51 templates,
  and got `42501` for saving a template and adding staff; a member got
  `42501`. After applying: 18 policies use `private.is_care_staff()`,
  `staff_members` has RLS on and 0 rows, `anon` cannot run the new RPCs.
- Deployed `send-notification` **v5** (was v4, identical to the repository):
  only the role check changed to Super Admin or raqi; `verify_jwt` stays off
  as before (the function checks the bearer token itself).

### 2026-11-13: ghusl calendar and detox days (Production)

- Applied `supabase/migrations/20261113090000_ghusl_calendar_detox_days.sql` as
  remote version `20261112223055` (`ghusl_calendar_detox_days_20261113`).
  Adds the care plan `dates` frequency (validated by trigger
  `plan_actions_validate_frequency`), patches the live `save_plan_action` and
  `admin_import_user_routine_reminders` definitions in place (only the
  allowed-type list and two inserted columns change), rewrites
  `ensure_patient_tasks` / `ensure_patient_reminder_tasks` from their deployed
  bodies plus dates and the detox rule (`private.detox_day_blocks`), and adds
  nullable `personal_routine_actions.active_dates` / `ghusl_kind`.
- Verified before applying in rolled-back transactions on Production: both
  in-place patches matched; on a test detox day a daily action produced 0
  tasks and the detox action 1 (including a task generated before the detox
  was added); an invalid date was refused. After applying: patches present,
  0 existing rows changed, `anon` still cannot run the generators,
  `authenticated` cannot run the private helper.

### 2026-11-12: admin Patients list shows only people under care (Production)

- Applied `supabase/migrations/20261112230000_admin_care_recipients.sql` as
  remote version `20261112221701` (`admin_care_recipients_20261112`): one
  read-only SECURITY DEFINER function `admin_list_care_recipients(query,
  limit, offset)`, Super Admin checked in the database. Without a search it
  returns only patient accounts and members an admin set a routine for; a
  search (name, email, phone, patient number) reaches any non-admin account.
  No table, RLS or data change.
- Verified before applying in a rolled-back transaction on Production: 4
  people listed (the 4 patients), a search reached 16 accounts, a member got
  `42501`; afterwards the function was confirmed absent. After applying:
  `anon` cannot execute, `authenticated` can. pgTAP:
  `supabase/tests/admin_care_recipients_test.sql`.

### 2026-11-12: admin-set routines listed first (Production)

- Applied `supabase/migrations/20261112090000_my_admin_assigned_routines.sql`
  as remote version `20261112211036` (`my_admin_assigned_routines_20261112`):
  one read-only SECURITY DEFINER function `my_admin_assigned_routine_ids()`
  that returns only the caller's own routine ids an admin created (from the
  existing `personal_routine.delegated_*` audit actions). No table, RLS or
  data changes; no audit detail is exposed.
- Verified before applying: the function did not exist, the columns it reads
  exist, and both admin routine functions log the matched actions. Dry run in
  a rolled-back transaction: a user saw only their own admin-set routine (not
  their self-made one, not another user's); `anon` cannot execute. After
  applying: function present, `anon` cannot execute, `authenticated` can, no
  dry-run rows left. Production had no admin-set routines yet, so the list is
  empty until an admin imports one. The client falls back to an empty list if
  the call fails.

### 2026-11-10: default reminder name per care template (Production)

- Applied `supabase/migrations/20261110150000_care_template_notification_title.sql`
  as remote version `20261110035443` (`care_template_notification_title_20261110`):
  adds nullable `care_templates.notification_title` (1 to 120 letters) and
  teaches `admin_save_care_template` to save it (trimmed, blank = null,
  still Super Admin only and audited).
- Verified before applying inside a rolled-back transaction on Production:
  name saved trimmed, left out clears it, 121 letters refused; afterwards the
  column and the fixture user were confirmed absent. After applying: 51
  templates, none named yet, `anon` still cannot run the save function.
  Additive; older clients simply do not send the field.

### 2026-11-10: admin-editable care templates (Production)

- Applied `supabase/migrations/20261110120000_care_templates_admin_editable.sql`
  as remote version `20261110031110`
  (`care_templates_admin_editable_20261110`): new table `care_templates`
  (RLS on, Super Admin read only, no direct writes) seeded with the 51
  official templates, and `admin_save_care_template` (Super Admin checked in
  the database, audited before/after).
- Verified before applying inside a rolled-back transaction (16 checks), and
  after: 51 rows, RLS on, `anon` cannot read the table or run the function.
  Additive; the deployed client does not use it until the next web deploy.

### 2026-11-10: reminder names and live reminder switches (Production)

- Applied `supabase/migrations/20261110090000_reminder_names_and_live_toggles.sql`
  as remote version `20261109231505`
  (`reminder_names_and_live_toggles_20261110`).
- Adds nullable `plan_actions.notification_title` (1 to 120 chars), copies it
  into new plan versions, adds `set_draft_action_notification_title`,
  `admin_set_plan_action_reminder` and `admin_set_user_routine_action_reminder`
  (audited, Super Admin checked in the database), lets routine import take an
  optional `notification_title`, and adds `id`/`notification_title` to the
  routine overview. The published-action guard trigger now allows only the
  `reminder_enabled` flag of an ACTIVE plan to change, and only inside the
  audited switch function.
- Owner decision: `sukun-ruqyahbd-qital-tadmir`, `sukun-ruqyahbd-khuruj` and
  `sukun-ruqyahbd-shifa` audios changed from `staff_only` to `assigned_only`.
- Verified before applying inside rolled-back transactions on Production
  (15 pgTAP checks passed, nothing kept). Verified after: the column exists,
  `anon` cannot execute the three new functions, `authenticated` can, and the
  three audios are `assigned_only`. The deployed client keeps working: all
  changes are backward compatible. Local `supabase test db` could not run in
  the session (container image pulls were rate limited).

### 2026-11-09: bulk template import and routine overview (Production)

- Applied two additive SECURITY DEFINER functions (no table, grant or RLS
  policy changes on existing tables):
  - `admin_import_user_routine_reminders` from
    `supabase/migrations/20261109090000_admin_bulk_import_user_routine_reminders.sql`
    as remote version `20261109173732`
    (`admin_bulk_import_user_routine_reminders_20261109`).
  - `admin_get_user_routine_overview` from
    `supabase/migrations/20261109120000_admin_user_routine_overview.sql`
    as remote version `20261109173739`
    (`admin_user_routine_overview_20261109`).
- Verified before applying: the routine tables and columns they use exist and
  neither function existed. Verified after: `anon` cannot execute either
  function, `authenticated` can (Super Admin is checked inside), and both are
  audited. Local `supabase test db` passed all 39 files including the two new
  pgTAP files. Security advisors list both under the same generic
  "authenticated SECURITY DEFINER" warning as the existing admin RPCs.
- Owner decision: an admin bulk import creates an ACTIVE user routine with
  fixed reminder times (no owner opt-in). See `docs/BULK_TEMPLATE_IMPORT.md`.
- The Flutter client using these must be deployed after this migration.

### 2026-10-24: approved public MP3 download gateway (Production)

- Verified Production source project `vydfafumxptanpkmtrpr` had the
  required `content_items` schema and 18 published/public MP3s.
- Applied the existing additive budget migration from
  `supabase/migrations/20261022170000_approved_audio_gateway_daily_budget.sql`
  as remote version `20261023184727`, name
  `approved_audio_gateway_daily_budget_20261024`. It creates only the
  unexposed `media_gateway_private` schema/table and a `service_role`-only
  reservation RPC; no clinical records were changed.
- Verified `anon` and `authenticated` cannot access the private quota
  schema/table or execute `reserve_approved_audio_download`; `service_role`
  can execute the reservation RPC.
- Deployed **Production** `approved-audio-download` Edge Function **v1**
  from the committed `supabase/functions/approved-audio-download` source.
  Its owner-attested publisher URLs are pinned; requests require exact
  `https://app.sukunlife.com` origin, GoTrue-verified sign-in, a
  published/public CMS audio row, bounded MP3 size, and atomic quotas of
  **3 files / 200 MiB per member per UTC day, 2 GiB per project per UTC day**.
- Current Flutter Pages app serves Production backend, not Staging.
  Chromium Guest route tests and credential-free CORS/denial probes are
  the safe live checks. **Successful authorized download, real browser
  offline playback, and rights/operator review remain pending** and must not
  be represented as passed without evidence.
- Existing Supabase security advisors still report warnings unrelated to
  the new private media quota (authenticated security-definer functions and
  leaked password protection); review separately, do not disable existing
  Patient/Admin flows merely to clear a generic linter warning.


### 2026-10-18 universal public notices

- Applied additive `universal_announcements` and
  `universal_announcement_dispatch_rpc` migrations to the existing Production
  project (remote versions `20261018065326` and `20261018065335`). They add a
  public notice inbox with draft/published/archived lifecycle, a dedicated
  non-clinical public image bucket, admin audit entries, and a private dispatch
  outbox. Existing patient and notification records were not changed.
- Verified RLS on both new tables. Guests can select only published,
  unexpired notices; guests cannot insert; ordinary authenticated users cannot
  delete notices or claim dispatch jobs. The new tables and queue had zero
  records as deployed.
- Deployed protected `dispatch-universal-announcements` Edge Function v1.
  A request without its private cron token returns HTTP 401. Its server-side
  release flag and separate GitHub workflow gate remain closed; no universal
  push has been sent. Native phone opt-in, Firebase topic receipt and tap
  behavior require release validation before either gate is enabled.

### 2026-10-18 public Quran links in clinical plans

- Applied additive migration `public_resource_action_links` to Production
  (remote version `20261018013712`; repository file
  `20261018012147_public_resource_action_links.sql`) after CI's disposable
  migration rebuild and RLS suite passed.
- It adds `plan_action_quran_surahs`, a draft-only audited replacement RPC,
  and copying of chapter references into a new draft care-plan version.
  Existing patient records and published care-plan rows were not edited.
- Verified RLS is enabled, guests have no table read permission or RPC
  execute permission, and the new relation contains zero rows before client
  deployment. Production security advisors reported no finding on the new
  table. The Flutter Pages client must be deployed after this migration.

### 2026-10-17 ordered clinical resource links

- Applied additive migration `clinical_resource_order_and_note` to Production
  (remote migration version `20261017174248`; repository file
  `20261017113000_clinical_resource_order_and_note.sql`). It adds a defaulted
  `sort_order` to `plan_action_resources` and updates the existing draft-only
  resource replacement RPC to retain the selected resource order and usage note.
- Verified the new column, enabled RLS, and that `anon` still cannot execute
  the RPC. Existing published action links and patient records were not edited.
- PR #128 contains the matching Flutter code and synthetic rollback-only
  database tests. The Pages client must be deployed after this migration.

### 2026-10-08 prescription AI diagnostic update

- Confirmed existing migrations `20261007114242` (document extraction) and
  `20261007114314` (attachment FK indexes). Neither was reapplied.
- Confirmed the private `prescription-private` bucket and Admin-only attachment/
  Storage policies. No database, Storage, credential or RLS changes made.
- Inspected document function v14 and typed function v10. Deployed
  `prescription-document-to-actions` **v15** with content-free diagnostics only.
  Typed function remains v10; model and parsing behavior are unchanged.
- Transcription succeeds; action generation remains unverified. Awaiting an
  authenticated retry to identify the exact response/validation failure.
  Phase 4B is not complete. See
  [investigation evidence](PRESCRIPTION_AI_DIAGNOSTIC_2026_10_08.md).

As of 2026-10-03:

- Repository database schema/migrations have been deployed to the production Supabase project.
- 24 public tables are present.
- RLS is enabled across all 24 public tables.
- Current app security/RLS policies are deployed.
- Phase 5 CMS/resource taxonomy/collection database changes are deployed.
- The Phase 6 published-media rights/licensing constraint is deployed and
  validated; published external media cannot omit `rights_note`.
- The Phase 7 notification delivery migration is deployed. Production has
  authenticated patient device registration/removal, approved exact-time
  reminder generation, inactive-plan cancellation, and notification event
  idempotency support. RLS remains enabled on notification tables.
- Android reminder delivery requests the user-controlled `Alarms & reminders`
  access for precise timing and safely falls back to inexact delivery when it
  is denied. Plan-update FCM messages use the dedicated high-importance
  `care_updates` notification channel.
- The following Edge Functions are deployed and ACTIVE:
  - `admin-create-patient`
  - `patient-sign-in`
  - `patient-change-password`
  - `prescription-to-actions`
  - `send-notification`
- A Super Admin Auth user exists and has the database role `super_admin`.

## Gemini production secrets

The production Supabase project already contains these server-side secret slots:

```text
GEMINI_API_KEY_1
GEMINI_API_KEY_2
GEMINI_API_KEY_3
GEMINI_API_KEY_4
```

The secret values must never be requested, exposed, printed, committed, copied into Flutter, or copied into repository files.

Quota-scope metadata may also be configured server-side when verified:

```text
GEMINI_QUOTA_SCOPE_1
GEMINI_QUOTA_SCOPE_2
GEMINI_QUOTA_SCOPE_3
GEMINI_QUOTA_SCOPE_4
```

Do not assume four keys imply four independent quotas. Respect the provider quota/project scope and the failover rules in `docs/AI_FAILOVER_ARCHITECTURE.md`.

## Firebase production configuration

The `send-notification` Edge Function is deployed and ACTIVE. Live FCM
delivery additionally requires these server-side Supabase secrets:

```text
FIREBASE_SERVICE_ACCOUNT_JSON
FIREBASE_PROJECT_ID
```

The Flutter release must receive its public Android and iOS Firebase client
identifiers through the runtime configuration described in
`app/config/production.example.json`. These client identifiers are not sender
credentials. The Firebase service-account JSON is server-only and must never
be requested in chat, committed, logged, or placed in Flutter.

The repository and Supabase connector do not expose secret values. An
authorized release operator has confirmed the server-side Firebase credential
and Android app registration through successful live delivery. iOS app
registration and APNs key/certificate verification remain separate release
requirements. When sender configuration is absent, plan publication remains
successful and the Edge Function returns a neutral `not_configured` result
without exposing infrastructure details.

Production `send-notification` version 3 was deployed on 2026-10-03 with the
dedicated Android `care_updates` channel. Live testing on 2026-10-03 confirmed
that a locked physical Android patient device received the visible plan-update
FCM notification and processed the background plan sync. The same device also
received an exact `RTC_WAKEUP` local reminder for an approved action after a
patient-selected 15-minute Snooze; Android reported a zero-width alarm window
authorized by the user-controlled exact-alarm permission. No sender credential
was exposed to Flutter, logs, documentation, or source control.

## Flutter production connection rules

- Flutter must connect through the existing runtime configuration system.
- Use only the Supabase publishable/anon client credential on the client where appropriate.
- Never put the Supabase service-role key in Flutter, source control, logs, screenshots, or analytics.
- Do not hardcode secret credentials into Dart files.
- Production URL must match the project above unless an explicit environment migration is approved.

## Change-control rules

Before any production database or Edge Function change:

1. Inspect the current repository migrations/functions and this production-state document.
2. Do not create a second Supabase project for this app unless explicitly instructed.
3. Do not reset, wipe, reseed destructively, or recreate the production database blindly.
4. Prefer additive, reviewable migrations for schema changes.
5. Keep RLS and server-side role verification intact.
6. Preserve the existing public Sukun Life website and existing internal dashboard; they remain out of scope.
7. Never weaken security checks just to make CI or deployment pass.
8. After production changes, update this document if the operational state materially changes.

## Patient authentication identity

Patient-facing sign-in accepts the Sukun Patient ID or the patient's phone
number plus a password. The backend resolves either identifier to a private,
confirmed email-backed Supabase Auth identity. This avoids requiring an SMS
gateway for password authentication; the private Auth email is never returned
to Flutter or shown to the patient. Existing phone-backed patient accounts are
migrated to the private email identity by `patient-sign-in` without changing
their password or patient record.

Do not enable or configure a paid SMS provider unless an explicitly approved
SMS OTP or recovery feature is added later.

Production verification on 2026-10-03 confirmed that an existing phone-backed
patient was migrated automatically and successfully signed in with the same
Patient ID and temporary password. `admin-create-patient` and
`patient-sign-in` are deployed as ACTIVE version 7.

## Known security-linter context

The server-only AI tables use RLS with no client-readable policies by design and have client grants revoked. Some intentional authenticated RPCs use `SECURITY DEFINER` while performing their own authorization checks. Treat Supabase security-advisor warnings as items to review, not as permission to weaken or remove authorization logic.

## Historical direct content publishing deployment

On 2026-10-04, the forward migration
`20261004161534_direct_content_publishing.sql` was applied to the existing
production project and recorded by Supabase as
`20261004163845_direct_content_publishing`.

That migration temporarily made the CMS workflow:

```text
Create/Edit → Save Draft or Publish Now → Published
```

During that temporary policy, an authorized Super Admin could publish every
content type directly. Unpublish returned the item to draft; archive preserved
the item and history. Legacy review/verification columns and records remained
intact for backward compatibility, but did not gate publication. Qur'an/Hadith source,
reference, edition, translation, and canonical-text constraints remain active,
published external media still requires rights metadata, and publish,
unpublish, and archive actions remain recorded in lifecycle and admin audit
history. The deployment did not rewrite existing content rows; the existing
historical Qur'an `review`/`pending` row was preserved unchanged.

On 2026-10-05, forward migration
`20261004172726_clarify_canonical_publish_validation.sql` was applied and
recorded in production as
`20261004211242_clarify_canonical_publish_validation`. It added a private,
security-invoker publication trigger that returns actionable source/rights
validation messages before the database safety constraints run. Incomplete canonical content is still preserved
as a draft/review record, RLS remains enabled, and no source metadata is
invented. Recitation-only resources may be modeled as `audio` content linked to
the Qur'an taxonomy instead of being represented as canonical Qur'an text.

## Active reviewed content publishing deployment

On 2026-10-05, forward migration
`20261005090000_restore_canonical_content_review_gate.sql` was applied and
recorded in production as
`20261004214238_restore_canonical_content_review_gate`.

The active CMS workflow is now:

```text
Choose resource type → Complete the simple form → Preview → Save Draft
→ Submit for Review → Verify Source for Qur'an/Hadith → Publish
```

The migration restored server-enforced review publication transitions without
deleting historical migrations, content, or audit events. Canonical Qur'an and
Hadith cannot publish until `verification_status = verified` with a recorded
verifier and verification time. Other resource types must be submitted for
review before publication. RLS and server-verified Super Admin authorization
remain unchanged.

One Qur'an row created during the historical direct-publish window was found in
`published` / `pending` state. The migration preserved the row and its entered
content, returned it to `review`, cleared its publication timestamp, and wrote
the `content_item_policy_returned_to_review` system-policy audit event. No
source data was invented and no content row was deleted.

On 2026-10-07, the forward correction
`20261007090000_fix_content_review_transition_enum_casts.sql` was applied and
recorded in production as
`20261007101953_fix_content_review_transition_enum_casts`. It adds explicit
PostgreSQL enum casts to the reviewed lifecycle transitions. Transactional
production smoke checks confirmed both non-canonical `draft → review` and
canonical `draft → review → verified → published → verified` behavior; every
smoke-test row and audit event was rolled back.

## Next production verification

The next hosted AI milestone is to verify the real `prescription-to-actions` flow against this production project while preserving human review, neutral fallback behavior, safe logging, and no raw Gemini/quota/key errors in Flutter.
