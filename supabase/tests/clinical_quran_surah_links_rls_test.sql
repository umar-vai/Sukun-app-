begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users(id,email,raw_user_meta_data) values
 ('aa000000-0000-4000-8000-000000000001','quran-admin@sukun.test','{}'),
 ('aa000000-0000-4000-8000-000000000011','quran-patient-a@sukun.test','{}'),
 ('aa000000-0000-4000-8000-000000000012','quran-patient-b@sukun.test','{}'),
 ('aa000000-0000-4000-8000-000000000013','quran-member@sukun.test','{}');
insert into public.user_roles(user_id,role,granted_by) values
 ('aa000000-0000-4000-8000-000000000001','super_admin','aa000000-0000-4000-8000-000000000001'),
 ('aa000000-0000-4000-8000-000000000011','patient','aa000000-0000-4000-8000-000000000001'),
 ('aa000000-0000-4000-8000-000000000012','patient','aa000000-0000-4000-8000-000000000001');
insert into public.patients(id,user_id,patient_code,full_name,created_by) values
 ('ab000000-0000-4000-8000-000000000011','aa000000-0000-4000-8000-000000000011','QTEST-A','Quran Test A','aa000000-0000-4000-8000-000000000001'),
 ('ab000000-0000-4000-8000-000000000012','aa000000-0000-4000-8000-000000000012','QTEST-B','Quran Test B','aa000000-0000-4000-8000-000000000001');
insert into public.care_plans(id,patient_id,version,name,start_date,status,created_by) values
 ('ac000000-0000-4000-8000-000000000011','ab000000-0000-4000-8000-000000000011',1,'Plan A',current_date,'draft','aa000000-0000-4000-8000-000000000001'),
 ('ac000000-0000-4000-8000-000000000012','ab000000-0000-4000-8000-000000000012',1,'Plan B',current_date,'draft','aa000000-0000-4000-8000-000000000001');
insert into public.plan_actions(id,care_plan_id,type,title,frequency_rule,start_date,review_status,created_by) values
 ('ad000000-0000-4000-8000-000000000011','ac000000-0000-4000-8000-000000000011','quran','Read A','{"type":"daily"}',current_date,'approved','aa000000-0000-4000-8000-000000000001'),
 ('ad000000-0000-4000-8000-000000000012','ac000000-0000-4000-8000-000000000012','quran','Read B','{"type":"daily"}',current_date,'approved','aa000000-0000-4000-8000-000000000001');
insert into public.plan_action_quran_surahs(plan_action_id,surah_number,title,created_by) values
 ('ad000000-0000-4000-8000-000000000011',1,'Al-Fatihah','aa000000-0000-4000-8000-000000000001'),
 ('ad000000-0000-4000-8000-000000000012',114,'An-Nas','aa000000-0000-4000-8000-000000000001');
update public.care_plans set status='active',published_at=now(),
 published_by='aa000000-0000-4000-8000-000000000001'
where id in ('ac000000-0000-4000-8000-000000000011',
             'ac000000-0000-4000-8000-000000000012');
insert into public.care_plans(id,patient_id,version,name,start_date,status,created_by)
values('ac000000-0000-4000-8000-000000000013',
 'ab000000-0000-4000-8000-000000000011',2,'Plan A draft',current_date,
 'draft','aa000000-0000-4000-8000-000000000001');
insert into public.plan_actions(id,care_plan_id,type,title,frequency_rule,
 start_date,review_status,created_by)
values('ad000000-0000-4000-8000-000000000013',
 'ac000000-0000-4000-8000-000000000013','quran','Read draft',
 '{"type":"daily"}',current_date,'draft',
 'aa000000-0000-4000-8000-000000000001');

select ok((select relrowsecurity from pg_class
 where oid='public.plan_action_quran_surahs'::regclass),'chapter links use RLS');
select ok(not has_table_privilege('anon','public.plan_action_quran_surahs','SELECT'),
 'guest cannot read clinical chapter links');

set local role authenticated;
select set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000011',true);
select is((select count(*) from public.plan_action_quran_surahs),1::bigint,
 'patient A sees only own approved chapter');
select throws_ok($$select public.replace_draft_action_quran_surahs(
 'ad000000-0000-4000-8000-000000000013',
 '[{"number":2,"title":"Al-Baqarah"}]',
 'ae000000-0000-4000-8000-000000000011')$$,
 '42501','Super Admin access required.','patient cannot change draft links');

select set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000012',true);
select is((select count(*) from public.plan_action_quran_surahs),1::bigint,
 'patient B sees only own approved chapter');
select set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000013',true);
select is((select count(*) from public.plan_action_quran_surahs),0::bigint,
 'general member sees no clinical chapter links');

select set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000001',true);
select is(public.replace_draft_action_quran_surahs(
 'ad000000-0000-4000-8000-000000000013',
 '[{"number":2,"title":"Al-Baqarah"},{"number":114,"title":"An-Nas"}]',
 'ae000000-0000-4000-8000-000000000012'),2,
 'admin can link reviewed draft to two valid public chapters');
select throws_ok($$select public.replace_draft_action_quran_surahs(
 'ad000000-0000-4000-8000-000000000013',
 '[{"number":115,"title":"Invalid"}]',
 'ae000000-0000-4000-8000-000000000013')$$,
 '22023','Invalid Quran chapter.','invalid chapter is rejected');
select is((select count(*) from public.plan_action_quran_surahs
 where plan_action_id='ad000000-0000-4000-8000-000000000013'),2::bigint,
 'failed request preserves prior draft links');
select * from finish();
rollback;
