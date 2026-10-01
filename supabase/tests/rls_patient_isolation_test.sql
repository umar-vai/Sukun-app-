begin;

create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000001', 'admin@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000011', 'patient-one@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000012', 'patient-two@sukun.test', '{}'::jsonb),
  (
    '00000000-0000-4000-8000-000000000099',
    'fake-admin@sukun.test',
    '{"role":"super_admin"}'::jsonb
  );

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000001', 'super_admin', '00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000011', 'patient', '00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000012', 'patient', '00000000-0000-4000-8000-000000000001');

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values
  (
    '10000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000011',
    'TEST-P001',
    'Patient One',
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000012',
    'TEST-P002',
    'Patient Two',
    '00000000-0000-4000-8000-000000000001'
  );

insert into public.prescriptions (
  id, patient_id, raw_text, visibility, created_by
) values
  (
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'Patient one instruction',
    'patient',
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    'Patient two instruction',
    'patient',
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '20000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000001',
    'Internal note',
    'staff_only',
    '00000000-0000-4000-8000-000000000001'
  );

insert into public.care_plans (
  id, patient_id, prescription_id, version, name, start_date, status,
  published_at, published_by, created_by
) values
  (
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    1,
    'Patient one plan',
    current_date,
    'active',
    now(),
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    1,
    'Patient two plan',
    current_date,
    'active',
    now(),
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000001'
  );

insert into public.plan_actions (
  id, care_plan_id, type, title, frequency_rule, start_date,
  review_status, created_by
) values
  (
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    'amal',
    'Patient one action',
    '{"type":"daily"}',
    current_date,
    'approved',
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '40000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000002',
    'amal',
    'Patient two action',
    '{"type":"daily"}',
    current_date,
    'approved',
    '00000000-0000-4000-8000-000000000001'
  );

insert into public.task_instances (
  id, plan_action_id, patient_id, occurrence_date, scheduled_at,
  timezone_offset_minutes
) values
  (
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    current_date,
    now(),
    0
  ),
  (
    '50000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    current_date,
    now(),
    0
  );

select ok(
  (select bool_and(c.relrowsecurity)
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'),
  'RLS is enabled on every public table'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000011',
  true
);

select results_eq(
  $$select count(*) from public.patients$$,
  array[1::bigint],
  'patient sees only their patient record'
);
select results_eq(
  $$select full_name from public.patients$$,
  array['Patient One'::text],
  'patient cannot read another patient identity'
);
select results_eq(
  $$select count(*) from public.prescriptions$$,
  array[1::bigint],
  'patient sees own patient-visible prescription only'
);
select results_eq(
  $$select count(*) from public.care_plans$$,
  array[1::bigint],
  'patient sees only their published care plan'
);
select results_eq(
  $$select count(*) from public.plan_actions$$,
  array[1::bigint],
  'patient sees only approved actions in their plan'
);
select results_eq(
  $$select count(*) from public.task_instances$$,
  array[1::bigint],
  'patient sees only their task instance'
);
select results_eq(
  $$update public.task_instances
    set status = 'skipped'
    where id = '50000000-0000-4000-8000-000000000001'
    returning id$$,
  array[]::uuid[],
  'patient cannot update task rows directly through RLS'
);

select lives_ok(
  $$select public.record_task_completion(
    '50000000-0000-4000-8000-000000000001',
    'completed',
    '60000000-0000-4000-8000-000000000001'
  )$$,
  'patient can complete their own task through the guarded RPC'
);
select results_eq(
  $$select status::text from public.task_instances
    where id = '50000000-0000-4000-8000-000000000001'$$,
  array['completed'::text],
  'guarded RPC records the completion state'
);
select results_eq(
  $$select count(*) from public.task_completions$$,
  array[1::bigint],
  'patient sees their own append-only completion event'
);
select throws_ok(
  $$select public.record_task_completion(
    '50000000-0000-4000-8000-000000000002',
    'completed',
    '60000000-0000-4000-8000-000000000002'
  )$$,
  'P0002',
  'Task was not found.',
  'patient cannot complete another patient task'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$select count(*) from public.patients$$,
  array[2::bigint],
  'database-verified super admin can read all patients'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000099',
  true
);
select results_eq(
  $$select count(*) from public.patients$$,
  array[0::bigint],
  'user-editable metadata cannot grant super-admin access'
);

select * from finish();
rollback;
