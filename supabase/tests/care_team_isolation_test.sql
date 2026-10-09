begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000a01', 'staff-admin@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a02', 'staff-raqi@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a03', 'staff-support@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a04', 'staff-patient@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a05', 'staff-member@sukun.test', '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000a01', 'super_admin', '00000000-0000-4000-8000-000000000a01'),
  ('00000000-0000-4000-8000-000000000a02', 'raqi', '00000000-0000-4000-8000-000000000a01'),
  ('00000000-0000-4000-8000-000000000a03', 'support_staff', '00000000-0000-4000-8000-000000000a01'),
  ('00000000-0000-4000-8000-000000000a04', 'patient', '00000000-0000-4000-8000-000000000a01');

insert into public.patients (id, user_id, patient_code, full_name, created_by)
values
  ('10000000-0000-4000-8000-000000000a01', '00000000-0000-4000-8000-000000000a04', 'STAFF-TEST-1', 'Private Patient', '00000000-0000-4000-8000-000000000a01'),
  ('10000000-0000-4000-8000-000000000a02', null, 'STAFF-TEST-2', 'Private Patient 2', '00000000-0000-4000-8000-000000000a01');

insert into public.care_team_assignments
  (patient_id, staff_user_id, assignment_role, assigned_by, active, ended_at)
values
  ('10000000-0000-4000-8000-000000000a01', '00000000-0000-4000-8000-000000000a02', 'raqi', '00000000-0000-4000-8000-000000000a01', true, null),
  ('10000000-0000-4000-8000-000000000a01', '00000000-0000-4000-8000-000000000a03', 'support_staff', '00000000-0000-4000-8000-000000000a01', true, null),
  ('10000000-0000-4000-8000-000000000a02', '00000000-0000-4000-8000-000000000a03', 'support_staff', '00000000-0000-4000-8000-000000000a01', false, now());

select has_table('public', 'care_team_assignments', 'assignment table exists');
select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-000000000a04'
      and role='patient'::public.app_role$$,
  array['patient'::text],
  'existing patient role still exists'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a05', true);

select is((select count(*) from public.care_team_assignments), 0::bigint,
  'member sees no staff assignments');
select is((select count(*) from public.patients), 0::bigint,
  'member sees no patient records');
select is((select count(*) from public.care_plans), 0::bigint,
  'member sees no care plans');
select throws_ok(
  $$insert into public.care_team_assignments
    (patient_id, staff_user_id, assignment_role, assigned_by)
    values ('10000000-0000-4000-8000-000000000a01',
      '00000000-0000-4000-8000-000000000a05', 'raqi',
      '00000000-0000-4000-8000-000000000a05')$$,
  '42501',
  'new row violates row-level security policy for table "care_team_assignments"',
  'member cannot assign themself to a patient'
);
select throws_ok(
  $$insert into public.user_roles (user_id, role)
    values ('00000000-0000-4000-8000-000000000a05', 'raqi')$$,
  '42501',
  'new row violates row-level security policy for table "user_roles"',
  'member cannot self-grant the raqi role'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a02', true);
select is((select count(*) from public.care_team_assignments), 1::bigint,
  'raqi sees own active assignment only');
select is((select count(*) from public.patients), 0::bigint,
  'raqi still cannot browse clinical patient table');
select is((select count(*) from public.prescriptions), 0::bigint,
  'raqi has no prescription access by default');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a03', true);
select is((select count(*) from public.care_team_assignments), 1::bigint,
  'support sees only own active assignment, not deactivated');
select is((select count(*) from public.patients), 0::bigint,
  'support has no general patient-record access');
select is((select count(*) from public.prescriptions), 0::bigint,
  'support cannot read prescriptions');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a01', true);
select is((select count(*) from public.care_team_assignments), 3::bigint,
  'admin can audit active and inactive assignments');

select * from finish();
rollback;
