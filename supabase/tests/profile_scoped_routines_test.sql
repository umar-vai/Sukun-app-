-- Routines and the 40 day challenge are per profile inside a family login.
begin;

create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, phone) values
  ('00000000-0000-4000-8000-000000000d01', '+8801700000d01'),
  ('00000000-0000-4000-8000-000000000d02', '+8801700000d02'),
  ('00000000-0000-4000-8000-000000000d03', '+8801700000d03');
insert into public.user_roles (user_id, role) values
  ('00000000-0000-4000-8000-000000000d01', 'super_admin'),
  ('00000000-0000-4000-8000-000000000d02', 'patient'),
  ('00000000-0000-4000-8000-000000000d03', 'patient')
on conflict do nothing;
insert into public.patients (id, user_id, patient_code, full_name, created_by) values
  ('10000000-0000-4000-8000-0000000da001', '00000000-0000-4000-8000-000000000d02', 'PR-1', 'Owner', '00000000-0000-4000-8000-000000000d01'),
  ('10000000-0000-4000-8000-0000000da002', null, 'PR-2', 'Child', '00000000-0000-4000-8000-000000000d01'),
  ('10000000-0000-4000-8000-0000000da003', '00000000-0000-4000-8000-000000000d03', 'PR-3', 'Other family', '00000000-0000-4000-8000-000000000d01');
insert into public.family_accounts (id, owner_user_id, created_by) values
  ('20000000-0000-4000-8000-0000000da001', '00000000-0000-4000-8000-000000000d02', '00000000-0000-4000-8000-000000000d01');
insert into public.family_members (family_id, patient_id) values
  ('20000000-0000-4000-8000-0000000da001', '10000000-0000-4000-8000-0000000da001'),
  ('20000000-0000-4000-8000-0000000da001', '10000000-0000-4000-8000-0000000da002');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000d02', true);

-- Routines.
select lives_ok($$insert into public.personal_routines (owner_user_id, title, patient_id) values ('00000000-0000-4000-8000-000000000d02', 'Child routine', '10000000-0000-4000-8000-0000000da002')$$, 'a routine can be created for a linked profile');
select lives_ok($$insert into public.personal_routines (owner_user_id, title) values ('00000000-0000-4000-8000-000000000d02', 'Legacy style routine')$$, 'an older client that sends no profile still works');
select results_eq($$select patient_id from public.personal_routines where title = 'Legacy style routine'$$, array['10000000-0000-4000-8000-0000000da001'::uuid], 'a missing profile defaults to the owner profile');
select results_eq($$select count(*) from public.personal_routines where patient_id = '10000000-0000-4000-8000-0000000da002'$$, array[1::bigint], 'the child profile sees only its own routine');
select results_eq($$select count(*) from public.personal_routines where patient_id = '10000000-0000-4000-8000-0000000da001'$$, array[1::bigint], 'the owner profile sees only its own routine');
select throws_ok($$insert into public.personal_routines (owner_user_id, title, patient_id) values ('00000000-0000-4000-8000-000000000d02', 'Forged', '10000000-0000-4000-8000-0000000da003')$$, '42501', null, 'a routine cannot be created for a profile of another family');

-- Challenge, once per profile.
select lives_ok($$insert into public.challenge_enrollments (user_id, challenge_key, started_on, paused_days, patient_id) values ('00000000-0000-4000-8000-000000000d02', 'sukun_40_day', current_date, 0, '10000000-0000-4000-8000-0000000da002')$$, 'the child profile starts the challenge');
select lives_ok($$insert into public.challenge_enrollments (user_id, challenge_key, started_on, paused_days) values ('00000000-0000-4000-8000-000000000d02', 'sukun_40_day', current_date, 0)$$, 'the owner profile starts its own challenge without sending a profile');
select results_eq($$select count(*) from public.challenge_enrollments where user_id = '00000000-0000-4000-8000-000000000d02'$$, array[2::bigint], 'two independent enrollments under one login');
select lives_ok($$insert into public.challenge_day_checkins (user_id, challenge_key, day_number, patient_id) values ('00000000-0000-4000-8000-000000000d02', 'sukun_40_day', 1, '10000000-0000-4000-8000-0000000da002')$$, 'a day is completed for the child profile');
select results_eq($$select count(*) from public.challenge_day_checkins where patient_id = '10000000-0000-4000-8000-0000000da002'$$, array[1::bigint], 'the child has one completed day');
select results_eq($$select count(*) from public.challenge_day_checkins where patient_id = '10000000-0000-4000-8000-0000000da001'$$, array[0::bigint], 'the owner profile progress is untouched');
select throws_ok($$insert into public.challenge_enrollments (user_id, challenge_key, started_on, paused_days, patient_id) values ('00000000-0000-4000-8000-000000000d02', 'sukun_40_day', current_date, 0, '10000000-0000-4000-8000-0000000da003')$$, '42501', null, 'the challenge cannot be started for another family profile');
select throws_ok($$insert into public.challenge_enrollments (user_id, challenge_key, started_on, paused_days, patient_id) values ('00000000-0000-4000-8000-000000000d02', 'sukun_40_day', current_date, 0, '10000000-0000-4000-8000-0000000da002')$$, '23505', null, 'a profile cannot be enrolled twice');

select * from finish();
rollback;
