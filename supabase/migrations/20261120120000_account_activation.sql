-- One-time account activation for CRM-registered patients (phase 4).
--
-- PURPOSE
--   The CRM never sends a password. SukunLife creates the login with a random,
--   unknown password, then delivers a single-use activation link (WhatsApp).
--   The patient opens it and sets their own permanent password.
--
-- DESIGN
--   * Only a SHA-256 hash of the token is stored; the token itself exists only
--     in the delivered link. 256 bit random token, 24 h default life
--     (5 minutes to 72 hours allowed), single use.
--   * Issuing a new link revokes older unused ones (safe resend).
--   * An already activated account (profiles.requires_credential_change =
--     false) is NEVER issued a link here, so an existing permanent password
--     cannot be reset by a new CRM prescription. Recovery is a separate flow.
--   * Service role only. Tables have RLS on and no policies.
--   * `integration_provision_patient` creates the patient row for an
--     integration actor (staff) with or without a login. A profile without a
--     login is a family member.
--
-- ROLLBACK
--   drop function public.integration_provision_patient, integration_issue_activation,
--   integration_consume_activation, integration_reopen_activation,
--   integration_complete_activation; drop table public.account_activations;

create table if not exists public.account_activations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  token_hash text not null unique,
  channel text not null default 'whatsapp',
  phone_digits text,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  revoked_at timestamptz,
  delivery_status text not null default 'pending',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint account_activations_hash check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint account_activations_channel check (channel in ('whatsapp', 'manual')),
  constraint account_activations_delivery check (
    delivery_status in ('pending', 'sent', 'failed', 'not_configured')
  )
);

create index if not exists account_activations_patient_idx
  on public.account_activations (patient_id, created_at desc);

alter table public.account_activations enable row level security;
revoke all on public.account_activations from public, anon, authenticated;

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

create or replace function public.integration_issue_activation(
  p_actor_user_id uuid,
  p_patient_id uuid,
  p_token_hash text,
  p_phone_digits text default null,
  p_ttl_minutes integer default 1440
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  pat public.patients%rowtype;
  must_change boolean;
  act public.account_activations%rowtype;
begin
  perform private.require_integration_actor(p_actor_user_id);
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
     or coalesce(p_ttl_minutes, 0) not between 5 and 4320 then
    raise exception 'Invalid activation request.' using errcode = '22023';
  end if;
  select * into pat from public.patients where id = p_patient_id and status = 'active';
  if not found then
    raise exception 'Patient profile was not found.' using errcode = 'P0002';
  end if;
  if pat.user_id is null then
    return jsonb_build_object('status', 'no_login');
  end if;

  select requires_credential_change into must_change
  from public.profiles where id = pat.user_id;
  if must_change is distinct from true then
    -- The patient already chose a permanent password. Never touch it.
    return jsonb_build_object('status', 'already_active');
  end if;

  update public.account_activations set revoked_at = now()
  where patient_id = p_patient_id and consumed_at is null and revoked_at is null;

  insert into public.account_activations
    (patient_id, user_id, token_hash, phone_digits, expires_at, created_by)
  values (p_patient_id, pat.user_id, p_token_hash, nullif(btrim(p_phone_digits), ''),
    now() + make_interval(mins => p_ttl_minutes), p_actor_user_id)
  returning * into act;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (p_actor_user_id, 'integration.activation_issued', 'account_activation',
    act.id, p_patient_id, jsonb_build_object('expires_at', act.expires_at));

  return jsonb_build_object('status', 'issued', 'activation_id', act.id,
    'expires_at', act.expires_at, 'patient_code', pat.patient_code);
end;
$$;

create or replace function public.integration_set_activation_delivery(
  p_activation_id uuid, p_status text
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.account_activations set delivery_status = p_status
  where id = p_activation_id and p_status in ('sent', 'failed', 'not_configured');
$$;

-- Atomically spends a valid link. Returns null for unknown, used, revoked or
-- expired tokens (one indistinguishable answer).
create or replace function public.integration_consume_activation(p_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  act public.account_activations%rowtype;
  code text;
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    return null;
  end if;
  update public.account_activations
  set consumed_at = now()
  where token_hash = p_token_hash and consumed_at is null
    and revoked_at is null and expires_at > now()
  returning * into act;
  if not found then return null; end if;
  select patient_code into code from public.patients where id = act.patient_id;
  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (null, 'integration.activation_consumed', 'account_activation',
    act.id, act.patient_id, '{}'::jsonb);
  return jsonb_build_object('activation_id', act.id, 'user_id', act.user_id,
    'patient_id', act.patient_id, 'patient_code', code);
end;
$$;

-- Used only when setting the password failed after the link was spent.
create or replace function public.integration_reopen_activation(p_activation_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with r as (
    update public.account_activations set consumed_at = null
    where id = p_activation_id and consumed_at is not null and revoked_at is null
      and expires_at > now()
    returning 1
  ) select exists (select 1 from r);
$$;

create or replace function public.integration_complete_activation(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles set requires_credential_change = false where id = p_user_id;
$$;

revoke all on function private.require_integration_actor(uuid) from public, anon, authenticated;
revoke all on function public.integration_provision_patient(uuid, uuid, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.integration_issue_activation(uuid, uuid, text, text, integer)
  from public, anon, authenticated;
revoke all on function public.integration_set_activation_delivery(uuid, text)
  from public, anon, authenticated;
revoke all on function public.integration_consume_activation(text) from public, anon, authenticated;
revoke all on function public.integration_reopen_activation(uuid) from public, anon, authenticated;
revoke all on function public.integration_complete_activation(uuid) from public, anon, authenticated;
grant execute on function private.require_integration_actor(uuid) to service_role;
grant execute on function public.integration_provision_patient(uuid, uuid, text, text, text, uuid)
  to service_role;
grant execute on function public.integration_issue_activation(uuid, uuid, text, text, integer)
  to service_role;
grant execute on function public.integration_set_activation_delivery(uuid, text) to service_role;
grant execute on function public.integration_consume_activation(text) to service_role;
grant execute on function public.integration_reopen_activation(uuid) to service_role;
grant execute on function public.integration_complete_activation(uuid) to service_role;
