# Testing and rollout

## Run the checks locally (no Docker, no Supabase CLI)

```bash
# PostgreSQL 16 server binaries are enough
export PGHOST=/var/tmp/pgsukun PGPORT=54329 PGUSER=postgres
scripts/local_db/reset.sh sk              # stand-in Supabase schema + every migration
scripts/local_db/run_tests.sh sk          # all SQL tests (pgTAP syntax, small shim)
cd scripts/integrations && npm i && npm run validate     # JSON contracts + fixtures
deno test --allow-import --config supabase/functions/crm-integration/deno.json supabase/functions/crm-integration
```

The shim implements only the pgTAP functions the repository uses; 14 older tests that need
real pgTAP features fail identically before and after these changes (baseline compared).
Real `supabase test db` in CI is the authority.

## Production rollout

Follow `docs/PRODUCTION_ENVIRONMENT.md`: rolled-back dry run, owner approval, apply in order
`20261120090000`, `20261120100000`, `20261120110000`, `20261120120000`, `20261120130000`, then record it there. Deploy the Edge
Function after the migrations. Roll out to staging and run the fixtures first. All five migrations are compatible with the currently deployed app.

## Rollback

1. Stop the CRM (remove its key from `CRM_INTEGRATION_KEYS`) and disable `crm-integration`.
2. `drop trigger task_completions_enqueue_integration on public.task_completions;`
   `drop function public.integration_*;` then drop tables `integration_outbox`, `integration_inbox`.
3. Family layer: restore the previous definitions of the five patient RPCs and the seven
   policies and four helper functions from their earlier migrations (the new migration only
   rewrites them), then `drop table public.family_members, public.family_accounts cascade;`
   and drop `private.accessible_patient_ids`, `can_access_patient`, `resolve_acting_patient`.
4. Plans created from CRM events stay valid; they are normal care plans.

## Production dry run script

The ready file is `docs/integrations/production_dry_run.sql` (regenerate it with
`scripts/integrations/build_dry_run.sh > docs/integrations/production_dry_run.sql` if a migration changes).
Paste the whole file into the Supabase SQL editor of the target project and run it. It applies the five
migrations, reads a few counts, then stops with a deliberate error that aborts the transaction, so nothing
is ever kept. The error text holds the report; a different error names what must be fixed first.
Verified on a local database built from every earlier migration.

## Staging dry run (2026-11-20, project `qacklgqvxvjjzsimjoip`)

Run through the Supabase Management API SQL endpoint inside `BEGIN ... ROLLBACK`; afterwards the
staging schema was confirmed unchanged (47 migrations, no `care_templates`, no `family_accounts`).

- Staging is behind the repository. Of the 32 repository migrations not recorded there, 27 applied
  cleanly in order, including all five new ones (`20261120090000` to `20261120130000`).
- 5 older repository migrations could not be replayed because staging already holds the same
  objects from its own `_staging` variants (`20261017113000`, `20261018012147`, `20261018022000`,
  `20261018114921`, `20261025081703`). This is staging drift, not a defect in the new migrations;
  the new ones ran on top of staging's real objects.
- Checks inside the transaction: the in-place patch counts the migration asserts (7 policies, 4 read
  helpers, 3 RPCs) held; 51 templates; `my_family_profiles()` returned exactly one profile for each
  of the 2 patient accounts; no orphaned challenge rows.
- Not covered: staging holds no routine or challenge rows, so the backfill ran on empty tables
  here (it is covered by the local legacy-data check); Edge Functions were not deployed; Auth
  user creation in `provision.ts` was not exercised.
- Production must be checked the same way before applying: the 5 drifted migrations suggest
  environments differ, 

## Production apply file

`docs/integrations/production_apply.sql` (built by `scripts/integrations/build_apply.sh`) applies the five
migrations in ONE transaction: lock timeout, pre-flight checks, the migrations, post-checks that abort and roll
everything back if a routine has no profile or a patient does not see exactly one profile, then COMMIT and a
record in `supabase_migrations.schema_migrations`. A second run refuses (family_accounts already exists).
Verified locally on a database built from the earlier migrations: applied once, the new and the related existing
SQL tests passed afterwards, and a repeat run was refused. After the owner applies it, record the result in
`docs/PRODUCTION_ENVIRONMENT.md`.
