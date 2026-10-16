-- Synthetic only. The historical prescription and other draft remain intact.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id,email,raw_user_meta_data) values
('b0000000-0000-4000-8000-000000000301','recovery-admin@sukun.test','{}'::jsonb),
('b0000000-0000-4000-8000-000000000302','recovery-patient@sukun.test','{}'::jsonb);
insert into public.user_roles (user_id,role,granted_by) values
('b0000000-0000-4000-8000-000000000301','super_admin','b0000000-0000-4000-8000-000000000301'),
('b0000000-0000-4000-8000-000000000302','patient','b0000000-0000-4000-8000-000000000301');
insert into public.patients (id,patient_code,full_name,created_by) values
('b1000000-0000-4000-8000-000000000301','SYN-REC-301','Synthetic Recovery Empty','b0000000-0000-4000-8000-000000000301'),
('b1000000-0000-4000-8000-000000000302','SYN-REC-302','Synthetic Recovery Occupied','b0000000-0000-4000-8000-000000000301');
insert into public.prescriptions (id,patient_id,source_type,raw_text,visibility,created_by) values
('b2000000-0000-4000-8000-000000000301','b1000000-0000-4000-8000-000000000301','manual','Synthetic source A','patient','b0000000-0000-4000-8000-000000000301'),
('b2000000-0000-4000-8000-000000000302','b1000000-0000-4000-8000-000000000302','manual','Synthetic source B','patient','b0000000-0000-4000-8000-000000000301');
insert into public.care_plans (id,patient_id,prescription_id,version,name,start_date,status,created_by) values
('b3000000-0000-4000-8000-000000000301','b1000000-0000-4000-8000-000000000301','b2000000-0000-4000-8000-000000000301',1,'Empty linked draft',current_date,'draft','b0000000-0000-4000-8000-000000000301'),
('b3000000-0000-4000-8000-000000000302','b1000000-0000-4000-8000-000000000302','b2000000-0000-4000-8000-000000000302',1,'Occupied linked draft',current_date,'draft','b0000000-0000-4000-8000-000000000301');
insert into public.plan_actions (
  id,care_plan_id,type,title,frequency_rule,start_date,sort_order,review_status,created_by
) values (
  'b4000000-0000-4000-8000-000000000302',
  'b3000000-0000-4000-8000-000000000302',
  'recitation','Synthetic existing action',
  '{"type":"daily","interval":1}'::jsonb,current_date,1,'draft',
  'b0000000-0000-4000-8000-000000000301'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000302',true);
select throws_ok(
 $$select public.archive_empty_draft_for_prescription_import(
  'b1000000-0000-4000-8000-000000000301',
  'b3000000-0000-4000-8000-000000000301',
  'b5000000-0000-4000-8000-000000000301')$$,
 '42501','Super Admin access is required.',
 'patient cannot archive any draft'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000301',true);
select throws_ok(
 $$select public.archive_empty_draft_for_prescription_import(
  'b1000000-0000-4000-8000-000000000301',
  'b3000000-0000-4000-8000-000000000302',
  'b5000000-0000-4000-8000-000000000302')$$,
 'P0002','The selected draft was not found.',
 'cannot use a plan belonging to another patient'
);
select throws_ok(
 $$select public.archive_empty_draft_for_prescription_import(
  'b1000000-0000-4000-8000-000000000302',
  'b3000000-0000-4000-8000-000000000302',
  'b5000000-0000-4000-8000-000000000303')$$,
 '55000','This draft contains work. Review it instead of archiving automatically.',
 'even unapproved draft actions prohibit automatic archive'
);
select lives_ok(
 $$select public.archive_empty_draft_for_prescription_import(
  'b1000000-0000-4000-8000-000000000301',
  'b3000000-0000-4000-8000-000000000301',
  'b5000000-0000-4000-8000-000000000304')$$,
 'Super Admin can explicitly archive the existing actionless linked draft'
);
select results_eq(
 $$select status::text from public.care_plans
   where id='b3000000-0000-4000-8000-000000000301'$$,
 array['archived'::text],'only the selected empty draft is archived'
);
select results_eq(
 $$select published_at is null and published_by is null
   from public.care_plans
   where id='b3000000-0000-4000-8000-000000000301'$$,
 array[true],'an unapproved draft is not misrepresented as published'
);
select results_eq(
 $$select count(*) from public.prescriptions
   where id='b2000000-0000-4000-8000-000000000301' and archived_at is null$$,
 array[1::bigint],'original source prescription stays unchanged'
);
select results_eq(
 $$select count(*) from public.plan_actions
   where care_plan_id='b3000000-0000-4000-8000-000000000302'$$,
 array[1::bigint],'unrelated existing actions remain untouched'
);
select results_eq(
 $$select status::text from public.care_plans
   where id='b3000000-0000-4000-8000-000000000302'$$,
 array['draft'::text],'other patient draft remains open'
);
select lives_ok(
 $$select public.archive_empty_draft_for_prescription_import(
  'b1000000-0000-4000-8000-000000000301',
  'b3000000-0000-4000-8000-000000000301',
  'b5000000-0000-4000-8000-000000000304')$$,
 'retry with the same request is idempotent'
);
select results_eq(
 $$select count(*) from public.admin_audit_logs
   where action='care_plan.empty_draft_archived_for_import'
   and request_id='b5000000-0000-4000-8000-000000000304'$$,
 array[1::bigint],'recovery action is audited once'
);
select throws_ok(
 $$select public.archive_empty_draft_for_prescription_import(
  'b1000000-0000-4000-8000-000000000301',
  'b3000000-0000-4000-8000-000000000301',
  'b5000000-0000-4000-8000-000000000305')$$,
 '55000','Only a draft can be cleared for a new prescription.',
 'archived draft cannot be archived by a new unrelated request'
);
select * from finish();
rollback;
