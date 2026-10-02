# Production Environment — Sukun Life App

This file is mandatory operational context for Codex and all coding agents working in this repository.

## Production Supabase project

- Project name: `Sukun Mobile App`
- Project ref: `vydfafumxptanpkmtrpr`
- Production URL: `https://vydfafumxptanpkmtrpr.supabase.co`
- Environment: Production

Treat this project as the current production backend for the standalone Sukun Life mobile app.

## Current deployed production state

As of 2026-10-02:

- Repository database schema/migrations have been deployed to the production Supabase project.
- 24 public tables are present.
- RLS is enabled across all 24 public tables.
- Current app security/RLS policies are deployed.
- Phase 5 CMS/resource taxonomy/collection database changes are deployed.
- The following Edge Functions are deployed and ACTIVE:
  - `admin-create-patient`
  - `patient-sign-in`
  - `patient-change-password`
  - `prescription-to-actions`
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
