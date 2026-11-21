#!/usr/bin/env bash
# Prints the REAL apply script for the five CRM/family migrations: one
# transaction, fail fast on locks, pre-flight and post-checks that abort
# (everything rolls back) if anything looks wrong, then COMMIT and record the
# migrations in supabase_migrations.schema_migrations when that table exists.
# Run ONLY after the dry run report was reviewed and approval was given.
#
#   scripts/integrations/build_apply.sh > docs/integrations/production_apply.sql
set -euo pipefail
cd "$(dirname "$0")/../.."
FILES="20261120090000_family_accounts 20261120100000_integration_template_catalog 20261120110000_crm_integration_core 20261120120000_patient_provisioning_credentials 20261120130000_profile_scoped_routines"
cat <<'SQL'
-- REAL APPLY. Run once, in the Production SQL editor, after taking a backup.
-- Any error aborts the whole transaction and nothing is kept.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '120s';

do $$
begin
  if to_regclass('public.care_templates') is null
     or to_regclass('public.staff_members') is null
     or to_regclass('public.personal_routines') is null then
    raise exception 'PRE-FLIGHT FAILED: the database is missing earlier migrations.';
  end if;
  if to_regclass('public.family_accounts') is not null then
    raise exception 'PRE-FLIGHT FAILED: family_accounts already exists (already applied?).';
  end if;
end $$;
SQL
for f in $FILES; do
  echo "-- ==== $f"
  cat "supabase/migrations/$f.sql"
done
cat <<'SQL'

-- Post-checks: abort (roll back) if anything is off.
do $$
declare u record; n int; bad int := 0; unassigned int;
begin
  select count(*) into unassigned from public.personal_routines r
  where r.patient_id is null
    and exists (select 1 from public.patients p where p.user_id = r.owner_user_id);
  if unassigned <> 0 then
    raise exception 'POST-CHECK FAILED: % routines without a profile', unassigned;
  end if;
  for u in select user_id from public.patients where user_id is not null and status = 'active' loop
    perform set_config('request.jwt.claim.sub', u.user_id::text, true);
    select count(*) into n from public.my_family_profiles();
    if n <> 1 then bad := bad + 1; end if;
  end loop;
  if bad <> 0 then
    raise exception 'POST-CHECK FAILED: % patient accounts without exactly one profile', bad;
  end if;
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

-- Record the migrations when the Supabase migration table exists.
do $$
begin
  if to_regclass('supabase_migrations.schema_migrations') is not null then
    insert into supabase_migrations.schema_migrations (version, name)
    select v, n from (values
      ('20261120090000', 'family_accounts_20261120'),
      ('20261120100000', 'integration_template_catalog_20261120'),
      ('20261120110000', 'crm_integration_core_20261120'),
      ('20261120120000', 'patient_provisioning_credentials_20261120'),
      ('20261120130000', 'profile_scoped_routines_20261120')
    ) t(v, n)
    on conflict (version) do nothing;
  end if;
end $$;

commit;
select 'APPLIED OK' as result;
SQL
