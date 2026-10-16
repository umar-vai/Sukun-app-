-- Synthetic regression only. Rolls back all seed records.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id,email,raw_user_meta_data) values
('a0000000-0000-4000-8000-000000000201','empty-draft-admin@sukun.test','{}'::jsonb);
insert into public.user_roles (user_id,role,granted_by) values
('a0000000-0000-4000-8000-000000000201','super_admin','a0000000-0000-4000-8000-000000000201');

insert into public.patients (id,patient_code,full_name,created_by) values
('a1000000-0000-4000-8000-000000000201','SYN-EMPTY-201','Synthetic Patient Empty','a0000000-0000-4000-8000-000000000201'),
('a1000000-0000-4000-8000-000000000202','SYN-LINKED-202','Synthetic Patient Linked','a0000000-0000-4000-8000-000000000201');

insert into public.care_plans (id,patient_id,prescription_id,version,name,start_date,status,created_by) values
('a3000000-0000-4000-8000-000000000201','a1000000-0000-4000-8000-000000000201',null,1,'Already Empty',current_date,'draft','a0000000-0000-4000-8000-000000000201');

insert into public.prescription_attachments (
  id,patient_id,uploaded_by,storage_path,original_filename,mime_type,
  byte_size,extraction_status,processing_request_id,processing_started_at
) values
('a4000000-0000-4000-8000-000000000201','a1000000-0000-4000-8000-000000000201','a0000000-0000-4000-8000-000000000201','synthetic/prescription-empty-201.pdf','test.pdf','application/pdf',600,'processing','a5000000-0000-4000-8000-000000000201',now());

select lives_ok(
  $$select public.finalize_prescription_attachment(
    'a4000000-0000-4000-8000-000000000201',
    'a0000000-0000-4000-8000-000000000201',
    'a5000000-0000-4000-8000-000000000201',
    'Synthetic: do a previously specified safe practice',
    '{"status":"generated","actions":[]}'::jsonb,
    'synthetic-model'
  )$$,
  'first PDF is finalized using an existing empty unlinked draft'
);
select results_eq(
  $$select count(*) from public.care_plans where patient_id='a1000000-0000-4000-8000-000000000201'$$,
  array[1::bigint], 'no duplicate plan for same patient'
);
select results_eq(
  $$select (prescription_id is not null) from public.care_plans where id='a3000000-0000-4000-8000-000000000201'$$,
  array[true], 'unlinked draft now links to the preserved prescription'
);
select results_eq(
  $$select extraction_status || ':' || care_plan_id::text from public.prescription_attachments where id='a4000000-0000-4000-8000-000000000201'$$,
  array['succeeded:a3000000-0000-4000-8000-000000000201'], 'stored upload finalized against same draft'
);
select results_eq(
  $$select count(*) from public.prescription_versions pv join public.care_plans cp on cp.prescription_id=pv.prescription_id where cp.id='a3000000-0000-4000-8000-000000000201'$$,
  array[1::bigint], 'original extracted prescription is versioned exactly once'
);
select results_eq(
  $$select count(*) from public.admin_audit_logs where action='care_plan.draft_linked' and request_id='a5000000-0000-4000-8000-000000000201'$$,
  array[1::bigint], 'existing draft linking is audited'
);
select results_eq(
  $$select count(*) from public.ai_generation_requests where request_id='a5000000-0000-4000-8000-000000000201' and status='succeeded'$$,
  array[1::bigint], 'generation request is recorded only after safe finalization'
);
select results_eq(
  $$select count(*) from public.plan_actions where care_plan_id='a3000000-0000-4000-8000-000000000201'$$,
  array[0::bigint], 'AI suggestions are not automatically published as actions'
);

-- A linked empty draft from a DIFFERENT prescription must remain protected.
insert into public.prescriptions (id,patient_id,source_type,raw_text,visibility,created_by) values
('a2000000-0000-4000-8000-000000000202','a1000000-0000-4000-8000-000000000202','manual','Synthetic existing prescription','patient','a0000000-0000-4000-8000-000000000201');
insert into public.care_plans (id,patient_id,prescription_id,version,name,start_date,status,created_by) values
('a3000000-0000-4000-8000-000000000202','a1000000-0000-4000-8000-000000000202','a2000000-0000-4000-8000-000000000202',1,'Linked Draft',current_date,'draft','a0000000-0000-4000-8000-000000000201');
insert into public.prescription_attachments (
  id,patient_id,uploaded_by,storage_path,original_filename,mime_type,
  byte_size,extraction_status,processing_request_id,processing_started_at
) values
('a4000000-0000-4000-8000-000000000202','a1000000-0000-4000-8000-000000000202','a0000000-0000-4000-8000-000000000201','synthetic/prescription-linked-202.pdf','other.pdf','application/pdf',601,'processing','a5000000-0000-4000-8000-000000000202',now());
select throws_ok(
  $$select public.finalize_prescription_attachment(
    'a4000000-0000-4000-8000-000000000202',
    'a0000000-0000-4000-8000-000000000201',
    'a5000000-0000-4000-8000-000000000202',
    'Synthetic other instructions',
    '{"status":"generated","actions":[]}'::jsonb,
    'synthetic-model'
  )$$,
  '55000',
  'This patient already has an empty draft from another prescription. Review or finish that draft before importing a different prescription.',
  'linked existing draft must NOT be replaced by unrelated PDF'
);
select results_eq(
  $$select prescription_id::text from public.care_plans where id='a3000000-0000-4000-8000-000000000202'$$,
  array['a2000000-0000-4000-8000-000000000202'::text],
  'rejected finalize preserves existing linked draft'
);
select * from finish();
rollback;
