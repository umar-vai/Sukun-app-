# Production Environment — Sukun Life App

This file is mandatory operational context for Codex and all coding agents working in this repository.

## Production Supabase project

- Project name: `Sukun Mobile App`
- Project ref: `vydfafumxptanpkmtrpr`
- Production URL: `https://vydfafumxptanpkmtrpr.supabase.co`
- Environment: Production

Treat this project as the current production backend for the standalone Sukun Life mobile app.

## Current deployed production state

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
