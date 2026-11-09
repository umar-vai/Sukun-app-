-- Every fixture rolls back. The overview separates admin-set routines from
-- routines the user added, and only Super Admin may read it.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users(id,email,raw_user_meta_data) values
('f0000000-0000-4000-8000-000000002811','overview-admin@sukun.test','{}'),
('f0000000-0000-4000-8000-000000002812','overview-user@sukun.test','{}');
insert into public.profiles(id,display_name) values
('f0000000-0000-4000-8000-000000002811','Overview admin'),
('f0000000-0000-4000-8000-000000002812','Overview user')
on conflict(id) do update set display_name=excluded.display_name;
insert into public.user_roles(user_id,role) values
('f0000000-0000-4000-8000-000000002811','super_admin'::public.app_role);

select ok(
  not has_function_privilege('anon',
    'public.admin_get_user_routine_overview(uuid)','EXECUTE'),
  'guest cannot read routine overview'
);

set local role authenticated;
-- The user adds a routine for themselves.
select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002812',true);
insert into public.personal_routines(owner_user_id,title)
values('f0000000-0000-4000-8000-000000002812','My own reminders');
select throws_ok($$
  select public.admin_get_user_routine_overview(
    'f0000000-0000-4000-8000-000000002812')
$$,'42501','Super Admin access is required','users cannot call the admin overview');

-- The admin imports a routine for the user.
select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002811',true);
select lives_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002812','Sukun routine',
    '[{"title":"ঘুমের পূর্বের আমল","notes":"Synthetic","official_template_id":"a02",
       "local_time":"22:00","resources":[]}]')
$$,'admin import for overview');

select is((
  select count(*) from jsonb_array_elements(
    public.admin_get_user_routine_overview(
      'f0000000-0000-4000-8000-000000002812')->'routines') r
  where (r->>'assigned_by_admin')::boolean
),1::bigint,'admin routine is marked as admin-set');
select is((
  select count(*) from jsonb_array_elements(
    public.admin_get_user_routine_overview(
      'f0000000-0000-4000-8000-000000002812')->'routines') r
  where not (r->>'assigned_by_admin')::boolean
),1::bigint,'self-added routine is marked as user-set');
select is((
  select r->'actions'->0->>'title' from jsonb_array_elements(
    public.admin_get_user_routine_overview(
      'f0000000-0000-4000-8000-000000002812')->'routines') r
  where (r->>'assigned_by_admin')::boolean
),'ঘুমের পূর্বের আমল'::text,'actions are included');
select ok((
  select count(*) from public.admin_audit_logs
  where action = 'personal_routine.overview_viewed'
) >= 1,'overview reads are audited');

select * from finish();
rollback;
