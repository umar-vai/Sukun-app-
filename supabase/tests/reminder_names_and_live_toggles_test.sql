-- Every fixture rolls back. Reminder names, live reminder switches for
-- care plans and admin-set routines, and the copied name on a new version.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000003101', 'toggle-admin@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000003111', 'toggle-patient@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000003121', 'toggle-member@sukun.test', '{}');
insert into public.profiles (id, display_name) values
  ('00000000-0000-4000-8000-000000003101', 'Toggle admin'),
  ('00000000-0000-4000-8000-000000003111', 'Toggle patient'),
  ('00000000-0000-4000-8000-000000003121', 'Toggle member')
on conflict (id) do update set display_name = excluded.display_name;
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000003101', 'super_admin',
   '00000000-0000-4000-8000-000000003101'),
  ('00000000-0000-4000-8000-000000003111', 'patient',
   '00000000-0000-4000-8000-000000003101');

insert into public.patients (id, user_id, patient_code, full_name, created_by)
values ('10000000-0000-4000-8000-000000003101',
        '00000000-0000-4000-8000-000000003111',
        'TEST-TOGGLE-1', 'Toggle Patient',
        '00000000-0000-4000-8000-000000003101');

insert into public.care_plans (
  id, patient_id, version, name, start_date, status, published_at,
  published_by, created_by
) values (
  '30000000-0000-4000-8000-000000003101',
  '10000000-0000-4000-8000-000000003101', 1, 'Live plan', current_date,
  'active', now(), '00000000-0000-4000-8000-000000003101',
  '00000000-0000-4000-8000-000000003101'
);
insert into public.plan_actions (
  id, care_plan_id, type, title, frequency_rule, time_window, exact_time,
  start_date, review_status, reminder_enabled, created_by, notification_title
) values
  ('40000000-0000-4000-8000-000000003101',
   '30000000-0000-4000-8000-000000003101', 'supplement', 'Ruqyah water',
   '{"kind":"daily"}', 'morning', '07:30', current_date, 'approved', true,
   '00000000-0000-4000-8000-000000003101', 'রুকইয়াহ পানি পান করুন'),
  ('40000000-0000-4000-8000-000000003102',
   '30000000-0000-4000-8000-000000003101', 'amal', 'Untimed',
   '{"kind":"daily"}', 'anytime', null, current_date, 'approved', false,
   '00000000-0000-4000-8000-000000003101', null);

select has_column('public', 'plan_actions', 'notification_title',
  'plan actions carry a reminder name');
select throws_ok($$
  insert into public.plan_actions (
    care_plan_id, type, title, frequency_rule, start_date, created_by,
    notification_title
  ) values (
    '30000000-0000-4000-8000-000000003101', 'amal', 'Too long',
    '{"kind":"daily"}', current_date,
    '00000000-0000-4000-8000-000000003101', repeat('x', 121))
$$, '23514', null, 'reminder name longer than 120 is rejected');
select throws_ok($$
  select set_config('sukun.live_reminder_toggle', 'on', true);
  update public.plan_actions set title = 'Rewritten'
  where id = '40000000-0000-4000-8000-000000003101'
$$, '55000', 'Published care plan actions cannot be rewritten.',
  'the live switch path never allows clinical edits');
select ok(
  not has_function_privilege('anon',
    'public.admin_set_plan_action_reminder(uuid,boolean)', 'EXECUTE'),
  'guest cannot switch reminders');
select ok(
  not has_function_privilege('anon',
    'public.admin_set_user_routine_action_reminder(uuid,boolean)', 'EXECUTE'),
  'guest cannot switch routine reminders');

-- Patient cannot switch their plan reminders through the admin path.
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000003111', true);
select throws_ok($$
  select public.admin_set_plan_action_reminder(
    '40000000-0000-4000-8000-000000003101', false)
$$, '42501', 'Super Admin access is required.', 'patient cannot use admin switch');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000003101', true);

select is(
  public.admin_set_plan_action_reminder(
    '40000000-0000-4000-8000-000000003101', false),
  false, 'admin switches a live reminder off');
select is(
  (select reminder_enabled from public.plan_actions
   where id = '40000000-0000-4000-8000-000000003101'),
  false, 'the live action now has its reminder off');
select is(
  (select count(*)::int from public.admin_audit_logs
   where action = 'plan_action.reminder_toggled'
     and entity_id = '40000000-0000-4000-8000-000000003101'
     and patient_id = '10000000-0000-4000-8000-000000003101'),
  1, 'the switch is audited with the patient');
select is(
  public.admin_set_plan_action_reminder(
    '40000000-0000-4000-8000-000000003101', true),
  true, 'admin switches it back on');
select throws_ok($$
  select public.admin_set_plan_action_reminder(
    '40000000-0000-4000-8000-000000003102', true)
$$, '22023', 'A reminder needs an approved exact time.',
  'an action without a time cannot get a reminder');
select is(
  (select version from public.care_plans
   where patient_id = '10000000-0000-4000-8000-000000003101'
   order by version desc limit 1),
  1, 'switching does not create a new plan version');

-- A new version copies the reminder name.
select lives_ok($$
  select public.create_draft_care_plan(
    '10000000-0000-4000-8000-000000003101', 'Next version', current_date,
    null, null, '30000000-0000-4000-8000-000000003101',
    '70000000-0000-4000-8000-000000003101')
$$, 'admin creates a new version from the live plan');
select is(
  (select pa.notification_title from public.plan_actions pa
   join public.care_plans cp on cp.id = pa.care_plan_id
   where cp.status = 'draft'
     and cp.patient_id = '10000000-0000-4000-8000-000000003101'
     and pa.title = 'Ruqyah water'),
  'রুকইয়াহ পানি পান করুন', 'the copied action keeps its reminder name');

select lives_ok($$
  select public.set_draft_action_notification_title(
    (select pa.id from public.plan_actions pa
     join public.care_plans cp on cp.id = pa.care_plan_id
     where cp.status = 'draft' and pa.title = 'Untimed'
       and cp.patient_id = '10000000-0000-4000-8000-000000003101'),
    '  সকালের আমল  ')
$$, 'admin names a draft reminder');
select is(
  (select pa.notification_title from public.plan_actions pa
   join public.care_plans cp on cp.id = pa.care_plan_id
   where cp.status = 'draft' and pa.title = 'Untimed'
     and cp.patient_id = '10000000-0000-4000-8000-000000003101'),
  'সকালের আমল', 'the draft name is trimmed and saved');
select throws_ok($$
  select public.set_draft_action_notification_title(
    '40000000-0000-4000-8000-000000003101', 'Live rename')
$$, 'P0002', 'Draft action was not found.',
  'a live action cannot be renamed without a new version');

-- Routines: an admin-set routine carries the name and can be switched.
select lives_ok($$
  select public.admin_import_user_routine_reminders(
    '00000000-0000-4000-8000-000000003121', 'Named routine',
    '[{"title":"Ruqyah water (সকাল)","notification_title":"পানি পান করুন",
       "local_time":"07:30","resources":[]}]')
$$, 'routine import accepts a reminder name');
-- Owner-only RLS hides the member's rows from the admin role, so read
-- them as the test owner.
reset role;
select is(
  (select notification_title from public.personal_routine_actions
   where owner_user_id = '00000000-0000-4000-8000-000000003121'
     and title = 'Ruqyah water (সকাল)'),
  'পানি পান করুন', 'routine action keeps the reminder name');
create temp table _named_action as
  select id from public.personal_routine_actions
  where owner_user_id = '00000000-0000-4000-8000-000000003121'
    and title = 'Ruqyah water (সকাল)';
grant select on _named_action to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000003101', true);
select is(
  public.admin_set_user_routine_action_reminder(
    (select id from _named_action), false),
  false, 'admin pauses an admin-set routine reminder');

-- A routine the user made for themselves is refused.
reset role;
insert into public.personal_routines (id, owner_user_id, title, is_active)
values ('50000000-0000-4000-8000-000000003121',
        '00000000-0000-4000-8000-000000003121', 'Own routine', true);
insert into public.personal_routine_actions (
  id, routine_id, owner_user_id, title, notification_title, schedule_kind,
  local_time, timezone_name, is_active
) values ('51000000-0000-4000-8000-000000003121',
          '50000000-0000-4000-8000-000000003121',
          '00000000-0000-4000-8000-000000003121', 'Own step', 'Own step',
          'fixed', '08:00', 'Asia/Dhaka', true);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000003101', true);
select throws_ok($$
  select public.admin_set_user_routine_action_reminder(
    '51000000-0000-4000-8000-000000003121', false)
$$, '42501', 'Only admin-set routines can be changed here',
  'admin cannot switch the user''s own routine');

select * from finish();
rollback;
