-- Every fixture rolls back. A raqi added by the main admin gets the role on
-- sign-in, reaches patient care, and cannot change templates or staff.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000006601', 'staff-admin@sukun.test', now(), '{}'),
  ('00000000-0000-4000-8000-000000006603', 'plain-staff-member@sukun.test', now(), '{}');
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000006601', 'super_admin',
   '00000000-0000-4000-8000-000000006601')
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000006601', true);
select lives_ok(
  $$ select public.admin_add_raqi('New.Raqi@Gmail.com', null, 'Raqi') $$,
  'main admin adds a raqi by Gmail');
select throws_ok(
  $$ select public.admin_add_raqi('new.raqi@gmail.com') $$,
  '23505', null, 'the same Gmail cannot be added twice');
reset role;

-- The raqi signs in with Google for the first time.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000006602', 'new.raqi@gmail.com', now(), '{}');

select ok(exists (
  select 1 from public.user_roles
  where user_id = '00000000-0000-4000-8000-000000006602' and role::text = 'raqi'
), 'signing in with that Gmail grants the raqi role');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000006602', true);
select ok((select private.is_care_staff()), 'a raqi is care staff');
select lives_ok(
  $$ select * from public.admin_list_care_recipients(null, 10, 0) $$,
  'a raqi lists patients');
select throws_ok(
  $$ select public.admin_save_care_template(
       '{"id":"a01","category":"amal","title":"x","instruction":"y"}') $$,
  '42501', null, 'a raqi cannot edit official templates');
select throws_ok(
  $$ select public.admin_add_raqi('another@gmail.com') $$,
  '42501', null, 'a raqi cannot add staff');

select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000006603', true);
select throws_ok(
  $$ select * from public.admin_list_care_recipients(null, 10, 0) $$,
  '42501', null, 'an ordinary member is not care staff');

select * from finish();
rollback;
