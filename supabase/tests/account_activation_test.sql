-- One-time account activation: single use, expiry, resend, existing accounts.
begin;

create extension if not exists pgtap with schema extensions;
select plan(19);

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

-- Provision a new login (profile row + role) and a login-less family profile.
select lives_ok($$select public.integration_provision_patient('00000000-0000-4000-8000-000000000c01', '00000000-0000-4000-8000-000000000c02', 'New Patient', '+8801700000c02', 'ACT-NEW', '90000000-0000-4000-8000-0000000cb001')$$, 'new login is provisioned');
select ok((select requires_credential_change from public.profiles where id = '00000000-0000-4000-8000-000000000c02'), 'a new account must set its own password');
select results_eq($$select count(*) from public.user_roles where user_id = '00000000-0000-4000-8000-000000000c02' and role = 'patient'$$, array[1::bigint], 'patient role granted');
select lives_ok($$select public.integration_provision_patient('00000000-0000-4000-8000-000000000c01', '00000000-0000-4000-8000-000000000c02', 'New Patient', '+8801700000c02', 'ACT-NEW', '90000000-0000-4000-8000-0000000cb001')$$, 'provisioning is idempotent by request id');
select results_eq($$select count(*) from public.patients where patient_code = 'ACT-NEW'$$, array[1::bigint], 'no duplicate patient');
select ok((select user_id is null from public.integration_provision_patient('00000000-0000-4000-8000-000000000c01', null, 'Family Member', null, 'ACT-FAM', '90000000-0000-4000-8000-0000000cb002')), 'a login-less family profile has no account');
select throws_ok($$select public.integration_provision_patient('00000000-0000-4000-8000-000000000c02', null, 'X', null, 'ACT-X', gen_random_uuid())$$, '42501', null, 'a non-staff actor is refused');

-- Issue, resend, consume.
select results_eq($$select (public.integration_issue_activation('00000000-0000-4000-8000-000000000c01', p.id, repeat('a', 64), '8801700000000', 60)) ->> 'status' from public.patients p where p.patient_code = 'ACT-NEW'$$, array['issued'::text], 'a link is issued for a new account');
select results_eq($$select (public.integration_issue_activation('00000000-0000-4000-8000-000000000c01', p.id, repeat('b', 64), null, 60)) ->> 'status' from public.patients p where p.patient_code = 'ACT-NEW'$$, array['issued'::text], 'a resend issues a new link');
select ok(public.integration_consume_activation(repeat('a', 64)) is null, 'the older link no longer works after a resend');
select results_eq($$select (public.integration_consume_activation(repeat('b', 64))) ->> 'patient_code'$$, array['ACT-NEW'::text], 'the latest link is accepted once');
select ok(public.integration_consume_activation(repeat('b', 64)) is null, 'a used link cannot be replayed');
select ok(public.integration_consume_activation(repeat('c', 64)) is null, 'an unknown token gets the same empty answer');
select ok(public.integration_consume_activation('short') is null, 'a malformed token is refused');
select ok((select public.integration_reopen_activation(id) from public.account_activations where token_hash = repeat('b', 64)), 'a spent link can be reopened if setting the password failed');
select ok(public.integration_consume_activation(repeat('b', 64)) is not null, 'the reopened link works once more');

-- Expiry.
select lives_ok($$select public.integration_issue_activation('00000000-0000-4000-8000-000000000c01', p.id, repeat('d', 64), null, 5) from public.patients p where p.patient_code = 'ACT-NEW'$$, 'a short lived link is issued');
update public.account_activations set expires_at = now() - interval '1 minute' where token_hash = repeat('d', 64);
select ok(public.integration_consume_activation(repeat('d', 64)) is null, 'an expired link is rejected');

-- Existing accounts keep their password.
select results_eq($$select (public.integration_issue_activation('00000000-0000-4000-8000-000000000c01', '10000000-0000-4000-8000-0000000ca003', repeat('e', 64), null, 60)) ->> 'status'$$, array['already_active'::text], 'an already activated account never gets a link');

select * from finish();
rollback;
