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
`20261120090000`, `20261120100000`, `20261120110000`, then record it there. Deploy the Edge
Function after the migrations. Roll out to staging and run the fixtures first.

## Rollback

1. Stop the CRM (remove its key from `CRM_INTEGRATION_KEYS`) and disable `crm-integration`.
2. `drop trigger task_completions_enqueue_integration on public.task_completions;`
   `drop function public.integration_*;` then drop tables `integration_outbox`, `integration_inbox`.
3. Family layer: restore the previous definitions of the five patient RPCs and the seven
   policies and four helper functions from their earlier migrations (the new migration only
   rewrites them), then `drop table public.family_members, public.family_accounts cascade;`
   and drop `private.accessible_patient_ids`, `can_access_patient`, `resolve_acting_patient`.
4. Plans created from CRM events stay valid; they are normal care plans.
