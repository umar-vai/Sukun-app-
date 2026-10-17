-- All mutations are synthetic, transaction-scoped, and rolled back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id,email,raw_user_meta_data) values
 ('f0000000-0000-4000-8000-000000001241','routine-owner-a@sukun.test','{}'::jsonb),
 ('f0000000-0000-4000-8000-000000001242','routine-owner-b@sukun.test','{}'::jsonb);

select ok(
  (select relrowsecurity from pg_class
   where oid='public.personal_routine_action_resources'::regclass),
  'multi-resource links have RLS enabled'
);
select ok(
  not has_table_privilege('anon','public.personal_routine_action_resources','SELECT'),
  'guest cannot read personal action resources'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000001241',true);

select lives_ok($$
  insert into public.personal_routines(id,owner_user_id,title)
  values('f1000000-0000-4000-8000-000000001241',
         'f0000000-0000-4000-8000-000000001241','Synthetic Action')
$$,'owner can create their own routine');
select lives_ok($$
  insert into public.personal_routine_actions
    (id,routine_id,owner_user_id,title,notification_title)
  values('f2000000-0000-4000-8000-000000001241',
         'f1000000-0000-4000-8000-000000001241',
         'f0000000-0000-4000-8000-000000001241',
         'Synthetic action','Synthetic reminder')
$$,'owner can create action');

select lives_ok($$
  select public.replace_personal_action_resources(
    'f2000000-0000-4000-8000-000000001241'::uuid,
    '[{"provider":"quran","external_resource_ref":"quran:2"},
      {"provider":"hadith","external_resource_ref":"hadith:sample"}]'::jsonb)
$$,'owner can order canonical references without storing scriptural text');

select is((select count(*) from public.personal_routine_action_resources),
          2::bigint,'owner sees their two ordered links');

select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000001242',true);
select is((select count(*) from public.personal_routine_action_resources),
          0::bigint,'different member sees zero resource links');
select throws_ok($$
  select public.replace_personal_action_resources(
    'f2000000-0000-4000-8000-000000001241'::uuid,'[]'::jsonb)
$$,'42501','Not authorized to edit this routine action',
'non-owner cannot replace another user action resources');
select is((select count(*) from public.personal_routine_actions),
          0::bigint,'different member sees zero routine actions');

select * from finish();
rollback;
