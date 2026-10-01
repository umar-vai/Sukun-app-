begin;

create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, phone, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000301', '+8801700000301', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000311', '+8801700000311', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000312', '+8801700000312', '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000301', 'super_admin', '00000000-0000-4000-8000-000000000301'),
  ('00000000-0000-4000-8000-000000000311', 'patient', '00000000-0000-4000-8000-000000000301'),
  ('00000000-0000-4000-8000-000000000312', 'patient', '00000000-0000-4000-8000-000000000301');

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values
  (
    '10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000311',
    'TEST-TASK-1',
    'Task Patient One',
    '00000000-0000-4000-8000-000000000301'
  ),
  (
    '10000000-0000-4000-8000-000000000302',
    '00000000-0000-4000-8000-000000000312',
    'TEST-TASK-2',
    'Task Patient Two',
    '00000000-0000-4000-8000-000000000301'
  );

insert into public.care_plans (
  id, patient_id, version, name, start_date, status,
  published_at, published_by, created_by
) values (
  '30000000-0000-4000-8000-000000000301',
  '10000000-0000-4000-8000-000000000301',
  1,
  'Active task plan',
  current_date - 7,
  'active',
  now(),
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000301'
);

insert into public.plan_actions (
  id, care_plan_id, type, title, frequency_rule, exact_time,
  start_date, sort_order, review_status, created_by
) values
  (
    '40000000-0000-4000-8000-000000000301',
    '30000000-0000-4000-8000-000000000301',
    'recitation',
    'Any-time daily action',
    '{"type":"daily","interval":1}',
    null,
    current_date - 7,
    0,
    'approved',
    '00000000-0000-4000-8000-000000000301'
  ),
  (
    '40000000-0000-4000-8000-000000000302',
    '30000000-0000-4000-8000-000000000301',
    'listening',
    'Exact-time weekly action',
    jsonb_build_object(
      'type', 'weekly',
      'weekdays', jsonb_build_array(extract(isodow from current_date)::integer)
    ),
    '09:00'::time,
    current_date - 7,
    1,
    'approved',
    '00000000-0000-4000-8000-000000000301'
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000311', true);

select lives_ok(
  $$select * from public.ensure_patient_tasks(current_date, 0)$$,
  'patient can idempotently generate the current day from the active plan'
);
select results_eq(
  $$select count(*) from public.task_instances
    where patient_id = '10000000-0000-4000-8000-000000000301'$$,
  array[2::bigint],
  'daily and matching weekly actions each generate one task'
);
select results_eq(
  $$select count(*) from public.task_instances
    where plan_action_id = '40000000-0000-4000-8000-000000000301'
      and scheduled_at is null$$,
  array[1::bigint],
  'an action without an exact time does not receive an invented timestamp'
);
select results_eq(
  $$select count(*) from public.task_instances
    where plan_action_id = '40000000-0000-4000-8000-000000000302'
      and scheduled_at is not null$$,
  array[1::bigint],
  'an explicit exact time produces a scheduled instant'
);
select lives_ok(
  $$select * from public.ensure_patient_tasks(current_date, 0)$$,
  'repeating generation for the same date is safe'
);
select results_eq(
  $$select count(*) from public.task_instances
    where patient_id = '10000000-0000-4000-8000-000000000301'$$,
  array[2::bigint],
  'idempotent generation does not duplicate tasks'
);
select throws_ok(
  $$select * from public.ensure_patient_tasks(current_date + 1, 0)$$,
  '22023',
  'Tasks can only be generated for the patient''s current day.',
  'patient cannot generate arbitrary future dates'
);

select lives_ok(
  format(
    'select public.record_task_completion(%L, %L, %L)',
    (select id from public.task_instances
      where plan_action_id = '40000000-0000-4000-8000-000000000301'),
    'completed',
    '70000000-0000-4000-8000-000000000302'
  ),
  'patient can complete their own generated task'
);
select results_eq(
  $$select status::text from public.task_instances
    where plan_action_id = '40000000-0000-4000-8000-000000000301'$$,
  array['completed'::text],
  'task state reflects the completion event'
);
select results_eq(
  $$select count(*) from public.task_completions
    where client_event_id = '70000000-0000-4000-8000-000000000302'$$,
  array[1::bigint],
  'one append-only completion event is stored'
);
select lives_ok(
  format(
    'select public.record_task_completion(%L, %L, %L)',
    (select id from public.task_instances
      where plan_action_id = '40000000-0000-4000-8000-000000000301'),
    'completed',
    '70000000-0000-4000-8000-000000000302'
  ),
  'retrying the same client event identifier is safe'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000312', true);
select results_eq(
  $$select count(*) from public.task_instances$$,
  array[0::bigint],
  'another patient cannot read the first patient''s tasks'
);
select throws_ok(
  format(
    'select public.record_task_completion(%L, %L, %L)',
    (select id from public.task_instances),
    'completed',
    '70000000-0000-4000-8000-000000000303'
  ),
  'P0002',
  'Task was not found.',
  'another patient cannot complete the first patient''s task'
);

select * from finish();
rollback;
