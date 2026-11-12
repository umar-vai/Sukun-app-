-- Every fixture rolls back. Calendar ("dates") care plan actions run only on
-- their dates, and a detox date pauses the patient's other actions.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000005501', 'ghusl-admin@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000005502', 'ghusl-patient@sukun.test', '{}');
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000005501', 'super_admin',
   '00000000-0000-4000-8000-000000005501'),
  ('00000000-0000-4000-8000-000000005502', 'patient',
   '00000000-0000-4000-8000-000000005501')
on conflict do nothing;
insert into public.patients (id, user_id, patient_code, full_name, created_by)
values ('00000000-0000-4000-8000-000000005510',
        '00000000-0000-4000-8000-000000005502', 'SL-GH-1', 'Ghusl Patient',
        '00000000-0000-4000-8000-000000005501');
insert into public.care_plans (id, patient_id, version, name, start_date, status,
  published_at, published_by, created_by)
values ('00000000-0000-4000-8000-000000005520',
        '00000000-0000-4000-8000-000000005510', 1, 'plan', current_date - 1,
        'active', now(), '00000000-0000-4000-8000-000000005501',
        '00000000-0000-4000-8000-000000005501');

insert into public.plan_actions (id, care_plan_id, type, title, frequency_rule,
  start_date, review_status, reminder_enabled, exact_time, sort_order, created_by)
values
  ('00000000-0000-4000-8000-000000005530', '00000000-0000-4000-8000-000000005520',
   'amal', 'daily', '{"type":"daily","interval":1}',
   current_date - 1, 'approved', true, '23:59', 0,
   '00000000-0000-4000-8000-000000005501'),
  ('00000000-0000-4000-8000-000000005531', '00000000-0000-4000-8000-000000005520',
   'bath', 'detox', jsonb_build_object('type', 'dates', 'dates',
     jsonb_build_array(current_date::text), 'ghusl', 'detox'),
   current_date - 1, 'approved', true, '23:58', 1,
   '00000000-0000-4000-8000-000000005501');

select throws_ok($$
  insert into public.plan_actions (care_plan_id, type, title, frequency_rule,
    start_date, created_by)
  values ('00000000-0000-4000-8000-000000005520', 'bath', 'bad',
    '{"type":"dates","dates":[]}', current_date,
    '00000000-0000-4000-8000-000000005501')
$$, '22023', null, 'empty calendar is refused');

select throws_ok($$
  insert into public.plan_actions (care_plan_id, type, title, frequency_rule,
    start_date, created_by)
  values ('00000000-0000-4000-8000-000000005520', 'bath', 'bad',
    '{"type":"dates","dates":["2026-11-20"],"ghusl":"x"}', current_date,
    '00000000-0000-4000-8000-000000005501')
$$, '22023', null, 'unknown ghusl kind is refused');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000005502', true);

select is(
  (select count(*)::integer from public.ensure_patient_tasks(current_date, 0)
   where plan_action_id = '00000000-0000-4000-8000-000000005531'),
  1, 'the detox bath runs on its date');

select is(
  (select count(*)::integer from public.ensure_patient_tasks(current_date, 0)
   where plan_action_id = '00000000-0000-4000-8000-000000005530'),
  0, 'other actions pause on a detox day');

select is(
  (select count(*)::integer from public.ensure_patient_reminder_tasks(current_date, current_date + 1, 0)
   where plan_action_id = '00000000-0000-4000-8000-000000005530'),
  1, 'the daily reminder returns the next day');

reset role;
select has_column('public', 'personal_routine_actions', 'active_dates',
  'routine steps carry calendar dates');

select * from finish();
rollback;
