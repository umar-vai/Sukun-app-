begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000101', 'workflow-admin@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000111', 'workflow-patient@sukun.test', '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  (
    '00000000-0000-4000-8000-000000000101',
    'super_admin',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '00000000-0000-4000-8000-000000000111',
    'patient',
    '00000000-0000-4000-8000-000000000101'
  );

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values (
  '10000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000111',
  'TEST-WORKFLOW-1',
  'Workflow Patient',
  '00000000-0000-4000-8000-000000000101'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.finalize_patient_provisioning(uuid,uuid,text,text,text,uuid)',
    'EXECUTE'
  ),
  'patient provisioning finalizer is unavailable to Flutter clients'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000111',
  true
);

select throws_ok(
  $$select public.create_prescription(
    '10000000-0000-4000-8000-000000000101',
    'Patient must not create this',
    null,
    'patient',
    '70000000-0000-4000-8000-000000000101'
  )$$,
  '42501',
  'Super Admin access is required.',
  'patient cannot invoke the privileged prescription workflow'
);
select throws_ok(
  $$select * from public.admin_search_patients('Workflow', 20, 0)$$,
  '42501',
  'Super Admin access is required.',
  'patient cannot invoke the admin patient search'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select lives_ok(
  $$select public.create_prescription(
    '10000000-0000-4000-8000-000000000101',
    '  সকাল-সন্ধ্যা আয়াতুল কুরসি ৩ বার পড়বেন।  ',
    current_date,
    'patient',
    '70000000-0000-4000-8000-000000000102'
  )$$,
  'Super Admin can atomically capture a prescription'
);
select results_eq(
  $$select patient_code from public.admin_search_patients('workflow', 20, 0)$$,
  array['TEST-WORKFLOW-1'::text],
  'Super Admin search matches patient name or reference code'
);

select results_eq(
  $$select count(*) from public.prescriptions
    where patient_id = '10000000-0000-4000-8000-000000000101'$$,
  array[1::bigint],
  'one prescription is created'
);
select results_eq(
  $$select count(*) from public.prescription_versions pv
    join public.prescriptions p on p.id = pv.prescription_id
    where p.patient_id = '10000000-0000-4000-8000-000000000101'
      and pv.version = 1$$,
  array[1::bigint],
  'immutable prescription version 1 is created in the same transaction'
);
select results_eq(
  $$select raw_text from public.prescriptions
    where patient_id = '10000000-0000-4000-8000-000000000101'$$,
  array['সকাল-সন্ধ্যা আয়াতুল কুরসি ৩ বার পড়বেন।'::text],
  'prescription text is preserved without surrounding whitespace'
);
select results_eq(
  $$select count(*) from public.admin_audit_logs
    where action = 'prescription.created'
      and request_id = '70000000-0000-4000-8000-000000000102'$$,
  array[1::bigint],
  'sensitive admin action is audited'
);

select lives_ok(
  $$select public.create_prescription(
    '10000000-0000-4000-8000-000000000101',
    'This retry payload is ignored',
    null,
    'staff_only',
    '70000000-0000-4000-8000-000000000102'
  )$$,
  'retrying the same request identifier returns safely'
);
select results_eq(
  $$select count(*) from public.prescriptions
    where patient_id = '10000000-0000-4000-8000-000000000101'$$,
  array[1::bigint],
  'idempotent retry does not duplicate the prescription'
);

select * from finish();
rollback;
