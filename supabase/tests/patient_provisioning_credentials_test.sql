-- CRM provisioning with a temporary credential: idempotent, never resets an
-- activated account, family profiles have no login.
begin;

create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, phone) values
  ('00000000-0000-4000-8000-000000000c01', '+8801700000c01'),
  ('00000000-0000-4000-8000-000000000c02', '+8801700000c02'),
  ('00000000-0000-4000-8000-000000000c03', '+8801700000c03');
insert into public.user_roles (user_id, role) values
  ('00000000-0000-4000-8000-000000000c01', 'super_admin');
insert into public.profiles (id, requires_credential_change) values
  ('00000000-0000-4000-8000-000000000c03', false)
on conflict (id) do update set requires_credential_change = false;
insert into public.user_roles (user_id, role) values
  ('00000000-0000-4000-8000-000000000c03', 'patient')
on conflict do nothing;
insert into public.patients (id, user_id, patient_code, full_name, created_by) values
  ('10000000-0000-4000-8000-0000000ca003', '00000000-0000-4000-8000-000000000c03', 'ACT-OLD', 'Already Active', '00000000-0000-4000-8000-000000000c01');

select lives_ok($$select public.integration_provision_patient('00000000-0000-4000-8000-000000000c01', '00000000-0000-4000-8000-000000000c02', 'New Patient', '+8801700000c02', 'ACT-NEW', '90000000-0000-4000-8000-0000000cb001')$$, 'new login is provisioned');
select ok((select requires_credential_change from public.profiles where id = '00000000-0000-4000-8000-000000000c02'), 'a new account must change its temporary password');
select results_eq($$select count(*) from public.user_roles where user_id = '00000000-0000-4000-8000-000000000c02' and role = 'patient'$$, array[1::bigint], 'patient role granted');
select ok((select count(*) = 0 from public.user_roles where user_id = '00000000-0000-4000-8000-000000000c02' and role::text = 'member'), 'no leftover member role');
select lives_ok($$select public.integration_provision_patient('00000000-0000-4000-8000-000000000c01', '00000000-0000-4000-8000-000000000c02', 'New Patient', '+8801700000c02', 'ACT-NEW', '90000000-0000-4000-8000-0000000cb001')$$, 'provisioning is idempotent by request id');
select results_eq($$select count(*) from public.patients where patient_code = 'ACT-NEW'$$, array[1::bigint], 'no duplicate patient');
select ok((select user_id is null from public.integration_provision_patient('00000000-0000-4000-8000-000000000c01', null, 'Family Member', null, 'ACT-FAM', '90000000-0000-4000-8000-0000000cb002')), 'a family profile has no account of its own');
select throws_ok($$select public.integration_provision_patient('00000000-0000-4000-8000-000000000c02', null, 'X', null, 'ACT-X', gen_random_uuid())$$, '42501', null, 'a non-staff actor is refused');

select results_eq($$select (public.integration_patient_credential_state('00000000-0000-4000-8000-000000000c01', p.id)) ->> 'status' from public.patients p where p.patient_code = 'ACT-NEW'$$, array['needs_credentials'::text], 'a never activated account needs a credential');
select results_eq($$select (public.integration_patient_credential_state('00000000-0000-4000-8000-000000000c01', p.id)) ->> 'status' from public.patients p where p.patient_code = 'ACT-FAM'$$, array['no_login'::text], 'a family profile needs none');
select results_eq($$select (public.integration_patient_credential_state('00000000-0000-4000-8000-000000000c01', '10000000-0000-4000-8000-0000000ca003')) ->> 'status'$$, array['already_active'::text], 'an activated account is never reset');
select lives_ok($$select public.integration_record_credential_issue('00000000-0000-4000-8000-000000000c01', p.id, 'created') from public.patients p where p.patient_code = 'ACT-NEW'$$, 'issuing is audited');
select ok((select metadata::text not like '%password%' from public.admin_audit_logs where action = 'integration.credential_issued'), 'the audit row holds no password');

select * from finish();
rollback;
