-- Phase 1 / 2: grant least privilege to new server-provisioned Patients.
-- The public Auth signup trigger provision_public_member adds the nonclinical
-- member role to every newly created Auth user, including an Auth user that
-- will become a Patient. The service-only finalizer must remove that temporary
-- grant atomically once a verified Super Admin creates the Patient record.
-- Existing Patient roles are not altered in this shared migration: previous
-- data is reconciled only on the isolated staging project after QA validation.

create or replace function public.finalize_patient_provisioning(
  p_actor_user_id uuid,
  p_patient_user_id uuid,
  p_full_name text,
  p_phone text,
  p_patient_code text,
  p_request_id uuid
)
returns public.patients
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_patient_id uuid;
  created_patient public.patients%rowtype;
begin
  if not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_actor_user_id
      and ur.role = 'super_admin'
  ) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'A request identifier is required.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  select aal.entity_id
    into existing_patient_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = p_actor_user_id
    and aal.action = 'patient.created'
    and aal.request_id = p_request_id;

  if existing_patient_id is not null then
    select p.* into created_patient
    from public.patients p
    where p.id = existing_patient_id;
    if found then
      return created_patient;
    end if;
  end if;

  if not exists (
    select 1 from auth.users u where u.id = p_patient_user_id
  ) then
    raise exception 'The patient account was not found.' using errcode = 'P0002';
  end if;

  insert into public.profiles (
    id, display_name, requires_credential_change
  ) values (
    p_patient_user_id, btrim(p_full_name), true
  )
  on conflict (id) do update
  set display_name = excluded.display_name,
      requires_credential_change = true;

  insert into public.user_roles (user_id, role, granted_by)
  values (p_patient_user_id, 'patient', p_actor_user_id)
  on conflict (user_id, role) do nothing;

  insert into public.patients (
    user_id, patient_code, full_name, phone, created_by
  ) values (
    p_patient_user_id,
    upper(btrim(p_patient_code)),
    btrim(p_full_name),
    p_phone,
    p_actor_user_id
  )
  returning * into created_patient;

  -- Auth signup provisions a nonclinical member role by default. A
  -- Super Admin-created Patient has one clinical role, not a leftover
  -- member grant. This is performed inside the same transaction as the
  -- patient record so failures roll back every role change.
  delete from public.user_roles
  where user_id = p_patient_user_id
    and role = 'member'::public.app_role;

  insert into public.admin_audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    patient_id,
    request_id,
    metadata
  ) values (
    p_actor_user_id,
    'patient.created',
    'patient',
    created_patient.id,
    created_patient.id,
    p_request_id,
    jsonb_build_object('account_user_id', p_patient_user_id)
  );

  return created_patient;
end;
$$;

-- The existing service_role-only EXECUTE grant/revocations are unchanged
-- by CREATE OR REPLACE FUNCTION. No privilege is made available to clients.
comment on function public.finalize_patient_provisioning(
  uuid, uuid, text, text, text, uuid
) is
  'Service-only, atomic Patient provisioning; strips Auth signup member grant after successful Patient creation while retaining idempotent audit trail.';
