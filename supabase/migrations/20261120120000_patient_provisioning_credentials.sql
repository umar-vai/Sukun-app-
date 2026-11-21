-- CRM patient provisioning with a generated temporary credential (phase 4).
--
-- OWNER DECISION 2026-11-20: no WhatsApp integration for now. SukunLife
-- generates the patient ID and a temporary password; staff send them to the
-- patient by hand. The CRM never supplies a password, and the temporary one
-- forces a change at first login (existing `profiles.requires_credential_change`
-- flow), after which the patient owns a permanent password nobody else knows.
--
-- DESIGN
--   * `integration_provision_patient` creates the patient row for an
--     integration actor (staff), with or without a login (a profile without a
--     login is a family member). Idempotent by request id.
--   * `integration_patient_credential_state` tells the gateway whether this
--     profile needs a temporary credential. An already activated account
--     (requires_credential_change = false) is NEVER given a new password, so an
--     existing permanent password cannot be reset by a new CRM prescription.
--   * `integration_record_credential_issue` writes the audit row. The password
--     itself is never stored or logged anywhere in SukunLife.
--   * Service role only.
--
-- ROLLBACK
--   drop function public.integration_provision_patient,
--   public.integration_patient_credential_state,
--   public.integration_record_credential_issue, private.require_integration_actor;

create or replace function private.require_integration_actor(p_actor uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_actor is null or not exists (
    select 1 from public.user_roles
    where user_id = p_actor and role::text in ('super_admin', 'raqi')
  ) then
    raise exception 'A staff service actor is required.' using errcode = '42501';
  end if;
end;
$$;

-- Creates (or returns, by request id) the patient row. p_user_id null makes a
-- login-less family profile.
create or replace function public.integration_provision_patient(
  p_actor_user_id uuid,
  p_user_id uuid,
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
  existing uuid;
  created public.patients%rowtype;
begin
  perform private.require_integration_actor(p_actor_user_id);
  if p_request_id is null or nullif(btrim(p_full_name), '') is null
     or nullif(btrim(p_patient_code), '') is null then
    raise exception 'Name, patient code and request id are required.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('provision:' || p_request_id::text, 0));

  select entity_id into existing from public.admin_audit_logs
  where actor_user_id = p_actor_user_id and action = 'patient.created'
    and request_id = p_request_id;
  if existing is not null then
    select * into created from public.patients where id = existing;
    if found then return created; end if;
  end if;

  if p_user_id is not null then
    if not exists (select 1 from auth.users where id = p_user_id) then
      raise exception 'The patient account was not found.' using errcode = 'P0002';
    end if;
    insert into public.profiles (id, display_name, requires_credential_change)
    values (p_user_id, btrim(p_full_name), true)
    on conflict (id) do update
      set display_name = excluded.display_name, requires_credential_change = true;
    insert into public.user_roles (user_id, role, granted_by)
    values (p_user_id, 'patient', p_actor_user_id)
    on conflict (user_id, role) do nothing;
    delete from public.user_roles
    where user_id = p_user_id and role = 'member'::public.app_role;
  end if;

  insert into public.patients (user_id, patient_code, full_name, phone, created_by)
  values (p_user_id, upper(btrim(p_patient_code)), btrim(p_full_name),
    nullif(btrim(p_phone), ''), p_actor_user_id)
  returning * into created;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, request_id, metadata)
  values (p_actor_user_id, 'patient.created', 'patient', created.id, created.id,
    p_request_id, jsonb_build_object('account_user_id', p_user_id, 'via', 'crm'));
  return created;
end;
$$;

create or replace function public.integration_patient_credential_state(
  p_actor_user_id uuid, p_patient_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pat public.patients%rowtype;
  must_change boolean;
begin
  perform private.require_integration_actor(p_actor_user_id);
  select * into pat from public.patients where id = p_patient_id and status = 'active';
  if not found then
    raise exception 'Patient profile was not found.' using errcode = 'P0002';
  end if;
  if pat.user_id is null then
    return jsonb_build_object('status', 'no_login', 'patient_code', pat.patient_code);
  end if;
  select requires_credential_change into must_change
  from public.profiles where id = pat.user_id;
  if must_change is distinct from true then
    return jsonb_build_object('status', 'already_active', 'patient_code', pat.patient_code);
  end if;
  return jsonb_build_object('status', 'needs_credentials', 'user_id', pat.user_id,
    'patient_code', pat.patient_code);
end;
$$;

create or replace function public.integration_record_credential_issue(
  p_actor_user_id uuid, p_patient_id uuid, p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_integration_actor(p_actor_user_id);
  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (p_actor_user_id, 'integration.credential_issued', 'patient', p_patient_id,
    p_patient_id, jsonb_build_object('reason', left(coalesce(p_reason, 'issue'), 40)));
end;
$$;

revoke all on function private.require_integration_actor(uuid) from public, anon, authenticated;
revoke all on function public.integration_provision_patient(uuid, uuid, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.integration_patient_credential_state(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.integration_record_credential_issue(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function private.require_integration_actor(uuid) to service_role;
grant execute on function public.integration_provision_patient(uuid, uuid, text, text, text, uuid)
  to service_role;
grant execute on function public.integration_patient_credential_state(uuid, uuid)
  to service_role;
grant execute on function public.integration_record_credential_issue(uuid, uuid, text)
  to service_role;
