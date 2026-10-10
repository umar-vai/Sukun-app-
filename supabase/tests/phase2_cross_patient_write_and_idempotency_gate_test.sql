begin;

-- Phase 2 release gate: directly exercise the real PostgREST/RPC roles and
-- write policies with synthetic accounts. Disposable CI only; rollback always.
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000d101', 'phase2-admin@invalid.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-00000000d111', 'phase2-a@invalid.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-00000000d112', 'phase2-b@invalid.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-00000000d113', 'phase2-member@invalid.test',
   '{"role":"super_admin"}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-00000000d101', 'super_admin',
   '00000000-0000-4000-8000-00000000d101'),
  ('00000000-0000-4000-8000-00000000d111', 'patient',
   '00000000-0000-4000-8000-00000000d101'),
  ('00000000-0000-4000-8000-00000000d112', 'patient',
   '00000000-0000-4000-8000-00000000d101'),
  ('00000000-0000-4000-8000-00000000d113', 'member',
   '00000000-0000-4000-8000-00000000d101');

insert into public.patients
  (id, user_id, patient_code, full_name, created_by)
values
  ('10000000-0000-4000-8000-00000000d111',
   '00000000-0000-4000-8000-00000000d111',
   'QA-PH2-A', 'QA synthetic Patient A',
   '00000000-0000-4000-8000-00000000d101'),
  ('10000000-0000-4000-8000-00000000d112',
   '00000000-0000-4000-8000-00000000d112',
   'QA-PH2-B', 'QA synthetic Patient B',
   '00000000-0000-4000-8000-00000000d101');

insert into public.care_plans
  (id, patient_id, version, name, start_date, status,
   published_at, published_by, created_by)
values
  ('30000000-0000-4000-8000-00000000d111',
   '10000000-0000-4000-8000-00000000d111',
   1, 'Original QA patient A plan', current_date, 'active',
   now(), '00000000-0000-4000-8000-00000000d101',
   '00000000-0000-4000-8000-00000000d101');

insert into public.plan_actions
  (id, care_plan_id, type, title, frequency_rule, start_date,
   review_status, created_by)
values
  ('40000000-0000-4000-8000-00000000d111',
   '30000000-0000-4000-8000-00000000d111',
   'amal', 'QA synthetic daily completion', '{"type":"daily"}',
   current_date, 'approved', '00000000-0000-4000-8000-00000000d101');

insert into public.task_instances
  (id, plan_action_id, patient_id, occurrence_date, timezone_offset_minutes)
values
  ('50000000-0000-4000-8000-00000000d111',
   '40000000-0000-4000-8000-00000000d111',
   '10000000-0000-4000-8000-00000000d111', current_date, 0);

select ok(
  (select bool_and(relrowsecurity) from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in ('patients', 'care_plans', 'plan_actions',
                     'task_instances', 'task_completions')),
  'Sensitive Phase 2 tables have RLS'
);
select ok(
  not has_table_privilege('authenticated','public.task_completions','INSERT'),
  'Direct append-only completion inserts are unavailable to clients'
);
select ok(
  not has_table_privilege('anon','public.patients','SELECT'),
  'Anonymous browsers cannot list Patients'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d111', true);
select results_eq($$select count(*) from public.patients$$,
  array[1::bigint], 'Patient A sees only their own Patient identity');
select results_eq($$select count(*) from public.task_instances$$,
  array[1::bigint], 'Patient A can read only their own task');
select results_eq(
  $$update public.patients set full_name='UNAUTHORIZED UPDATE'
    where id='10000000-0000-4000-8000-00000000d112' returning id$$,
  array[]::uuid[], 'Patient A cannot update Patient B identity by known UUID'
);
select results_eq(
  $$update public.task_instances set status='skipped'
    where id='50000000-0000-4000-8000-00000000d111' returning id$$,
  array[]::uuid[], 'Patient cannot bypass guarded completion RPC with UPDATE'
);
select lives_ok(
  $$select public.record_task_completion(
    '50000000-0000-4000-8000-00000000d111','completed',
    '70000000-0000-4000-8000-00000000d111')$$,
  'Patient A completes own task through guarded RPC'
);
select results_eq(
  $$select count(*) from public.task_completions
    where client_event_id='70000000-0000-4000-8000-00000000d111'$$,
  array[1::bigint], 'Exactly one immutable completion event recorded'
);
select lives_ok(
  $$select public.record_task_completion(
    '50000000-0000-4000-8000-00000000d111','completed',
    '70000000-0000-4000-8000-00000000d111')$$,
  'Retrying the identical completion event is idempotent'
);
select results_eq(
  $$select count(*) from public.task_completions
    where client_event_id='70000000-0000-4000-8000-00000000d111'$$,
  array[1::bigint], 'Duplicate request does not duplicate progress');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d112', true);
select results_eq($$select count(*) from public.task_instances$$,
  array[0::bigint], 'Patient B cannot read Patient A tasks');
select throws_ok(
  $$select public.record_task_completion(
    '50000000-0000-4000-8000-00000000d111','completed',
    '70000000-0000-4000-8000-00000000d112')$$,
  'P0002', 'Task was not found.',
  'Patient B cannot mutate a known Patient A task ID via RPC');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d113', true);
select results_eq($$select count(*) from public.care_plans$$,
  array[0::bigint], 'General Member cannot read clinical plans');
select throws_ok(
  $$select public.create_prescription(
    '10000000-0000-4000-8000-00000000d111',
    'Attempted forged admin change', current_date, 'patient',
    '70000000-0000-4000-8000-00000000d113')$$,
  '42501', 'Super Admin access is required.',
  'User-controlled admin metadata cannot grant clinical write access');

select * from finish();
rollback;
