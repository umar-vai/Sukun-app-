-- Every fixture rolls back. Bulk import creates an ACTIVE routine with fixed
-- reminder times for the target user only; Super Admin is checked in the DB.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users(id,email,raw_user_meta_data) values
('f0000000-0000-4000-8000-000000002711','bulk-admin@sukun.test','{}'),
('f0000000-0000-4000-8000-000000002712','bulk-recipient@sukun.test','{}'),
('f0000000-0000-4000-8000-000000002713','bulk-other@sukun.test','{}');
insert into public.profiles(id,display_name) values
('f0000000-0000-4000-8000-000000002711','Bulk admin'),
('f0000000-0000-4000-8000-000000002712','Bulk recipient'),
('f0000000-0000-4000-8000-000000002713','Bulk other')
on conflict(id) do update set display_name=excluded.display_name;
insert into public.user_roles(user_id,role) values
('f0000000-0000-4000-8000-000000002711','super_admin'::public.app_role);

select ok(
  not has_function_privilege('anon',
    'public.admin_import_user_routine_reminders(uuid,text,jsonb,text)','EXECUTE'),
  'guest cannot bulk import reminders'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002713',true);
select throws_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002712','Impersonation',
    '[{"title":"x","local_time":"07:00","resources":[]}]')
$$,'42501','Super Admin access is required','normal member cannot bulk import');

select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002711',true);
select lives_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002712',
    'Sukun bulk routine',
    '[
      {"title":"Morning amal (সকাল)","notes":"Synthetic approved note",
       "official_template_id":"a01","local_time":"06:30:00","resources":[]},
      {"title":"Morning amal (সন্ধ্যা)","official_template_id":"a01",
       "local_time":"17:30","resources":[]},
      {"title":"Al-Baqarah","official_template_id":"a07","local_time":"21:00",
       "resources":[{"provider":"quran","external_resource_ref":"quran:2"}]}
    ]')
$$,'super admin bulk import succeeds');
select throws_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002712','Bad time',
    '[{"title":"x","local_time":"25:00","resources":[]}]')
$$,'22023','Invalid action or resource count','invalid reminder time rejected');
select throws_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002712','No time',
    '[{"title":"x","resources":[]}]')
$$,'22023','Invalid action or resource count','missing reminder time rejected');
select throws_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002712','Unfilled',
    '[{"title":"Bath","notes":"{দিন} দিন","official_template_id":"b02",
       "local_time":"10:00","resources":[]}]')
$$,'22023','Invalid action or resource count','unfilled placeholders rejected');
select throws_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002712','Unlinked audio',
    '[{"title":"Audio","official_template_id":"u07","local_time":"21:00",
       "resources":[]}]')
$$,'22023','Invalid action or resource count','audio template needs a resource');
select throws_ok($$
  select public.admin_import_user_routine_reminders(
    'f0000000-0000-4000-8000-000000002712','Bad zone',
    '[{"title":"x","local_time":"07:00","resources":[]}]','Mars/Olympus')
$$,'22023','Invalid timezone','unknown timezone rejected');
select is((select count(*) from public.personal_routines),0::bigint,
  'admin still cannot SELECT the owner routine directly under RLS');
select is((
  select count(*) from public.admin_audit_logs
  where action = 'personal_routine.delegated_reminders_imported'
),1::bigint,'bulk import is audited once');

select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002712',true);
select is((select count(*) from public.personal_routines where is_active),
  1::bigint,'imported routine is active for the owner immediately');
select is((
  select count(*) from public.personal_routine_actions
  where schedule_kind = 'fixed' and is_active
), 3::bigint, 'each imported row has a fixed reminder time');
select is((
  select external_resource_ref from public.personal_routine_action_resources
  where provider = 'quran'
), 'quran:2'::text, 'canonical surah link kept');

select set_config('request.jwt.claim.sub',
  'f0000000-0000-4000-8000-000000002713',true);
select is((select count(*) from public.personal_routines),0::bigint,
  'another member cannot see the imported routine');

select * from finish();
rollback;
