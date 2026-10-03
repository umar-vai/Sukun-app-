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

The repository and Supabase connector do not expose secret values, so live
FCM/APNs delivery still requires an authorized release operator to confirm the
Firebase service-account secret, Android app registration, iOS app
registration, and APNs key/certificate in the Firebase console. When those are
absent, plan publication remains successful and the Edge Function returns a
neutral `not_configured` result without exposing infrastructure details.

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

## Known security-linter context

The server-only AI tables use RLS with no client-readable policies by design and have client grants revoked. Some intentional authenticated RPCs use `SECURITY DEFINER` while performing their own authorization checks. Treat Supabase security-advisor warnings as items to review, not as permission to weaken or remove authorization logic.

## Next production verification

The next hosted AI milestone is to verify the real `prescription-to-actions` flow against this production project while preserving human review, neutral fallback behavior, safe logging, and no raw Gemini/quota/key errors in Flutter.
