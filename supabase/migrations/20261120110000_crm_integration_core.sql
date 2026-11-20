-- CRM/ERP integration core (SukunLife side). Service role only.
--
-- PURPOSE
--   * integration_inbox  : idempotency + audit of CRM events (prescriptions).
--   * integration_outbox : reliable, retried delivery of app progress events
--                          to the CRM (the app never calls the CRM directly).
--   * integration_link_patient : explicit CRM id mapping + family linking.
--   * integration_apply_prescription_event : applies a FINAL CRM prescription
--       (issued / updated / cancelled) as a new versioned care plan.
--   * integration_patient_progress : the single authoritative adherence
--       calculation the CRM reads.
--
-- SAFETY
--   * Every function is SECURITY DEFINER and executable by `service_role`
--     only. They are reached through Edge Functions that first verify the
--     CRM signature (see supabase/functions/_shared/crm_auth.ts). The
--     `p_actor_user_id` is a dedicated staff service user configured on the
--     server, never client supplied.
--   * Tables have RLS enabled and NO policies: no app role can read them.
--   * Nothing is deleted. A revision creates a new care plan version; the old
--     plan becomes `inactive`, which (existing trigger) cancels its future
--     pending tasks and scheduled reminders. Completion history is kept.
--   * AI is never involved. Missing counts, schedules or frequencies are
--     REJECTED, never guessed. Staff-only notes are not accepted at all.
--
-- ROLLBACK
--   drop function public.integration_* ; drop table public.integration_outbox,
--   public.integration_inbox; drop trigger/function task_completion_enqueue.
--   No existing table is altered.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.integration_inbox (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'crm',
  event_id text not null,
  event_type text not null,
  payload_hash text not null,
  status text not null,
  result jsonb not null default '{}'::jsonb,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint integration_inbox_status check (status in ('applied', 'rejected', 'stale')),
  constraint integration_inbox_event_not_blank check (btrim(event_id) <> ''),
  unique (source, event_id)
);

create table if not exists public.integration_outbox (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  patient_id uuid references public.patients (id) on delete cascade,
  dedupe_key text not null unique,
  payload jsonb not null,
  status text not null default 'pending',
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  acked_at timestamptz,
  constraint integration_outbox_status check (status in ('pending', 'sent', 'dead'))
);

create index if not exists integration_outbox_due_idx
  on public.integration_outbox (next_attempt_at) where status = 'pending';

alter table public.integration_inbox enable row level security;
alter table public.integration_outbox enable row level security;
revoke all on public.integration_inbox from public, anon, authenticated;
revoke all on public.integration_outbox from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Patient mapping and family linking
-- ---------------------------------------------------------------------------

create or replace function public.integration_link_patient(
  p_actor_user_id uuid,
  p_patient_id uuid,
  p_crm_patient_id text,
  p_crm_customer_id text default null,
  p_crm_family_id text default null,
  p_relationship_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_patient uuid;
  fam public.family_accounts%rowtype;
  patient_row public.patients%rowtype;
begin
  if nullif(btrim(p_crm_patient_id), '') is null then
    raise exception 'crm_patient_id is required.' using errcode = '22023';
  end if;
  select * into patient_row from public.patients
  where id = p_patient_id and status = 'active';
  if not found then
    raise exception 'Patient profile was not found.' using errcode = 'P0002';
  end if;

  -- Never silently merge two patients: an external id points to one patient.
  select patient_id into existing_patient from public.patient_external_refs
  where source_system = 'crm_patient' and external_id = btrim(p_crm_patient_id);
  if existing_patient is not null and existing_patient <> p_patient_id then
    raise exception 'This CRM patient id is already linked to another profile.'
      using errcode = '23505';
  end if;
  if exists (
    select 1 from public.patient_external_refs
    where patient_id = p_patient_id and source_system = 'crm_patient'
      and external_id <> btrim(p_crm_patient_id)
  ) then
    raise exception 'This profile is already linked to a different CRM patient.'
      using errcode = '23505';
  end if;

  insert into public.patient_external_refs (patient_id, source_system, external_id)
  values (p_patient_id, 'crm_patient', btrim(p_crm_patient_id))
  on conflict (source_system, external_id) do nothing;

  if nullif(btrim(p_crm_customer_id), '') is not null then
    select patient_id into existing_patient from public.patient_external_refs
    where source_system = 'crm_customer' and external_id = btrim(p_crm_customer_id);
    -- A customer may own several family profiles; only block a profile that
    -- already carries a different customer id.
    if exists (
      select 1 from public.patient_external_refs
      where patient_id = p_patient_id and source_system = 'crm_customer'
        and external_id <> btrim(p_crm_customer_id)
    ) then
      raise exception 'This profile is already linked to a different CRM customer.'
        using errcode = '23505';
    end if;
    insert into public.patient_external_refs (patient_id, source_system, external_id)
    values (p_patient_id, 'crm_customer', btrim(p_crm_customer_id))
    on conflict (source_system, external_id) do nothing;
  end if;

  if nullif(btrim(p_crm_family_id), '') is not null then
    select * into fam from public.family_accounts
    where crm_family_id = btrim(p_crm_family_id);
    if not found then
      -- The family login is created from the owner profile (it must have a
      -- login). A login-less profile cannot start a family.
      if patient_row.user_id is null then
        raise exception 'The CRM family is not linked yet; link its owner profile first.'
          using errcode = '22023';
      end if;
      select * into fam from public.family_accounts
      where owner_user_id = patient_row.user_id;
      if found then
        if fam.crm_family_id is not null then
          raise exception 'This login already belongs to a different CRM family.'
            using errcode = '23505';
        end if;
        update public.family_accounts set crm_family_id = btrim(p_crm_family_id),
          updated_at = now() where id = fam.id returning * into fam;
      else
        insert into public.family_accounts (owner_user_id, crm_family_id, created_by)
        values (patient_row.user_id, btrim(p_crm_family_id), p_actor_user_id)
        returning * into fam;
        insert into public.family_members (family_id, patient_id, display_order, linked_by)
        values (fam.id, p_patient_id, 0, p_actor_user_id);
      end if;
    end if;

    if not exists (
      select 1 from public.family_members
      where family_id = fam.id and patient_id = p_patient_id and unlinked_at is null
    ) then
      if exists (
        select 1 from public.family_members
        where patient_id = p_patient_id and unlinked_at is null
      ) then
        raise exception 'This profile already belongs to another family.'
          using errcode = '23505';
      end if;
      if patient_row.user_id is not null and patient_row.user_id <> fam.owner_user_id then
        raise exception 'This profile has its own login and cannot join the family.'
          using errcode = '23505';
      end if;
      insert into public.family_members
        (family_id, patient_id, relationship_label, display_order, linked_by)
      values (fam.id, p_patient_id, nullif(btrim(p_relationship_label), ''),
        (select coalesce(max(display_order), 0) + 1 from public.family_members
          where family_id = fam.id), p_actor_user_id);
    end if;
  end if;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (p_actor_user_id, 'integration.patient_linked', 'patient', p_patient_id,
    p_patient_id, jsonb_build_object('crm_patient_id', btrim(p_crm_patient_id),
      'crm_family_id', nullif(btrim(p_crm_family_id), '')));

  return jsonb_build_object('patient_id', p_patient_id,
    'family_id', fam.id, 'crm_patient_id', btrim(p_crm_patient_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Prescription events
-- ---------------------------------------------------------------------------

create or replace function private.integration_reject(
  p_event_id text, p_event_type text, p_hash text, p_event jsonb,
  p_code text, p_detail jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb := jsonb_build_object('status', 'rejected', 'code', p_code,
    'detail', p_detail);
begin
  insert into public.integration_inbox
    (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
  values ('crm', p_event_id, p_event_type, p_hash, 'rejected', result, p_event, now())
  on conflict (source, event_id) do update
    set payload_hash = excluded.payload_hash, status = 'rejected',
        result = excluded.result, payload = excluded.payload,
        event_type = excluded.event_type, processed_at = now()
    where public.integration_inbox.status = 'rejected';
  return result;
end;
$$;

create or replace function public.integration_apply_prescription_event(
  p_actor_user_id uuid,
  p_event jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ev_id text := p_event ->> 'event_id';
  ev_type text := p_event ->> 'event_type';
  rx jsonb := p_event -> 'prescription';
  pt jsonb := p_event -> 'patient';
  ph text;
  inbox public.integration_inbox%rowtype;
  v_patient uuid;
  v_family_crm text;
  v_actual_family_crm text;
  v_rx_id text := rx ->> 'crm_prescription_id';
  v_version integer;
  v_prescription public.prescriptions%rowtype;
  v_latest integer;
  v_start date;
  v_end date;
  v_plan public.care_plans%rowtype;
  v_old_plan uuid;
  v_next_plan_version integer;
  item jsonb;
  tpl public.care_templates%rowtype;
  tpl_revision text;
  v_times text[];
  t text;
  v_text text;
  v_title text;
  v_count integer;
  v_minutes integer;
  v_days integer;
  v_freq jsonb;
  v_item_start date;
  v_item_end date;
  v_action_id uuid;
  v_sort integer := 0;
  seen_items text[] := '{}';
  ref text;
  v_content uuid;
  v_ref_sort integer;
  warnings jsonb := '[]'::jsonb;
  action_count integer := 0;
  raw_lines text[] := '{}';
  result jsonb;
  surah_no integer;
begin
  if p_actor_user_id is null or not exists (
    select 1 from public.user_roles
    where user_id = p_actor_user_id and role::text in ('super_admin', 'raqi')
  ) then
    raise exception 'A staff service actor is required.' using errcode = '42501';
  end if;
  if ev_id is null or btrim(ev_id) = '' or ev_type is null then
    raise exception 'event_id and event_type are required.' using errcode = '22023';
  end if;

  ph := encode(sha256(convert_to(p_event::text, 'UTF8')), 'hex');
  perform pg_advisory_xact_lock(hashtextextended('crm-event:' || ev_id, 0));

  select * into inbox from public.integration_inbox
  where source = 'crm' and event_id = ev_id;
  if found then
    if inbox.payload_hash <> ph then
      return jsonb_build_object('status', 'rejected', 'code', 'event_id_reuse_conflict');
    end if;
    if inbox.status in ('applied', 'stale') then
      return inbox.result || jsonb_build_object('replayed', true);
    end if;
    -- A previously rejected event is re-evaluated (e.g. after mapping).
  end if;

  if ev_type not in ('prescription.issued', 'prescription.updated', 'prescription.cancelled')
     or p_event ->> 'schema_version' is distinct from '1.0'
     or rx is null or pt is null or v_rx_id is null or btrim(v_rx_id) = ''
     or (rx ->> 'version') is null or (rx ->> 'version') !~ '^[0-9]{1,6}$'
     or (pt ->> 'crm_patient_id') is null then
    return private.integration_reject(ev_id, coalesce(ev_type, 'unknown'), ph, p_event, 'invalid_event');
  end if;
  v_version := (rx ->> 'version')::integer;
  if v_version < 1 then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'invalid_event');
  end if;

  -- Identity: explicit mapping only. Never matched by phone or name.
  select patient_id into v_patient from public.patient_external_refs
  where source_system = 'crm_patient' and external_id = btrim(pt ->> 'crm_patient_id');
  if v_patient is null or not exists (
    select 1 from public.patients where id = v_patient and status = 'active'
  ) then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'patient_not_mapped',
      jsonb_build_object('crm_patient_id', pt ->> 'crm_patient_id'));
  end if;

  v_family_crm := nullif(btrim(pt ->> 'crm_family_id'), '');
  if v_family_crm is not null then
    select fa.crm_family_id into v_actual_family_crm
    from public.family_members fm
    join public.family_accounts fa on fa.id = fm.family_id
    where fm.patient_id = v_patient and fm.unlinked_at is null;
    if v_actual_family_crm is distinct from v_family_crm then
      return private.integration_reject(ev_id, ev_type, ph, p_event, 'family_mismatch',
        jsonb_build_object('crm_family_id', v_family_crm));
    end if;
  end if;

  select * into v_prescription from public.prescriptions
  where patient_id = v_patient and source_type = 'imported'
    and source_external_id = btrim(v_rx_id)
  for update;

  if found then
    select coalesce(max(version), 0) into v_latest
    from public.prescription_versions where prescription_id = v_prescription.id;
    if v_version <= v_latest then
      -- Out of order or already superseded: never overwrite a newer version.
      result := jsonb_build_object('status', 'stale', 'current_version', v_latest,
        'received_version', v_version);
      insert into public.integration_inbox
        (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
      values ('crm', ev_id, ev_type, ph, 'stale', result, p_event, now())
      on conflict (source, event_id) do update
        set payload_hash = excluded.payload_hash, status = 'stale',
            result = excluded.result, payload = excluded.payload, processed_at = now();
      return result;
    end if;
  end if;

  -- ---------------- cancellation ----------------
  if ev_type = 'prescription.cancelled' then
    if v_prescription.id is null then
      return private.integration_reject(ev_id, ev_type, ph, p_event, 'prescription_not_found');
    end if;
    update public.care_plans set status = 'inactive'
    where patient_id = v_patient and prescription_id = v_prescription.id
      and status = 'active';
    insert into public.prescription_versions
      (prescription_id, version, raw_text, visibility, change_note, created_by)
    values (v_prescription.id, v_version, 'Cancelled by clinic', 'patient',
      'cancelled', p_actor_user_id);
    update public.prescriptions set archived_at = now() where id = v_prescription.id;

    insert into public.admin_audit_logs
      (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
    values (p_actor_user_id, 'integration.prescription_cancelled', 'prescription',
      v_prescription.id, v_patient, jsonb_build_object('event_id', ev_id,
        'crm_prescription_id', v_rx_id, 'version', v_version));
    result := jsonb_build_object('status', 'applied', 'patient_id', v_patient,
      'prescription_id', v_prescription.id, 'version', v_version, 'care_plan_id', null);
    insert into public.integration_inbox
      (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
    values ('crm', ev_id, ev_type, ph, 'applied', result, p_event, now())
    on conflict (source, event_id) do update
      set payload_hash = excluded.payload_hash, status = 'applied',
          result = excluded.result, payload = excluded.payload, processed_at = now();
    return result;
  end if;

  -- ---------------- issue / revise ----------------
  if coalesce(rx ->> 'status', 'issued') <> 'issued' then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'prescription_not_final');
  end if;
  if (rx ->> 'start_date') is null or (rx ->> 'start_date') !~ '^\d{4}-\d{2}-\d{2}$' then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'missing_start_date');
  end if;
  v_start := (rx ->> 'start_date')::date;
  v_end := nullif(rx ->> 'end_date', '')::date;
  if v_end is not null and v_end < v_start then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'invalid_date_range');
  end if;
  if jsonb_typeof(p_event -> 'items') is distinct from 'array'
     or jsonb_array_length(p_event -> 'items') = 0 then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'no_items');
  end if;

  -- New draft plan version; flipped to active after its actions are in place.
  select coalesce(max(version), 0) + 1 into v_next_plan_version
  from public.care_plans where patient_id = v_patient;

  if v_prescription.id is null then
    insert into public.prescriptions
      (patient_id, source_type, source_external_id, raw_text, session_date,
       visibility, created_by)
    values (v_patient, 'imported', btrim(v_rx_id), 'pending',
      nullif(rx ->> 'issued_at', '')::timestamptz::date, 'patient', p_actor_user_id)
    returning * into v_prescription;
  end if;

  insert into public.care_plans
    (patient_id, prescription_id, version, name, start_date, end_date, status, created_by)
  values (v_patient, v_prescription.id, v_next_plan_version,
    'Rx ' || btrim(v_rx_id) || ' v' || v_version, v_start, v_end, 'draft', p_actor_user_id)
  returning * into v_plan;

  for item in select * from jsonb_array_elements(p_event -> 'items') loop
    if (item ->> 'item_id') is null or (item ->> 'item_id') = ANY (seen_items)
       or (item ->> 'template_id') is null then
      raise exception 'REJECT:invalid_item' using errcode = 'P0001';
    end if;
    seen_items := seen_items || (item ->> 'item_id');

    select * into tpl from public.care_templates where id = item ->> 'template_id';
    if not found then
      raise exception 'REJECT:template_not_found:%', item ->> 'template_id' using errcode = 'P0001';
    end if;
    if not tpl.is_active then
      raise exception 'REJECT:template_inactive:%', tpl.id using errcode = 'P0001';
    end if;
    tpl_revision := 'sha256:' || encode(sha256(convert_to(jsonb_build_array(
      tpl.id, tpl.category, tpl.action_type, tpl.title, tpl.instruction,
      tpl.notification_title, tpl.default_times::text[], tpl.resource_refs,
      tpl.requires_resource, tpl.sort_order, tpl.is_active)::text, 'UTF8')), 'hex');
    if (item ->> 'template_revision') is not null
       and item ->> 'template_revision' <> tpl_revision then
      warnings := warnings || jsonb_build_object('code', 'template_revision_mismatch',
        'item_id', item ->> 'item_id', 'template_id', tpl.id);
    end if;

    v_count := nullif(item ->> 'count', '')::integer;
    v_minutes := nullif(item ->> 'minutes', '')::integer;
    v_days := nullif(item ->> 'days', '')::integer;
    if coalesce(v_count, 1) < 1 or coalesce(v_minutes, 1) < 1 or coalesce(v_days, 1) < 1 then
      raise exception 'REJECT:invalid_parameter:%', item ->> 'item_id' using errcode = 'P0001';
    end if;

    v_text := coalesce(nullif(btrim(item ->> 'patient_instruction'), ''), tpl.instruction);
    v_title := coalesce(nullif(btrim(item ->> 'title'), ''), tpl.title);

    if position('{বার}' in v_text) > 0 then
      if v_count is null then
        raise exception 'REJECT:missing_parameter:%:count', item ->> 'item_id' using errcode = 'P0001';
      end if;
      v_text := replace(v_text, '{বার}', v_count::text);
    end if;
    if position('{মিনিট}' in v_text) > 0 then
      if v_minutes is null then
        raise exception 'REJECT:missing_parameter:%:minutes', item ->> 'item_id' using errcode = 'P0001';
      end if;
      v_text := replace(v_text, '{মিনিট}', v_minutes::text);
    end if;
    if position('{দিন}' in v_text) > 0 then
      if v_days is null then
        raise exception 'REJECT:missing_parameter:%:days', item ->> 'item_id' using errcode = 'P0001';
      end if;
      v_text := replace(v_text, '{দিন}', v_days::text);
    end if;

    v_freq := item -> 'frequency';
    if jsonb_typeof(v_freq) is distinct from 'object'
       or (v_freq ->> 'type') not in ('daily', 'weekly', 'dates') then
      raise exception 'REJECT:missing_frequency:%', item ->> 'item_id' using errcode = 'P0001';
    end if;

    v_item_start := coalesce(nullif(item ->> 'start_date', '')::date, v_start);
    v_item_end := case
      when (item ->> 'duration_days') is not null
        then v_item_start + ((item ->> 'duration_days')::integer - 1)
      else coalesce(nullif(item ->> 'end_date', '')::date, v_end) end;

    if jsonb_typeof(item -> 'reminder_times') is distinct from 'array' then
      raise exception 'REJECT:missing_reminder_times:%', item ->> 'item_id' using errcode = 'P0001';
    end if;
    select coalesce(array_agg(x order by x), '{}') into v_times
    from jsonb_array_elements_text(item -> 'reminder_times') x;
    if exists (select 1 from unnest(v_times) y where y !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') then
      raise exception 'REJECT:invalid_reminder_time:%', item ->> 'item_id' using errcode = 'P0001';
    end if;
    if cardinality(v_times) = 0 then
      v_times := array[null::text];
    end if;

    raw_lines := raw_lines || (v_title || ' - ' || v_text);

    foreach t in array v_times loop
      insert into public.plan_actions
        (care_plan_id, type, title, instruction, count_target, duration_minutes,
         frequency_rule, exact_time, start_date, end_date, sort_order,
         review_status, reminder_enabled, notification_title, created_by)
      values (v_plan.id, tpl.action_type, v_title, v_text, v_count, v_minutes,
        v_freq, t::time, v_item_start, v_item_end, v_sort, 'approved',
        t is not null, tpl.notification_title, p_actor_user_id)
      returning id into v_action_id;
      v_sort := v_sort + 1;
      action_count := action_count + 1;

      -- Resource links: only published, patient-accessible content; anything
      -- else is skipped and reported, never invented.
      v_ref_sort := 0;
      for ref in
        select r from unnest(
          case when jsonb_typeof(item -> 'resource_refs') = 'array'
            then array(select jsonb_array_elements_text(item -> 'resource_refs'))
            else tpl.resource_refs end) r
      loop
        exit when v_ref_sort >= 15;
        if ref ~ '^quran:[0-9]+$' then
          surah_no := substring(ref from 7)::integer;
          if surah_no between 1 and 114 then
            insert into public.plan_action_quran_surahs
              (plan_action_id, surah_number, title, sort_order, created_by)
            values (v_action_id, surah_no, 'Surah ' || surah_no, v_ref_sort, p_actor_user_id)
            on conflict do nothing;
            v_ref_sort := v_ref_sort + 1;
          end if;
        else
          select ci.id into v_content from public.content_items ci
          where ci.slug = ref and ci.status = 'published'
            and ci.visibility in ('public', 'patient_only', 'assigned_only');
          if v_content is null then
            warnings := warnings || jsonb_build_object('code', 'resource_skipped',
              'ref', ref, 'item_id', item ->> 'item_id');
          else
            insert into public.plan_action_resources
              (plan_action_id, content_item_id, created_by, sort_order)
            values (v_action_id, v_content, p_actor_user_id, v_ref_sort)
            on conflict do nothing;
            v_ref_sort := v_ref_sort + 1;
          end if;
        end if;
      end loop;
    end loop;
  end loop;

  update public.prescriptions
  set raw_text = coalesce(nullif(btrim(rx ->> 'patient_visible_note'), ''),
        array_to_string(raw_lines, E'\n'))
  where id = v_prescription.id;
  insert into public.prescription_versions
    (prescription_id, version, raw_text, visibility, change_note, created_by)
  values (v_prescription.id, v_version,
    coalesce(nullif(btrim(rx ->> 'patient_visible_note'), ''), array_to_string(raw_lines, E'\n')),
    'patient', ev_type, p_actor_user_id);

  -- Publish: previous active plan becomes inactive (existing trigger cancels
  -- its future pending tasks and scheduled reminders).
  select id into v_old_plan from public.care_plans
  where patient_id = v_patient and status = 'active';
  update public.care_plans set status = 'inactive'
  where patient_id = v_patient and status = 'active';
  update public.care_plans
  set status = 'active', published_at = now(), published_by = p_actor_user_id
  where id = v_plan.id;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (p_actor_user_id, 'integration.prescription_applied', 'care_plan',
    v_plan.id, v_patient, jsonb_build_object('event_id', ev_id,
      'crm_prescription_id', v_rx_id, 'version', v_version,
      'plan_version', v_next_plan_version, 'actions', action_count,
      'replaced_plan_id', v_old_plan));

  result := jsonb_build_object('status', 'applied', 'patient_id', v_patient,
    'prescription_id', v_prescription.id, 'version', v_version,
    'care_plan_id', v_plan.id, 'care_plan_version', v_next_plan_version,
    'actions_created', action_count, 'warnings', warnings);
  insert into public.integration_inbox
    (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
  values ('crm', ev_id, ev_type, ph, 'applied', result, p_event, now())
  on conflict (source, event_id) do update
    set payload_hash = excluded.payload_hash, status = 'applied',
        result = excluded.result, payload = excluded.payload, processed_at = now();
  return result;

exception
  when sqlstate 'P0001' then
    -- Business rejection raised from inside the item loop: everything done
    -- for this event is rolled back (implicit subtransaction), then recorded.
    if sqlerrm like 'REJECT:%' then
      return private.integration_reject(ev_id, ev_type, ph, p_event,
        split_part(substring(sqlerrm from 8), ':', 1),
        jsonb_build_object('info', substring(sqlerrm from 8)));
    end if;
    raise;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Progress: outbox enqueue + delivery RPCs + authoritative summary
-- ---------------------------------------------------------------------------

create or replace function private.enqueue_task_completion_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  crm_patient text;
  info record;
begin
  select external_id into crm_patient from public.patient_external_refs
  where patient_id = new.patient_id and source_system = 'crm_patient'
  order by created_at limit 1;
  if crm_patient is null then
    return new;   -- Patients without a CRM link are never exported.
  end if;

  select ti.occurrence_date, pa.id as plan_action_id, cp.id as care_plan_id,
         cp.version as care_plan_version, rx.source_external_id as crm_prescription_id
  into info
  from public.task_instances ti
  join public.plan_actions pa on pa.id = ti.plan_action_id
  join public.care_plans cp on cp.id = pa.care_plan_id
  left join public.prescriptions rx on rx.id = cp.prescription_id
  where ti.id = new.task_instance_id;

  insert into public.integration_outbox (event_type, patient_id, dedupe_key, payload)
  values (
    'progress.task_' || new.status::text,
    new.patient_id,
    'task_completion:' || new.id::text,
    jsonb_build_object(
      'schema_version', '1.0',
      'event_id', new.id,
      'event_type', 'progress.task_' || new.status::text,
      'occurred_at', to_char(new.occurred_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'crm_patient_id', crm_patient,
      'sukun_patient_id', new.patient_id,
      'crm_prescription_id', info.crm_prescription_id,
      'care_plan_id', info.care_plan_id,
      'care_plan_version', info.care_plan_version,
      'plan_action_id', info.plan_action_id,
      'task_instance_id', new.task_instance_id,
      'occurrence_date', info.occurrence_date,
      'status', new.status
    ))
  on conflict (dedupe_key) do nothing;
  return new;
end;
$$;

drop trigger if exists task_completions_enqueue_integration on public.task_completions;
create trigger task_completions_enqueue_integration
after insert on public.task_completions
for each row execute function private.enqueue_task_completion_event();

create or replace function public.integration_claim_outbox(
  p_limit integer default 50,
  p_lease_seconds integer default 300
)
returns setof public.integration_outbox
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with due as (
    select o.id from public.integration_outbox o
    where o.status = 'pending' and o.next_attempt_at <= now()
    order by o.next_attempt_at, o.created_at
    limit least(greatest(coalesce(p_limit, 50), 1), 200)
    for update skip locked
  )
  update public.integration_outbox o
  set attempts = o.attempts + 1,
      next_attempt_at = now() + make_interval(secs => greatest(coalesce(p_lease_seconds, 300), 30))
  from due where o.id = due.id
  returning o.*;
end;
$$;

create or replace function public.integration_ack_outbox(p_ids uuid[])
returns integer
language sql
security definer
set search_path = ''
as $$
  with done as (
    update public.integration_outbox
    set status = 'sent', acked_at = now(), last_error = null
    where id = any (p_ids) and status = 'pending'
    returning 1
  ) select count(*)::integer from done;
$$;

create or replace function public.integration_fail_outbox(
  p_id uuid, p_error text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.integration_outbox%rowtype;
  new_status text;
begin
  select * into o from public.integration_outbox where id = p_id for update;
  if not found or o.status <> 'pending' then return 'ignored'; end if;
  -- Exponential backoff (1,2,4,... minutes, capped at 6 hours); dead letter
  -- after 12 attempts for manual reconciliation. The error text is truncated
  -- and must never contain patient data.
  new_status := case when o.attempts >= 12 then 'dead' else 'pending' end;
  update public.integration_outbox
  set status = new_status,
      last_error = left(coalesce(p_error, 'delivery_failed'), 300),
      next_attempt_at = now() + make_interval(
        mins => least(power(2, greatest(o.attempts - 1, 0))::integer, 360))
  where id = p_id;
  return new_status;
end;
$$;

create or replace function public.integration_patient_progress(
  p_crm_patient_id text,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_patient uuid;
  totals jsonb;
  daily jsonb;
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    raise exception 'A date range of at most 93 days is required.' using errcode = '22023';
  end if;
  select patient_id into v_patient from public.patient_external_refs
  where source_system = 'crm_patient' and external_id = btrim(p_crm_patient_id);
  if v_patient is null then
    raise exception 'Patient is not linked.' using errcode = 'P0002';
  end if;

  select jsonb_build_object(
    'total', count(*) filter (where ti.status <> 'cancelled'),
    'completed', count(*) filter (where ti.status = 'completed'),
    'pending', count(*) filter (where ti.status = 'pending'),
    'snoozed', count(*) filter (where ti.status = 'snoozed'),
    'skipped', count(*) filter (where ti.status = 'skipped'),
    'missed', count(*) filter (where ti.status = 'missed'),
    'adherence_percent', case when count(*) filter (where ti.status <> 'cancelled') = 0 then null
      else round(100.0 * count(*) filter (where ti.status = 'completed')
        / count(*) filter (where ti.status <> 'cancelled'), 1) end)
  into totals
  from public.task_instances ti
  where ti.patient_id = v_patient and ti.occurrence_date between p_from and p_to;

  select coalesce(jsonb_agg(d order by d ->> 'date'), '[]'::jsonb) into daily
  from (
    select jsonb_build_object('date', ti.occurrence_date,
      'total', count(*) filter (where ti.status <> 'cancelled'),
      'completed', count(*) filter (where ti.status = 'completed'),
      'skipped', count(*) filter (where ti.status = 'skipped'),
      'pending', count(*) filter (where ti.status in ('pending', 'snoozed'))) as d
    from public.task_instances ti
    where ti.patient_id = v_patient and ti.occurrence_date between p_from and p_to
    group by ti.occurrence_date
  ) x;

  return jsonb_build_object('schema_version', '1.0',
    'crm_patient_id', btrim(p_crm_patient_id), 'from', p_from, 'to', p_to,
    'totals', totals, 'daily', daily);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Grants: service role only
-- ---------------------------------------------------------------------------

revoke all on function public.integration_link_patient(uuid, uuid, text, text, text, text)
  from public, anon, authenticated;
revoke all on function public.integration_apply_prescription_event(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.integration_claim_outbox(integer, integer)
  from public, anon, authenticated;
revoke all on function public.integration_ack_outbox(uuid[]) from public, anon, authenticated;
revoke all on function public.integration_fail_outbox(uuid, text) from public, anon, authenticated;
revoke all on function public.integration_patient_progress(text, date, date)
  from public, anon, authenticated;
revoke all on function private.integration_reject(text, text, text, jsonb, text, jsonb)
  from public, anon, authenticated;
revoke all on function private.enqueue_task_completion_event()
  from public, anon, authenticated;

grant execute on function public.integration_link_patient(uuid, uuid, text, text, text, text)
  to service_role;
grant execute on function public.integration_apply_prescription_event(uuid, jsonb)
  to service_role;
grant execute on function public.integration_claim_outbox(integer, integer) to service_role;
grant execute on function public.integration_ack_outbox(uuid[]) to service_role;
grant execute on function public.integration_fail_outbox(uuid, text) to service_role;
grant execute on function public.integration_patient_progress(text, date, date)
  to service_role;
grant usage on schema private to service_role;
grant execute on function private.integration_reject(text, text, text, jsonb, text, jsonb)
  to service_role;
