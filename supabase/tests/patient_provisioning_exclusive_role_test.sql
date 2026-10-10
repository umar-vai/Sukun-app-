begin;

-- Dedicated role-isolation regression. All Auth users here are synthetic,
-- created in the disposable test database and rolled back.
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000b401', 'qa-admin@invalid.test',
   '{}'::jsonb),
  ('00000000-0000-4000-8000-00000000b402', 'qa-patient@invalid.test',
   '{"role":"super_admin"}'::jsonb),
  ('00000000-0000-4000-8000-00000000b403', 'qa-member@invalid.test',
   '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-00000000b401', 'super_admin',
   '00000000-0000-4000-8000-00000000b401');

select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-00000000b402'$$,
  array['member'::text],
  'Auth signup safely defaults prospective patient to member'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.finalize_patient_provisioning(uuid,uuid,text,text,text,uuid)',
    'EXECUTE'
  ),
  'Flutter user cannot call service-role Patient provisioner'
);
select lives_ok(
  $$select public.finalize_patient_provisioning(
    '00000000-0000-4000-8000-00000000b401',
    '00000000-0000-4000-8000-00000000b402',
    'QA Synthetic Patient', '+8801710000000', 'QA-STAGE-B402',
    '70000000-0000-4000-8000-00000000b402'
  )$$,
  'Authorized Admin can finalize synthetic Patient provisioning'
);
select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-00000000b402'$$,
  array['patient'::text],
  'New Patient has exactly the patient role and no member grant'
);
select results_eq(
  $$select count(*) from public.user_roles
    where user_id='00000000-0000-4000-8000-00000000b402'
    and role='member'$$,
  array[0::bigint],
  'Unnecessary public Member grant is revoked atomically'
);
select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-00000000b403'$$,
  array['member'::text],
  'Independent Google-style Member role remains intact'
);
select results_eq(
  $$select role::text from public.user_roles
    where user_id='00000000-0000-4000-8000-00000000b401'
    and role='super_admin'$$,
  array['super_admin'::text],
  'Existing Admin privilege remains intact'
);
select results_eq(
  $$select requires_credential_change from public.profiles
    where id='00000000-0000-4000-8000-00000000b402'$$,
  array[true],
  'New Patient must change their temporary password'
);
select results_eq(
  $$select patient_code from public.patients
    where user_id='00000000-0000-4000-8000-00000000b402'$$,
  array['QA-STAGE-B402'::text],
  'Created Patient account remains associated with Auth identity'
);
select results_eq(
  $$select count(*) from public.admin_audit_logs
    where action='patient.created'
    and request_id='70000000-0000-4000-8000-00000000b402'$$,
  array[1::bigint],
  'Creation remains audited'
);
select lives_ok(
  $$select public.finalize_patient_provisioning(
    '00000000-0000-4000-8000-00000000b401',
    '00000000-0000-4000-8000-00000000b402',
    'Retry ignored', '+8801710000000', 'QA-STAGE-B402',
    '70000000-0000-4000-8000-00000000b402'
  )$$,
  'Idempotent retry returns original Patient without a second insertion'
);
select results_eq(
  $$select count(*) from public.patients
    where user_id='00000000-0000-4000-8000-00000000b402'$$,
  array[1::bigint],
  'Idempotent retry preserves exactly one Patient record'
);

select * from finish();
rollback;
