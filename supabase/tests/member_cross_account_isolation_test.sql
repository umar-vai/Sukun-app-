begin;

create extension if not exists pgtap with schema extensions;
select plan(20);

-- All identities and clinical records are synthetic and rolled back.
-- A new OAuth/member account must never inherit another member's profile
-- or any patient/admin access from client-supplied metadata.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000a01', 'member-a@test.invalid',
   '{"role":"super_admin"}'::jsonb),
  ('00000000-0000-4000-8000-000000000a02', 'member-b@test.invalid',
   '{"role":"patient"}'::jsonb),
  ('00000000-0000-4000-8000-000000000a03', 'clinical@test.invalid',
   '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000a04', 'admin@test.invalid',
   '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000a03', 'patient',
   '00000000-0000-4000-8000-000000000a04'),
  ('00000000-0000-4000-8000-000000000a04', 'super_admin',
   '00000000-0000-4000-8000-000000000a04');

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values (
  '10000000-0000-4000-8000-000000000a03',
  '00000000-0000-4000-8000-000000000a03',
  'ISOLATION-PATIENT', 'Synthetic Clinical User',
  '00000000-0000-4000-8000-000000000a04'
);

insert into public.prescriptions (
  id, patient_id, raw_text, visibility, created_by
) values (
  '20000000-0000-4000-8000-000000000a03',
  '10000000-0000-4000-8000-000000000a03',
  'Synthetic private prescription', 'patient',
  '00000000-0000-4000-8000-000000000a04'
);

insert into public.care_plans (
  id, patient_id, prescription_id, version, name, start_date,
  status, published_at, published_by, created_by
) values (
  '30000000-0000-4000-8000-000000000a03',
  '10000000-0000-4000-8000-000000000a03',
  '20000000-0000-4000-8000-000000000a03',
  1, 'Synthetic private plan', current_date, 'active', now(),
  '00000000-0000-4000-8000-000000000a04',
  '00000000-0000-4000-8000-000000000a04'
);

-- Member A can see only their own profile and member grant.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a01', true
);

select results_eq(
  $$select id from public.profiles$$,
  array['00000000-0000-4000-8000-000000000a01'::uuid],
  'member A sees only their own profile'
);
select results_eq(
  $$select user_id from public.user_roles$$,
  array['00000000-0000-4000-8000-000000000a01'::uuid],
  'member A sees only their own role'
);
select results_eq(
  $$select role::text from public.user_roles$$,
  array['member'::text],
  'untrusted metadata does not elevate member A'
);
select results_eq(
  $$update public.profiles set display_name = 'STOLEN'
    where id = '00000000-0000-4000-8000-000000000a02'
    returning id$$,
  array[]::uuid[],
  'member A cannot edit member B profile'
);
select results_eq(
  $$select count(*) from public.patients$$,
  array[0::bigint],
  'member A cannot see clinical patient'
);
select results_eq(
  $$select count(*) from public.prescriptions$$,
  array[0::bigint],
  'member A cannot see prescriptions'
);
select results_eq(
  $$select count(*) from public.care_plans$$,
  array[0::bigint],
  'member A cannot see care plans'
);

-- Switch authenticated JWT subject without any app cache reset. RLS must
-- immediately isolate B from A, without inheriting A's identity or grants.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000a02', true
);
select results_eq(
  $$select id from public.profiles$$,
  array['00000000-0000-4000-8000-000000000a02'::uuid],
  'member B sees only their own profile'
);
select results_eq(
  $$select user_id from public.user_roles$$,
  array['00000000-0000-4000-8000-000000000a02'::uuid],
  'member B sees only their own role'
);
select results_eq(
  $$select role::text from public.user_roles$$,
  array['member'::text],
  'member B did not inherit metadata-claimed patient role'
);
select results_eq(
  $$update public.profiles set display_name = 'STOLEN'
    where id = '00000000-0000-4000-8000-000000000a01'
    returning id$$,
  array[]::uuid[],
  'member B cannot edit member A profile'
);
select results_eq(
  $$select count(*) from public.patients$$,
  array[0::bigint],
  'member B cannot see clinical patient'
);
select results_eq(
  $$select count(*) from public.prescriptions$$,
  array[0::bigint],
  'member B cannot see prescriptions'
);
select results_eq(
  $$select count(*) from public.care_plans$$,
  array[0::bigint],
  'member B cannot see care plans'
);

-- Logged-out requests must not retain access to private tables. The
-- browser's public publishable key alone is not a patient session.
reset role;
select ok(
  not has_table_privilege('anon', 'public.profiles', 'SELECT'),
  'logged-out anonymous role cannot read profiles'
);
select ok(
  not has_table_privilege('anon', 'public.user_roles', 'SELECT'),
  'logged-out anonymous role cannot read verified roles'
);
select ok(
  not has_table_privilege('anon', 'public.patients', 'SELECT'),
  'logged-out anonymous role cannot read patients'
);
select ok(
  not has_table_privilege('anon', 'public.prescriptions', 'SELECT'),
  'logged-out anonymous role cannot read prescriptions'
);
select ok(
  not has_table_privilege('anon', 'public.care_plans', 'SELECT'),
  'logged-out anonymous role cannot read care plans'
);
select ok(
  not has_table_privilege('anon', 'public.task_instances', 'SELECT'),
  'logged-out anonymous role cannot read patient tasks'
);

select * from finish();
rollback;
