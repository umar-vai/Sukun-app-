begin;

create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, raw_user_meta_data) values
  ('90000000-0000-4000-8000-000000000101', 'retry-admin@sukun.test', '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values (
  '90000000-0000-4000-8000-000000000101',
  'super_admin',
  '90000000-0000-4000-8000-000000000101'
);

insert into public.patients (
  id, patient_code, full_name, created_by
) values (
  '91000000-0000-4000-8000-000000000101',
  'RETRY-PATIENT-1',
  'Retry Patient',
  '90000000-0000-4000-8000-000000000101'
);

insert into public.prescriptions (
  id, patient_id, source_type, raw_text, visibility, created_by
) values (
  '92000000-0000-4000-8000-000000000101',
  '91000000-0000-4000-8000-000000000101',
  'imported',
  'Source text',
  'patient',
  '90000000-0000-4000-8000-000000000101'
);

insert into public.prescription_versions (
  prescription_id, version, raw_text, visibility, created_by
) values (
  '92000000-0000-4000-8000-000000000101',
  1,
  'Source text',
  'patient',
  '90000000-0000-4000-8000-000000000101'
);

insert into public.care_plans (
  id, patient_id, prescription_id, version, name, start_date, status, created_by
) values (
  '93000000-0000-4000-8000-000000000101',
  '91000000-0000-4000-8000-000000000101',
  '92000000-0000-4000-8000-000000000101',
  1,
  'Care Plan',
  current_date,
  'draft',
  '90000000-0000-4000-8000-000000000101'
);

insert into public.prescription_attachments (
  id, patient_id, prescription_id, care_plan_id, uploaded_by,
  storage_path, original_filename, mime_type, byte_size,
  extraction_status, normalized_result, processed_at
) values (
  '94000000-0000-4000-8000-000000000101',
  '91000000-0000-4000-8000-000000000101',
  '92000000-0000-4000-8000-000000000101',
  '93000000-0000-4000-8000-000000000101',
  '90000000-0000-4000-8000-000000000101',
  'retry/source-1.pdf',
  'pres.pdf',
  'application/pdf',
  391275,
  'succeeded',
  '{"status":"generated","actions":[]}'::jsonb,
  now()
), (
  '94000000-0000-4000-8000-000000000102',
  '91000000-0000-4000-8000-000000000101',
  null,
  null,
  '90000000-0000-4000-8000-000000000101',
  'retry/source-2.pdf',
  'pres.pdf',
  'application/pdf',
  391275,
  'processing',
  null,
  null
);

update public.prescription_attachments
set processing_request_id = '95000000-0000-4000-8000-000000000101',
    processing_started_at = now()
where id = '94000000-0000-4000-8000-000000000102';

select lives_ok(
  $$select public.finalize_prescription_attachment(
    '94000000-0000-4000-8000-000000000102',
    '90000000-0000-4000-8000-000000000101',
    '95000000-0000-4000-8000-000000000101',
    'Source text',
    '{"status":"generated","actions":[]}'::jsonb,
    'test-model'
  )$$,
  'same-file retry reuses the existing empty draft safely'
);

select results_eq(
  $$select count(*) from public.care_plans
    where patient_id='91000000-0000-4000-8000-000000000101'$$,
  array[1::bigint],
  'same-file retry does not create a second care plan'
);

select results_eq(
  $$select count(*) from public.prescriptions
    where patient_id='91000000-0000-4000-8000-000000000101'$$,
  array[1::bigint],
  'same-file retry does not duplicate the prescription'
);

select results_eq(
  $$select extraction_status || ':' || care_plan_id::text
    from public.prescription_attachments
    where id='94000000-0000-4000-8000-000000000102'$$,
  array['succeeded:93000000-0000-4000-8000-000000000101'::text],
  'retry attachment is finalized against the existing draft'
);

select results_eq(
  $$select count(*) from public.ai_generation_requests
    where request_id='95000000-0000-4000-8000-000000000101'$$,
  array[1::bigint],
  'retry still records its AI generation request'
);

select results_eq(
  $$select count(*) from public.admin_audit_logs
    where action='prescription_attachment.retry_reused'
      and request_id='95000000-0000-4000-8000-000000000101'$$,
  array[1::bigint],
  'same-file retry reuse is audited'
);

select * from finish();
rollback;
