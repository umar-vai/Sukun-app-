#!/usr/bin/env bash
# Prints a SQL script that applies the five CRM/family migrations inside one
# transaction and ALWAYS rolls back. Paste it into the Supabase SQL editor of
# the target project (or send it through the Management API), read the result
# row, and nothing is kept. Use only on a database that already has every
# migration up to 20261113150000.
#
#   scripts/integrations/build_dry_run.sh > /tmp/dry_run.sql
set -euo pipefail
cd "$(dirname "$0")/../.."
cat <<'SQL'
-- DRY RUN: everything below is rolled back at the end.
begin;
-- Fail fast instead of queueing behind live traffic.
set local lock_timeout = '3s';
set local statement_timeout = '60s';

-- Pre-flight: the objects these migrations rewrite must look as expected.
do $$
begin
  if to_regclass('public.care_templates') is null
     or to_regclass('public.staff_members') is null
     or to_regclass('public.challenge_enrollments') is null
     or to_regclass('public.personal_routines') is null then
    raise exception 'PRE-FLIGHT FAILED: the database is missing earlier migrations.';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'challenge_enrollments_pk')
     or not exists (select 1 from pg_constraint where conname = 'challenge_day_checkins_pk')
     or not exists (select 1 from pg_constraint where conname = 'challenge_checkins_enrollment_fk') then
    raise exception 'PRE-FLIGHT FAILED: challenge constraint names differ from the repository.';
  end if;
  if to_regclass('public.family_accounts') is not null then
    raise exception 'PRE-FLIGHT FAILED: family_accounts already exists (already applied?).';
  end if;
end $$;
SQL
for f in \
  20261120090000_family_accounts \
  20261120100000_integration_template_catalog \
  20261120110000_crm_integration_core \
  20261120120000_patient_provisioning_credentials \
  20261120130000_profile_scoped_routines_challenge; do
  echo "-- ==== $f"
  cat "supabase/migrations/$f.sql"
done
cat <<'SQL'

-- Post-checks (read only), reported as one row.
create temp table dry_report (k text, v text) on commit drop;
insert into dry_report select 'templates', count(*)::text from public.care_templates;
insert into dry_report select 'routines_total', count(*)::text from public.personal_routines;
insert into dry_report select 'routines_unassigned_but_owner_has_patient', count(*)::text
  from public.personal_routines r
  where r.patient_id is null and exists (select 1 from public.patients p where p.user_id = r.owner_user_id);
insert into dry_report select 'enrollments_total', count(*)::text from public.challenge_enrollments;
insert into dry_report select 'checkins_total', count(*)::text from public.challenge_day_checkins;
insert into dry_report select 'checkins_orphaned', count(*)::text
  from public.challenge_day_checkins c
  where not exists (select 1 from public.challenge_enrollments e
    where e.user_id = c.user_id and e.challenge_key = c.challenge_key and e.profile_key = c.profile_key);
insert into dry_report select 'patients', count(*)::text from public.patients;
do $$
declare u record; n int; bad int := 0;
begin
  for u in select user_id from public.patients where user_id is not null and status = 'active' loop
    perform set_config('request.jwt.claim.sub', u.user_id::text, true);
    select count(*) into n from public.my_family_profiles();
    if n <> 1 then bad := bad + 1; end if;
  end loop;
  insert into dry_report values ('patient_users_without_exactly_one_profile', bad::text);
end $$;
select jsonb_object_agg(k, v) as dry_run_report from dry_report;
rollback;
SQL
