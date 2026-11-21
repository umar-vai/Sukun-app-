-- Family accounts: one login, many independent profiles (CRM/ERP master prompt).
begin;

create extension if not exists pgtap with schema extensions;
select plan(47);

insert into auth.users (id, phone, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000a01', '+8801700000a01', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a11',  '+8801700000a11', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a12',  '+8801700000a12', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a13','+8801700000a13', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a14',   '+8801700000a14', '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000a01', 'super_admin', '00000000-0000-4000-8000-000000000a01'),
  ('00000000-0000-4000-8000-000000000a11',  'patient', '00000000-0000-4000-8000-000000000a01'),
  ('00000000-0000-4000-8000-000000000a12',  'patient', '00000000-0000-4000-8000-000000000a01'),
  ('00000000-0000-4000-8000-000000000a13','patient', '00000000-0000-4000-8000-000000000a01'),
  ('00000000-0000-4000-8000-000000000a14',   'patient', '00000000-0000-4000-8000-000000000a01');

-- Family 1: owner profile P1 plus four logins-less profiles P2..P5.
-- Family 2: owner profile P6 plus P7. Single patient: P8. Own-login: P9.
insert into public.patients (id, user_id, patient_code, full_name, created_by) values
  ('10000000-0000-4000-8000-0000000fa001', '00000000-0000-4000-8000-000000000a11',  'FAM-P1', 'Abdul Rahman',  '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa002', null,        'FAM-P2', 'Fatema Begum',  '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa003', null,        'FAM-P3', 'Muhammad Ahmed','00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa004', null,        'FAM-P4', 'Ayesha Rahman', '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa005', null,        'FAM-P5', 'Khadija Begum', '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa006', '00000000-0000-4000-8000-000000000a12',  'FAM-P6', 'Other Family Owner', '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa007', null,        'FAM-P7', 'Other Family Child', '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa008', '00000000-0000-4000-8000-000000000a13','FAM-P8', 'Single Patient', '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-0000000fa009', '00000000-0000-4000-8000-000000000a14',   'FAM-P9', 'Has Own Login', '00000000-0000-4000-8000-000000000a01');

-- One active plan per patient: P1 has two daily actions, the others one.
insert into public.care_plans (id, patient_id, version, name, start_date, status, published_at, published_by, created_by)
select format('30000000-0000-4000-8000-0000000fb%s', lpad(n::text,3,'0'))::uuid, format('10000000-0000-4000-8000-0000000fa%s', lpad(n::text,3,'0'))::uuid,
  1, 'Plan ' || n, current_date - 7, 'active', now(), '00000000-0000-4000-8000-000000000a01', '00000000-0000-4000-8000-000000000a01'
from generate_series(1, 9) n;

insert into public.plan_actions (id, care_plan_id, type, title, frequency_rule, start_date, sort_order, review_status, created_by)
select format('40000000-0000-4000-8000-0000000fc%s', lpad(n::text,3,'0'))::uuid,
  format('30000000-0000-4000-8000-0000000fb%s', lpad(n::text,3,'0'))::uuid, 'recitation', 'Daily ' || n,
  '{"type":"daily","interval":1}', current_date - 7, 0, 'approved', '00000000-0000-4000-8000-000000000a01'
from generate_series(1, 9) n;
insert into public.plan_actions (id, care_plan_id, type, title, frequency_rule, start_date, sort_order, review_status, created_by)
values ('40000000-0000-4000-8000-0000000fc101', '30000000-0000-4000-8000-0000000fb001',
  'listening', 'Second action for P1', '{"type":"daily","interval":1}', current_date - 7, 1, 'approved', '00000000-0000-4000-8000-000000000a01');

insert into public.prescriptions (id, patient_id, raw_text, visibility, created_by) values
  ('50000000-0000-4000-8000-0000000fd001', '10000000-0000-4000-8000-0000000fa002', 'Patient visible text', 'patient', '00000000-0000-4000-8000-000000000a01'),
  ('50000000-0000-4000-8000-0000000fd002', '10000000-0000-4000-8000-0000000fa002', 'STAFF ONLY counselling note', 'staff_only', '00000000-0000-4000-8000-000000000a01');

-- Staff link the family (the owner profile is added automatically).
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a01', true);
select lives_ok($$select public.admin_create_family('10000000-0000-4000-8000-0000000fa001', 'Rahman family', 'CRM-F-1002')$$, 'staff creates the family from the owner profile');
select lives_ok($$select public.admin_create_family('10000000-0000-4000-8000-0000000fa001', 'ignored', null)$$, 'creating the family again is idempotent');
select results_eq($$select count(*) from public.family_accounts where owner_user_id = '00000000-0000-4000-8000-000000000a11'$$, array[1::bigint], 'idempotent create keeps one family row');
select lives_ok($$select public.admin_add_family_member(f.id, p.id, rel, ord)
  from public.family_accounts f, (values
    ('10000000-0000-4000-8000-0000000fa002'::uuid,'wife',1),('10000000-0000-4000-8000-0000000fa003','son',2),('10000000-0000-4000-8000-0000000fa004','daughter',3),('10000000-0000-4000-8000-0000000fa005','mother',4)) v(pid, rel, ord)
  join public.patients p on p.id = v.pid
  where f.owner_user_id = '00000000-0000-4000-8000-000000000a11'$$, 'staff links four more profiles (five in total, no hard limit)');
select lives_ok($$select public.admin_create_family('10000000-0000-4000-8000-0000000fa006', 'Other family', 'CRM-F-2000')$$, 'second family exists');
select lives_ok($$select public.admin_add_family_member(f.id, '10000000-0000-4000-8000-0000000fa007'::uuid, 'child', 1)
  from public.family_accounts f where f.owner_user_id = '00000000-0000-4000-8000-000000000a12'$$, 'second family gets a member');

select throws_ok($$select public.admin_add_family_member(f.id, '10000000-0000-4000-8000-0000000fa007'::uuid, null, null)
  from public.family_accounts f where f.owner_user_id = '00000000-0000-4000-8000-000000000a11'$$, '23505', null, 'a profile cannot be moved silently into another family');
select throws_ok($$select public.admin_add_family_member(f.id, '10000000-0000-4000-8000-0000000fa009'::uuid, null, null)
  from public.family_accounts f where f.owner_user_id = '00000000-0000-4000-8000-000000000a11'$$, '23505', null, 'a profile with its own login cannot be linked');
select throws_ok($$select public.admin_create_family('10000000-0000-4000-8000-0000000fa002', null, null)$$, '22023', null, 'a login-less profile cannot own a family');

-- Profile list per account.
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a11', true);
select results_eq($$select full_name from public.my_family_profiles()$$,
  array['Abdul Rahman','Fatema Begum','Muhammad Ahmed','Ayesha Rahman','Khadija Begum'],
  'family login lists five profiles, owner first, in display order');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a13', true);
select results_eq($$select full_name from public.my_family_profiles()$$, array['Single Patient'], 'single-patient account keeps exactly its own profile');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a12', true);
select results_eq($$select count(*) from public.my_family_profiles()$$, array[2::bigint], 'second family sees only its own two profiles');

-- Task generation per profile.
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a11', true);
select lives_ok($$select * from public.ensure_patient_tasks(current_date, 0, '10000000-0000-4000-8000-0000000fa002')$$, 'family generates tasks for a selected linked profile');
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa001'$$, array[0::bigint], 'generating for P2 creates nothing for P1');
select lives_ok($$select * from public.ensure_patient_tasks(current_date, 0)$$, 'no profile id keeps the legacy own-profile behaviour');
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa001'$$, array[2::bigint], 'owner profile P1 now has its two tasks');
select throws_ok($$select * from public.ensure_patient_tasks(current_date, 0, '10000000-0000-4000-8000-0000000fa006')$$, '42501', null, 'forged profile of another family is rejected');
select throws_ok($$select * from public.ensure_patient_reminder_tasks(current_date, current_date, 0, '10000000-0000-4000-8000-0000000fa007')$$, '42501', null, 'forged profile is rejected by reminder generation too');
select lives_ok($$select * from public.ensure_patient_tasks(current_date, 0, '10000000-0000-4000-8000-0000000fa003')$$, 'third profile generates its own tasks');

-- Completion independence: P2 completes, P1 and P3 stay pending.
select lives_ok(format('select public.record_task_completion(%L, %L, %L)',
  (select id from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa002'), 'completed',
  '70000000-0000-4000-8000-0000000fe001'), 'family login completes the task of the selected profile');
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa002' and status = 'completed'$$, array[1::bigint], 'P2 shows 1 completed');
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa001' and status = 'completed'$$, array[0::bigint], 'P1 progress is untouched by P2 completion');
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa003' and status = 'completed'$$, array[0::bigint], 'P3 progress is untouched by P2 completion');
select results_eq($$select patient_id from public.task_completions where client_event_id = '70000000-0000-4000-8000-0000000fe001'$$,
  array['10000000-0000-4000-8000-0000000fa002'::uuid], 'the completion event is stored under the actual profile');
select lives_ok(format('select public.record_task_completion(%L, %L, %L)',
  (select id from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa002'), 'completed',
  '70000000-0000-4000-8000-0000000fe001'), 'replaying the same event is idempotent');
select results_eq($$select count(*) from public.task_completions where patient_id = '10000000-0000-4000-8000-0000000fa002'$$, array[1::bigint], 'replay does not inflate completion counts');

-- Intra-family visibility is allowed; staff-only data is not.
select results_eq($$select count(distinct patient_id) from public.task_instances$$, array[3::bigint], 'family reads task progress of linked profiles (approved visibility)');
select results_eq($$select count(*) from public.prescriptions where patient_id = '10000000-0000-4000-8000-0000000fa002'$$, array[1::bigint], 'family sees only the patient-visible prescription');
select results_eq($$select count(*) from public.prescriptions where visibility = 'staff_only'$$, array[0::bigint], 'staff-only prescriptions stay hidden from the family');
select results_eq($$select count(*) from public.care_plans where patient_id = '10000000-0000-4000-8000-0000000fa006'$$, array[0::bigint], 'family 1 cannot read family 2 plans');

-- Cross-family and single-patient isolation.
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a12', true);
select results_eq($$select count(*) from public.task_instances where patient_id in ('10000000-0000-4000-8000-0000000fa001','10000000-0000-4000-8000-0000000fa002','10000000-0000-4000-8000-0000000fa003')$$, array[0::bigint], 'family 2 cannot read family 1 tasks');
select throws_ok(format('select public.record_task_completion(%L, %L, %L)',
  (select id from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa003' limit 1), 'completed',
  '70000000-0000-4000-8000-0000000fe002'), 'P0002', null, 'another family cannot complete a task of family 1');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a13', true);
select results_eq($$select count(*) from public.task_instances$$, array[0::bigint], 'single-patient account sees none of the family data');
select lives_ok($$select * from public.ensure_patient_tasks(current_date, 0)$$, 'single-patient account still generates its own tasks');
select results_eq($$select count(*) from public.family_members$$, array[0::bigint], 'single-patient account cannot read family membership rows');

-- Direct writes are impossible for authenticated users.
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a11', true);
select throws_ok($$insert into public.family_members (family_id, patient_id) select id, '10000000-0000-4000-8000-0000000fa006' from public.family_accounts limit 1$$, '42501', null, 'family login cannot link profiles by direct insert');
select throws_ok($$select public.admin_add_family_member(f.id, '10000000-0000-4000-8000-0000000fa006'::uuid, null, null) from public.family_accounts f where f.owner_user_id = '00000000-0000-4000-8000-000000000a11'$$, '42501', null, 'family login cannot call staff linking functions');

-- Per-device profile selection (notification devices).
select lives_ok($$select public.register_notification_device('install-A', 'android', 'tok-A', 'Asia/Dhaka', '10000000-0000-4000-8000-0000000fa001')$$, 'phone A registers with profile P1');
select lives_ok($$select public.register_notification_device('install-B', 'android', 'tok-B', 'Asia/Dhaka', '10000000-0000-4000-8000-0000000fa002')$$, 'phone B registers with profile P2');
select lives_ok($$select public.register_notification_device('install-A', 'android', 'tok-A', 'Asia/Dhaka', '10000000-0000-4000-8000-0000000fa003')$$, 'phone A switches to P3');
select results_eq($$select installation_id || ':' || patient_id::text from public.notification_devices order by installation_id$$,
  array['install-A:10000000-0000-4000-8000-0000000fa003','install-B:10000000-0000-4000-8000-0000000fa002'], 'switching phone A never changes the profile selected on phone B');
select throws_ok($$select public.register_notification_device('install-C', 'android', 'tok-C', 'Asia/Dhaka', '10000000-0000-4000-8000-0000000fa006')$$, '42501', null, 'a device cannot select a profile of another family');

-- Unlinking keeps history and removes access.
reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a01', true);
set local role authenticated;
select lives_ok($$select public.admin_remove_family_member(f.id, '10000000-0000-4000-8000-0000000fa003'::uuid) from public.family_accounts f where f.owner_user_id = '00000000-0000-4000-8000-000000000a11'$$, 'staff unlinks a profile');
select throws_ok($$select public.admin_remove_family_member(f.id, '10000000-0000-4000-8000-0000000fa001'::uuid) from public.family_accounts f where f.owner_user_id = '00000000-0000-4000-8000-000000000a11'$$, '22023', null, 'the owner profile cannot be unlinked');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a11', true);
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa003'$$, array[0::bigint], 'unlinked profile data is no longer visible to the family');
reset role;
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000fa003'$$, array[1::bigint], 'unlinking kept the profile task history');
select results_eq($$select action from public.admin_audit_logs where action like 'family.%' order by id desc limit 1$$, array['family.member_unlinked'::text], 'family changes are audited');

select * from finish();
rollback;
