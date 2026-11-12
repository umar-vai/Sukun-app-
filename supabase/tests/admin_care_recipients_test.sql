-- Every fixture rolls back. The admin Patients list shows only people under
-- care; search reaches other accounts; only a Super Admin can call it.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000004401', 'care-admin@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000004402', 'care-patient@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000004403', 'plain-member@sukun.test', '{}');
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000004401', 'super_admin',
   '00000000-0000-4000-8000-000000004401'),
  ('00000000-0000-4000-8000-000000004402', 'patient',
   '00000000-0000-4000-8000-000000004401'),
  ('00000000-0000-4000-8000-000000004403', 'member',
   '00000000-0000-4000-8000-000000004401')
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000004401', true);

select ok(
  exists (select 1 from public.admin_list_care_recipients(null, 100, 0)
          where user_id = '00000000-0000-4000-8000-000000004402'),
  'a patient account is listed');

select ok(
  not exists (select 1 from public.admin_list_care_recipients(null, 100, 0)
              where user_id = '00000000-0000-4000-8000-000000004403'),
  'a plain member is not listed without a search');

select ok(
  not exists (select 1 from public.admin_list_care_recipients(null, 100, 0)
              where user_id = '00000000-0000-4000-8000-000000004401'),
  'admins are never listed');

select ok(
  exists (select 1 from public.admin_list_care_recipients('plain-member', 100, 0)
          where user_id = '00000000-0000-4000-8000-000000004403'),
  'search by email reaches a plain member');

select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000004403', true);

select throws_ok(
  $$ select * from public.admin_list_care_recipients(null, 10, 0) $$,
  '42501', null, 'a member cannot list people');

reset role;
set local role anon;
select throws_ok(
  $$ select * from public.admin_list_care_recipients(null, 10, 0) $$,
  '42501', null, 'anon cannot call it');

select * from finish();
rollback;
