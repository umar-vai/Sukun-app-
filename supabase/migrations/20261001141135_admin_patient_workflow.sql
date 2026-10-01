-- Atomic, idempotent prescription capture for the Super Admin workflow.
-- Patient Auth provisioning remains in an Edge Function because auth.users
-- must only be managed with a server-held service-role credential.

create unique index admin_audit_logs_operation_request_key
  on public.admin_audit_logs (actor_user_id, action, request_id)
  where request_id is not null;

create or replace function public.create_prescription(
  p_patient_id uuid,
  p_raw_text text,
  p_session_date date default null,
  p_visibility public.record_visibility default 'patient',
  p_request_id uuid default gen_random_uuid()
)
returns public.prescriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  existing_prescription_id uuid;
  created_prescription public.prescriptions%rowtype;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'A request identifier is required.' using errcode = '22023';
  end if;

  if p_raw_text is null or btrim(p_raw_text) = '' then
    raise exception 'Prescription text is required.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  select aal.entity_id
    into existing_prescription_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'prescription.created'
    and aal.request_id = p_request_id;

  if existing_prescription_id is not null then
    select p.*
      into created_prescription
    from public.prescriptions p
    where p.id = existing_prescription_id;

    if found then
      return created_prescription;
    end if;
  end if;

  if not exists (
    select 1
    from public.patients p
    where p.id = p_patient_id
      and p.status = 'active'
  ) then
    raise exception 'An active patient was not found.' using errcode = 'P0002';
  end if;

  insert into public.prescriptions (
    patient_id,
    source_type,
    raw_text,
    session_date,
    visibility,
    created_by
  ) values (
    p_patient_id,
    'manual',
    btrim(p_raw_text),
    p_session_date,
    p_visibility,
    caller_user_id
  )
  returning * into created_prescription;

  insert into public.prescription_versions (
    prescription_id,
    version,
    raw_text,
    visibility,
    change_note,
    created_by
  ) values (
    created_prescription.id,
    1,
    created_prescription.raw_text,
    created_prescription.visibility,
    'Initial prescription capture',
    caller_user_id
  );

  insert into public.admin_audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    patient_id,
    request_id,
    metadata
  ) values (
    caller_user_id,
    'prescription.created',
    'prescription',
    created_prescription.id,
    created_prescription.patient_id,
    p_request_id,
    jsonb_build_object(
      'source_type', created_prescription.source_type,
      'visibility', created_prescription.visibility
    )
  );

  return created_prescription;
end;
$$;

revoke execute on function public.create_prescription(
  uuid, text, date, public.record_visibility, uuid
) from public, anon;
grant execute on function public.create_prescription(
  uuid, text, date, public.record_visibility, uuid
) to authenticated;

comment on function public.create_prescription(
  uuid, text, date, public.record_visibility, uuid
) is
  'Super Admin-only, idempotent prescription capture with immutable version 1 and an audit record.';

create or replace function public.admin_search_patients(
  p_query text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof public.patients
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  normalized_query text := nullif(btrim(p_query), '');
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;

  if p_limit < 1 or p_limit > 100 or p_offset < 0 then
    raise exception 'Invalid pagination.' using errcode = '22023';
  end if;

  return query
  select p.*
  from public.patients p
  where normalized_query is null
    or p.full_name ilike ('%' || normalized_query || '%')
    or p.patient_code ilike ('%' || normalized_query || '%')
    or coalesce(p.phone, '') ilike ('%' || normalized_query || '%')
  order by p.created_at desc, p.id
  limit p_limit
  offset p_offset;
end;
$$;

revoke execute on function public.admin_search_patients(text, integer, integer)
  from public, anon;
grant execute on function public.admin_search_patients(text, integer, integer)
  to authenticated;

comment on function public.admin_search_patients(text, integer, integer) is
  'Server-authorized Super Admin patient search with bounded pagination.';

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

revoke execute on function public.finalize_patient_provisioning(
  uuid, uuid, text, text, text, uuid
) from public, anon, authenticated;
grant execute on function public.finalize_patient_provisioning(
  uuid, uuid, text, text, text, uuid
) to service_role;

comment on function public.finalize_patient_provisioning(
  uuid, uuid, text, text, text, uuid
) is
  'Service-only transactional patient profile, role, record, and audit finalization after Auth account creation.';
