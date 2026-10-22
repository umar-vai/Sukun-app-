-- Synthetic rollback-only RLS test. Never uses production patient data.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id,email,raw_user_meta_data) values
 ('e0000000-0000-4000-8000-000000000501','challenge-alice@sukun.test','{}'::jsonb),
 ('e0000000-0000-4000-8000-000000000502','challenge-bob@sukun.test','{}'::jsonb);

select ok((select relrowsecurity from pg_class
    where oid='public.challenge_enrollments'::regclass),
    'enrollment RLS is enabled');
select ok((select relrowsecurity from pg_class
    where oid='public.challenge_day_checkins'::regclass),
    'check-in RLS is enabled');
select ok(not has_table_privilege('anon','public.challenge_enrollments','SELECT'),
    'anon cannot list enrollment');
select ok(not has_table_privilege('anon','public.challenge_day_checkins','SELECT'),
    'anon cannot list check-ins');

set local role authenticated;
select set_config('request.jwt.claim.sub',
    'e0000000-0000-4000-8000-000000000501',true);
select lives_ok($$
  insert into public.challenge_enrollments(user_id,challenge_key)
  values ('e0000000-0000-4000-8000-000000000501','sukun_40_day')
$$,'member A may join own free challenge');

select lives_ok($$
  insert into public.challenge_day_checkins(user_id,challenge_key,day_number)
  values ('e0000000-0000-4000-8000-000000000501','sukun_40_day',1)
$$,'member A may save own first day');
select is((select count(*) from public.challenge_day_checkins),
    1::bigint,'A sees own checkin');

select set_config('request.jwt.claim.sub',
    'e0000000-0000-4000-8000-000000000502',true);
select is((select count(*) from public.challenge_enrollments),
    0::bigint,'B cannot read A enrollment');
select is((select count(*) from public.challenge_day_checkins),
    0::bigint,'B cannot read A day');
select throws_ok($$
  insert into public.challenge_enrollments(user_id,challenge_key)
  values ('e0000000-0000-4000-8000-000000000501','sukun_40_day')
$$,'42501','new row violates row-level security policy for table "challenge_enrollments"',
'B cannot enroll as A');
select throws_ok($$
  insert into public.challenge_day_checkins(user_id,challenge_key,day_number)
  values ('e0000000-0000-4000-8000-000000000501','sukun_40_day',2)
$$,'42501','new row violates row-level security policy for table "challenge_day_checkins"',
'B cannot add day into A tracker');
select is((select count(*) from public.challenge_day_checkins
    where user_id='e0000000-0000-4000-8000-000000000501'),
    0::bigint,'B cannot bypass check-in filter');

select * from finish();
rollback;
