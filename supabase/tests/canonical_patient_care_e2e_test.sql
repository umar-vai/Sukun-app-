begin;

-- Canonical Patient Care system acceptance test, independent of real accounts.
-- All inserted data rolls back; this exercises the *actual* Admin-to-Patient
-- database APIs, not a mocked front end. Never run against Production.
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000c501', 'qa-admin@invalid.test', '{}'::jsonb),
 ('00000000-0000-4000-8000-00000000c511', 'qa-patient-a@invalid.test', '{}'::jsonb),
 ('00000000-0000-4000-8000-00000000c512', 'qa-patient-b@invalid.test', '{}'::jsonb),
 ('00000000-0000-4000-8000-00000000c513', 'qa-member@invalid.test',
  '{"role":"super_admin"}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
 ('00000000-0000-4000-8000-00000000c501', 'super_admin',
  '00000000-0000-4000-8000-00000000c501'),
 ('00000000-0000-4000-8000-00000000c511', 'patient',
  '00000000-0000-4000-8000-00000000c501'),
 ('00000000-0000-4000-8000-00000000c512', 'patient',
  '00000000-0000-4000-8000-00000000c501');

-- The Auth Admin API provisions test accounts in the live browser scenario.
-- Here we test clinical DB access after those identities have been provisioned.
insert into public.patients (id, user_id, patient_code, full_name, created_by)
values
 ('10000000-0000-4000-8000-00000000c511',
  '00000000-0000-4000-8000-00000000c511',
  'QA-PATIENT-A', 'Synthetic Patient A',
  '00000000-0000-4000-8000-00000000c501'),
 ('10000000-0000-4000-8000-00000000c512',
  '00000000-0000-4000-8000-00000000c512',
  'QA-PATIENT-B', 'Synthetic Patient B',
  '00000000-0000-4000-8000-00000000c501');

set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-00000000c513', true);

select throws_ok(
 $$select public.create_prescription(
   '10000000-0000-4000-8000-00000000c511',
   'Unauthorized member prescription',
   current_date, 'patient', '70000000-0000-4000-8000-00000000c501'
 )$$,
 '42501', 'Super Admin access is required.',
 'Member cannot create clinical prescriptions despite fake admin metadata'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-00000000c501', true);

select lives_ok(
 $$select public.create_prescription(
   '10000000-0000-4000-8000-00000000c511',
   'Synthetic: complete your reviewed morning activity.',
   current_date, 'patient', '70000000-0000-4000-8000-00000000c502'
 )$$,
 'Admin creates the patient-visible prescription through validated RPC'
);
select results_eq(
 $$select count(*) from public.prescription_versions
   where prescription_id in (
     select id from public.prescriptions
     where patient_id='10000000-0000-4000-8000-00000000c511'
   )$$,
 array[1::bigint],
 'Prescription version is persisted atomically'
);
select lives_ok(
 $$select public.create_draft_care_plan(
   '10000000-0000-4000-8000-00000000c511',
   'Synthetic daily care plan',
   current_date, null,
   (select id from public.prescriptions
     where patient_id='10000000-0000-4000-8000-00000000c511'),
   null, '70000000-0000-4000-8000-00000000c503'
 )$$,
 'Admin converts an existing prescription into a draft care plan'
);
select results_eq(
 $$select status::text from public.care_plans
    where patient_id='10000000-0000-4000-8000-00000000c511'$$,
 array['draft'::text],
 'New care plan starts as a non-public draft'
);
select lives_ok(
 $$select public.save_plan_action(
   p_care_plan_id := (select id from public.care_plans
     where patient_id='10000000-0000-4000-8000-00000000c511'),
   p_type := 'recitation',
   p_title := 'Synthetic reviewed morning task',
   p_frequency_rule := '{"type":"daily","interval":1}'::jsonb,
   p_start_date := current_date,
   p_review_status := 'needs_review',
   p_request_id := '70000000-0000-4000-8000-00000000c504'
 )$$,
 'Admin adds an action without bypassing the review queue'
);
select throws_ok(
 $$select public.publish_care_plan(
   (select id from public.care_plans
     where patient_id='10000000-0000-4000-8000-00000000c511'),
   '70000000-0000-4000-8000-00000000c505'
 )$$,
 '22023', 'At least one approved action is required.',
 'Unreviewed action cannot be accidentally published'
);
select lives_ok(
 $$select public.save_plan_action(
   p_care_plan_id := (select id from public.care_plans
     where patient_id='10000000-0000-4000-8000-00000000c511'),
   p_type := 'recitation',
   p_title := 'Synthetic reviewed morning task',
   p_frequency_rule := '{"type":"daily","interval":1}'::jsonb,
   p_start_date := current_date,
   p_action_id := (select id from public.plan_actions
     where care_plan_id in (select id from public.care_plans
       where patient_id='10000000-0000-4000-8000-00000000c511')),
   p_review_status := 'approved',
   p_request_id := '70000000-0000-4000-8000-00000000c506'
 )$$,
 'Admin approves the explicit action before publication'
);
select lives_ok(
 $$select public.publish_care_plan(
   (select id from public.care_plans
     where patient_id='10000000-0000-4000-8000-00000000c511'),
   '70000000-0000-4000-8000-00000000c507'
 )$$,
 'Admin publishes the reviewed patient care plan'
);
select results_eq(
 $$select status::text from public.care_plans
    where patient_id='10000000-0000-4000-8000-00000000c511'$$,
 array['active'::text],
 'The published plan is active'
);
select results_eq(
 $$select count(*) from public.admin_audit_logs
   where action = 'care_plan.published'
     and request_id='70000000-0000-4000-8000-00000000c507'$$,
 array[1::bigint],
 'Publishing produces one audit event'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-00000000c511', true);

select results_eq(
 $$select count(*) from public.prescriptions$$,
 array[1::bigint],
 'Patient A sees their own published prescription'
);
select results_eq(
 $$select count(*) from public.care_plans
   where status='active'$$,
 array[1::bigint],
 'Patient A sees their published plan'
);
select lives_ok(
 $$select * from public.ensure_patient_tasks(current_date, 0)$$,
 'Patient A generates tasks from the reviewed active plan'
);
select results_eq(
 $$select count(*) from public.task_instances$$,
 array[1::bigint],
 'Patient A has exactly one daily task'
);
select set_config(
 'qa.synthetic_patient_a_task',
 (select id::text from public.task_instances limit 1),
 true
);
select lives_ok(
 format('select public.record_task_completion(%L, %L, %L)',
  current_setting('qa.synthetic_patient_a_task'),
  'completed', '70000000-0000-4000-8000-00000000c508'),
 'Patient A completes the approved task using guarded RPC'
);
select results_eq(
 $$select status::text from public.task_instances$$,
 array['completed'::text],
 'Patient A task status changes to completed'
);
select results_eq(
 $$select count(*) from public.task_completions$$,
 array[1::bigint],
 'Progress has one immutable completion event'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-00000000c512', true);
select results_eq(
 $$select count(*) from public.task_instances$$,
 array[0::bigint],
 'Patient B cannot see Patient A tasks'
);
select throws_ok(
 format('select public.record_task_completion(%L, %L, %L)',
  current_setting('qa.synthetic_patient_a_task'),
  'completed', '70000000-0000-4000-8000-00000000c509'),
 'P0002', 'Task was not found.',
 'Patient B cannot mutate Patient A task by a known UUID'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '00000000-0000-4000-8000-00000000c513', true);
select results_eq(
 $$select count(*) from public.care_plans$$,
 array[0::bigint],
 'Public Member cannot read any clinical care plan'
);

reset role;
select ok(
 not has_table_privilege('anon', 'public.task_completions', 'SELECT'),
 'Logged-out visitor cannot read private task completion events'
);

select * from finish();
rollback;
