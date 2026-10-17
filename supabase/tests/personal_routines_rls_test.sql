-- Synthetic rollback-only test: self-created routines never expose clinical
-- plans or any other user's personal data.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id,email,raw_user_meta_data) values
 ('f0000000-0000-4000-8000-000000001211','routine-alice@sukun.test','{}'::jsonb),
 ('f0000000-0000-4000-8000-000000001212','routine-bob@sukun.test','{}'::jsonb);

select ok(
  (select relrowsecurity from pg_class
   where oid='public.personal_routines'::regclass),
  'personal routines have RLS'
);
select ok(
  (select relrowsecurity from pg_class
   where oid='public.personal_routine_actions'::regclass),
  'personal action rows have RLS'
);
select ok(
  (select relrowsecurity from pg_class
   where oid='public.personal_routine_progress'::regclass),
  'personal progress has RLS'
);
select ok(
  not has_table_privilege('anon','public.personal_routines','SELECT'),
  'guest cannot select private routines'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000001211',true);
select lives_ok($$
insert into public.personal_routines(id,owner_user_id,title)
values('f1000000-0000-4000-8000-000000001211',
       'f0000000-0000-4000-8000-000000001211','Synthetic Fajr')
$$,'member A may create their own routine');
select lives_ok($$
insert into public.personal_routine_actions
 (id,routine_id,owner_user_id,title,notification_title,schedule_kind,
  prayer_latitude,prayer_longitude,prayer_method,prayer_city,timezone_name)
values('f2000000-0000-4000-8000-000000001211',
       'f1000000-0000-4000-8000-000000001211',
       'f0000000-0000-4000-8000-000000001211',
       'Synthetic morning dua','Remember morning dua','fajr',
       23.8103,90.4125,'karachi','Dhaka','Asia/Dhaka')
$$,'member A may set a Fajr-relative preference');
select lives_ok($$
insert into public.personal_routine_progress
 (action_id,owner_user_id,local_date,outcome)
values('f2000000-0000-4000-8000-000000001211',
       'f0000000-0000-4000-8000-000000001211',
       current_date,'done')
$$,'member A may record their own completion');
select is((select count(*) from public.personal_routine_actions),
          1::bigint,'member A sees own action');

select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000001212',true);
select is((select count(*) from public.personal_routines),
          0::bigint,'member B cannot read member A routine');
select is((select count(*) from public.personal_routine_progress),
          0::bigint,'member B cannot read member A completion');
select throws_ok($$
insert into public.personal_routines(owner_user_id,title)
values('f0000000-0000-4000-8000-000000001211',
       'Illegally write into A')
$,'42501','new row violates row-level security policy for table "personal_routines"','member B cannot impersonate owner');

select * from finish();
rollback;
