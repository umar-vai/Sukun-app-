begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

-- Auth sign-ups are inserted by Supabase Auth, never by an untrusted client.
-- Use fake accounts and rollback everything when this pgTAP suite finishes.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000901',
   'new-member@sukun.test', '{"role":"super_admin","is_admin":true}'::jsonb),
  ('00000000-0000-4000-8000-000000000902',
   'existing-patient@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000903',
   'existing-admin@sukun.test', '{}'::jsonb);

select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-000000000901'$$,
  array['member'::text],
  'untrusted user metadata never creates elevated roles'
);
select results_eq(
  $$select locale from public.profiles
    where id='00000000-0000-4000-8000-000000000901'$$,
  array['bn'::text],
  'public signups receive a default Bangla profile'
);
select is(
  (select requires_credential_change from public.profiles
    where id='00000000-0000-4000-8000-000000000901'),
  false,
  'public signup is not mistakenly forced into legacy patient password reset'
);

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000902', 'patient',
   '00000000-0000-4000-8000-000000000903'),
  ('00000000-0000-4000-8000-000000000903', 'super_admin',
   '00000000-0000-4000-8000-000000000903');

insert into public.patients (id, user_id, patient_code, full_name, created_by)
values (
  '10000000-0000-4000-8000-000000000901',
  '00000000-0000-4000-8000-000000000902',
  'MEMBER-ISOLATION-1',
  'Protected Patient',
  '00000000-0000-4000-8000-000000000903'
);

select ok(
  not has_function_privilege(
    'authenticated', 'private.provision_public_member()', 'EXECUTE'
  ),
  'member provisioning function cannot be called directly by a client'
);
select ok(
  not has_function_privilege('anon', 'private.provision_public_member()', 'EXECUTE'),
  'anonymous users cannot call member provisioning function'
);
select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-000000000902'
      and role='patient'::public.app_role$$,
  array['patient'::text],
  'pre-existing patient role is unaffected'
);
select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-000000000903'
      and role='super_admin'::public.app_role$$,
  array['super_admin'::text],
  'pre-existing administrator role is unaffected'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000901', true);

select is((select count(*) from public.profiles), 1::bigint,
  'member can read only their own profile');
select is((select count(*) from public.user_roles), 1::bigint,
  'member can see only their own assigned role');
select is((select count(*) from public.patients), 0::bigint,
  'member cannot read another patient record');
select is((select count(*) from public.care_plans), 0::bigint,
  'member cannot read any clinical care plans');
select throws_ok(
  $$insert into public.user_roles (user_id, role)
     values ('00000000-0000-4000-8000-000000000901', 'super_admin')$$,
  '42501',
  'new row violates row-level security policy for table "user_roles"',
  'member cannot self-promote to super admin'
);

select * from finish();
rollback;
