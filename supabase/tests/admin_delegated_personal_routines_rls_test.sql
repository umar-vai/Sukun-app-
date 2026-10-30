-- Every fixture rolls back. Super Admin rights come from DB user_roles,
-- never editable JWT user_metadata, and owner RLS stays intact.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users(id,email,raw_user_meta_data) values
('f0000000-0000-4000-8000-000000002611','admin-delegator@sukun.test','{}'),
('f0000000-0000-4000-8000-000000002612','recipient-routine@sukun.test','{}'),
('f0000000-0000-4000-8000-000000002613','unrelated-member@sukun.test','{}');
insert into public.profiles(id,display_name) values
('f0000000-0000-4000-8000-000000002611','Delegator'),
('f0000000-0000-4000-8000-000000002612','Recipient'),
('f0000000-0000-4000-8000-000000002613','Other member')
on conflict(id) do update set display_name=excluded.display_name;
insert into public.user_roles(user_id,role) values
('f0000000-0000-4000-8000-000000002611','super_admin'::public.app_role);

select ok(
  not has_function_privilege('anon',
    'public.admin_get_user_routine_progress(uuid,integer)','EXECUTE'),
  'guest cannot inspect admin progress RPC'
);
select ok(
  not has_function_privilege('anon',
    'public.admin_create_user_routine(uuid,text,jsonb)','EXECUTE'),
  'guest cannot create admin-delegated routine'
);
select ok(
  (select relrowsecurity from pg_class where oid='public.personal_routines'::regclass),
  'owner RLS remains enabled'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002613',true);
select throws_ok($$
  select public.admin_get_user_routine_progress(
    'f0000000-0000-4000-8000-000000002612',7)
$$,'42501','Super Admin access is required','normal member cannot see other progress');
select throws_ok($$
  select public.admin_create_user_routine(
    'f0000000-0000-4000-8000-000000002612','Impersonation',
    '[{"title":"Unauthorised","resources":[]}]')
$$,'42501','Super Admin access is required','normal member cannot assign routine');

select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002611',true);
select lives_ok($$
  select public.admin_create_user_routine(
    'f0000000-0000-4000-8000-000000002612',
    'Synthetic admin suggested routine',
    '[{"title":"Read Al-Fatiha","resources":[
      {"provider":"quran","external_resource_ref":"quran:1:7"}
    ]}]')
$$,'super admin may create an inactive, owner-visible routine');
select throws_ok($$
  select public.admin_create_user_routine(
    'f0000000-0000-4000-8000-000000002612',
    'Invalid references',
    '[{"title":"Bad Quran","resources":[
      {"provider":"quran","external_resource_ref":"quran:115:9"}
    ]}]')
$$,'22023','Invalid canonical Quran reference','invalid Quran IDs rejected');
select is((select count(*) from public.personal_routines),0::bigint,
  'admin still cannot SELECT another owner routine directly under RLS');
select lives_ok($$
  select public.admin_get_user_routine_progress(
    'f0000000-0000-4000-8000-000000002612',7)
$$,'super admin may use scoped, audited progress RPC');
select throws_ok($$
  select public.admin_get_user_routine_progress(
    'f0000000-0000-4000-8000-000000002612',365)
$$,'22023','Only 7 or 30 days are supported','progress cannot be unbounded');
select is((
  select count(*) from public.admin_audit_logs
  where action in (
    'personal_routine.delegated_draft_created',
    'personal_routine.progress_viewed')
),2::bigint,'delegated routine and progress reads both audited');

select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002612',true);
select is((select count(*) from public.personal_routines),
  1::bigint,'target owner sees delegated draft');
select is((select count(*) from public.personal_routine_actions where is_active),
  0::bigint,'delegated action does not auto-enable reminders');

select * from finish();
rollback;
