-- Production parity phase B: ADDITIVE live schema/functions only.

-- All source definitions were first validated in isolated staging and CI.

-- No production patients, login credentials, prescriptions, attachments or resources are copied or removed.

-- Caller roles and existing authorizations remain server-side; never expose service-role credentials.

-- --- Canonical source: 20261009100100_member_signup_provisioning.sql ---
-- Accounts created through email, phone OTP, or an OAuth provider must
-- receive only a nonclinical member identity by default. Never derive any
-- patient, raqi, support, or admin permission from user-supplied metadata.
create or replace function private.provision_public_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, locale, requires_credential_change)
  values (new.id, 'bn', false)
  on conflict (id) do update
  set locale = 'bn'
  where public.profiles.locale = 'en';

  insert into public.user_roles (user_id, role, granted_by)
  values (new.id, 'member'::public.app_role, null)
  on conflict (user_id, role) do nothing;

  return new;
end;
$$;

revoke all on function private.provision_public_member()
  from public, anon, authenticated;

drop trigger if exists provision_public_member_after_signup on auth.users;
create trigger provision_public_member_after_signup
after insert on auth.users
for each row execute function private.provision_public_member();

comment on function private.provision_public_member() is
  'Creates a Bangla public profile and a member-only role for new Auth users; never grants clinical or staff permissions.';

-- --- Canonical source: 20261011000000_patient_role_provisioning_exclusive.sql ---
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

-- --- Canonical source: 20261011034500_patient_login_rate_limit_jwt_claims.sql ---
-- Staging-tested Patient sign-in limiter; never bypass or disable throttling.
-- PostgREST now supplies the signed JWT role in request.jwt.claims; the
-- legacy request.jwt.claim.role GUC may be absent. The old check caused
-- "Server role required" (42501) for legitimate server-side sign-ins.
-- Keep BOTH the signed service_role claim check and RPC execute ACL.
create schema if not exists private;

create table if not exists private.patient_login_attempts (
  bucket_key text primary key check (length(bucket_key) = 64),
  window_start timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  updated_at timestamptz not null default now()
);
revoke all on private.patient_login_attempts from public, anon, authenticated;

create or replace function public.check_patient_login_rate_limit(
  p_ip_hash text, p_identity_hash text
) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  permitted boolean;
  current_key text;
  current_count integer;
  threshold integer;
begin
  -- Only an API-validated service_role JWT may invoke this RPC.
  -- auth.jwt() reads the signed request.jwt.claims representation, which is
  -- the current PostgREST context. Legacy claim fallback supports older
  -- PostgREST installations only when the JSON claim has no role.
  if coalesce(
      nullif(auth.jwt() ->> 'role', ''),
      nullif(current_setting('request.jwt.claim.role', true), ''),
      ''
    ) <> 'service_role' then
    raise exception 'Server role required' using errcode = '42501';
  end if;

  if p_ip_hash !~ '^[0-9a-f]{64}$'
    or p_identity_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid rate-limit key' using errcode = '22023';
  end if;

  permitted := true;
  for current_key, threshold in
    select 'i:' || p_ip_hash, 30
    union all select 'u:' || p_identity_hash, 8
    order by 1
  loop
    insert into private.patient_login_attempts as a
      (bucket_key, window_start, attempts, updated_at)
    values (substr(current_key, 3), now(), 1, now())
    on conflict (bucket_key) do update
      set attempts = case
        when a.window_start <= now() - interval '15 minutes' then 1
        else a.attempts + 1 end,
        window_start = case
        when a.window_start <= now() - interval '15 minutes' then now()
        else a.window_start end,
        updated_at = now()
    returning attempts into current_count;
    if current_count > threshold then permitted := false; end if;
  end loop;
  return permitted;
end;
$$;

revoke all on function public.check_patient_login_rate_limit(text,text)
  from public, anon, authenticated;
grant execute on function public.check_patient_login_rate_limit(text,text)
  to service_role;

-- --- Canonical source: 20261008140500_patient_notification_inbox.sql ---
-- Prelaunch patient inbox: permit only the authenticated owner to mark
-- an already sent event as opened. No client-supplied patient identity.
-- Server-only scheduled, failed and cancelled events cannot be marked opened.
-- RLS SELECT continues to protect history; direct UPDATE remains admin-only.
create or replace function public.mark_patient_notification_opened(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_patient_id uuid;
  matched_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  caller_patient_id := (select private.current_patient_id());
  if caller_patient_id is null or p_notification_id is null then
    return false;
  end if;

  update public.notification_events ne
  set
    status = 'opened'::public.notification_status,
    opened_at = coalesce(ne.opened_at, now())
  where ne.id = p_notification_id
    and ne.patient_id = caller_patient_id
    and ne.status in ('sent', 'opened')
    and ne.scheduled_at <= now()
  returning ne.id into matched_id;

  return matched_id is not null;
end;
$$;

revoke execute on function public.mark_patient_notification_opened(uuid)
  from public, anon, authenticated;
grant execute on function public.mark_patient_notification_opened(uuid)
  to authenticated;

comment on function public.mark_patient_notification_opened(uuid) is
  'Allows only the authenticated patient to mark an already sent own event as opened; no arbitrary status or patient ID is accepted.';

-- --- Canonical source: 20261013170000_reviewed_resource_bulk_publication.sql ---
-- Reviewed Sukun Life resources: authenticated, audited, atomic batch publication.
-- Scope deliberately excludes unfinished Qur'an passages and test/private data.
create or replace function public.publish_reviewed_resource_batch(
  p_content_item_ids uuid[],
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  item public.content_items;
  ok_count integer := 0;
  failed_count integer := 0;
  skipped_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  allowed_book boolean;
  allowed_audio boolean;
  before_visibility public.resource_visibility;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_request_id is null or p_content_item_ids is null
     or coalesce(array_length(p_content_item_ids, 1), 0) < 1
     or array_length(p_content_item_ids, 1) > 100 then
    raise exception 'Choose between one and 100 reviewed content items.'
      using errcode = '22023';
  end if;
  if array_position(p_content_item_ids, null) is not null then
    raise exception 'Invalid content identifier.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  -- Locks/reloads current database rows: never write an old screen snapshot.
  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) requested
      on requested.id = ci.id
    order by ci.id
    for update of ci
  loop
    allowed_book :=
      item.slug like 'srg2024-%'
      and item.slug not like 'srg2024-qur-%'
      and item.type in ('article', 'dua', 'amal')
      and item.rights_note like
        'Sukun Life owner attested app-use rights on 2026-10-12.%'
      and item.source_reference is not null
      and btrim(item.source_reference) <> ''
      and item.arabic_text is null
      or false;

    -- Dua source material contains Arabic: retain source-based Dua, but do
    -- not let an ARTICLE with unverified Arabic masquerade as a Qur'an Ayah.
    if item.type = 'dua' and item.slug like 'srg2024-dua-%'
       and item.rights_note like
         'Sukun Life owner attested app-use rights on 2026-10-12.%'
       and nullif(btrim(item.source_reference), '') is not null then
      allowed_book := true;
    end if;

    allowed_audio :=
      item.slug like 'sukun-ruqyahbd-%'
      and item.type = 'audio'
      and item.media_source_type = 'direct_audio_url'
      and item.media_url like 'https://files.ruqyahbd.org/audio/%'
      and split_part(item.media_url, '/', 3) = 'files.ruqyahbd.org'
      and item.rights_note like
        'Owner-attested Sukun Life audio authorization (2026-10-12).%'
      and nullif(btrim(item.source_reference), '') is not null;

    if item.status not in ('draft', 'review')
       or item.visibility not in ('staff_only', 'public')
       or item.title ilike '%QA TEST%'
       or item.title like '%সূত্র যাচাই প্রয়োজন%'
       or item.slug ~* '(^|[-_])(qa|test|fixture|sample|synthetic)([-_]|$)'
       or not (allowed_book or allowed_audio) then
      skipped_count := skipped_count + 1;
      continue;
    end if;

    begin
      before_visibility := item.visibility;
      if item.visibility = 'staff_only' then
        update public.content_items
        set visibility = 'public',
            updated_by = caller_user_id
        where id = item.id;
        insert into public.admin_audit_logs(
          actor_user_id, action, entity_type, entity_id, request_id, metadata
        ) values (
          caller_user_id, 'content_item_visibility_public', 'content_item',
          item.id, gen_random_uuid(),
          jsonb_build_object('batch_request_id', p_request_id,
                             'previous_visibility', before_visibility,
                             'reason', 'user-reviewed authorized source batch')
        );
      end if;

      if item.status = 'draft' then
        perform public.transition_content_item(
          item.id, 'submit',
          'Super Admin reviewed source batch submission.',
          gen_random_uuid()
        );
      end if;
      perform public.transition_content_item(
        item.id, 'publish',
        'Super Admin reviewed source batch publication.',
        gen_random_uuid()
      );
      ok_count := ok_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
      -- The inner subtransaction reverts both visibility and status.
    end;
  end loop;

  return jsonb_build_object(
    'published', ok_count,
    'failed', failed_count,
    'skipped', skipped_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.publish_reviewed_resource_batch(uuid[],uuid)
  from public, anon;
grant execute on function public.publish_reviewed_resource_batch(uuid[],uuid)
  to authenticated;

-- --- Canonical source: 20261013200000_archive_selected_content_drafts.sql ---
-- Admin-only bulk soft delete: archive selected DRAFT items.
-- Avoid client snapshot races and preserve evidence, audit history, and linked records.
create or replace function public.archive_selected_content_drafts(
  p_content_item_ids uuid[],
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  item public.content_items;
  archived_count integer := 0;
  skipped_count integer := 0;
  failed_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  requested_count integer;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  requested_count := coalesce(array_length(p_content_item_ids, 1), 0);
  if p_request_id is null or requested_count < 1 or requested_count > 100 then
    raise exception 'Select between 1 and 100 draft items.'
      using errcode = '22023';
  end if;
  if array_position(p_content_item_ids, null) is not null then
    raise exception 'Invalid content identifier.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  -- Recheck every status *after* obtaining its row lock. A draft published
  -- by another administrator in the meantime must never be archived here.
  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) selected
      on selected.id = ci.id
    order by ci.id
    for update of ci
  loop
    if item.status <> 'draft' then
      skipped_count := skipped_count + 1;
      continue;
    end if;

    begin
      perform public.transition_content_item(
        item.id,
        'archive',
        'Super Admin bulk draft archive (soft delete; preserves history).',
        gen_random_uuid()
      );
      archived_count := archived_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
    end;
  end loop;

  return jsonb_build_object(
    'archived', archived_count,
    'skipped', skipped_count,
    'failed', failed_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.archive_selected_content_drafts(uuid[],uuid)
  from public, anon;
grant execute on function public.archive_selected_content_drafts(uuid[],uuid)
  to authenticated;

-- --- Canonical source: 20261014080000_submit_selected_content_drafts_for_review.sql ---
-- Review is a queue transition, never a publication.
-- The existing transition_content_item function owns status, reviewer history
-- and server audit. This wrapper only batches SELECTED eligible draft IDs.
create or replace function public.submit_selected_content_drafts_for_review(
  p_content_item_ids uuid[],
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  item public.content_items;
  submitted_count integer := 0;
  skipped_count integer := 0;
  failed_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  requested_count integer;
  seen_count integer := 0;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  requested_count := coalesce(array_length(p_content_item_ids, 1), 0);
  if p_request_id is null or requested_count < 1 or requested_count > 100 then
    raise exception 'Select between 1 and 100 draft items.'
      using errcode = '22023';
  end if;
  if array_position(p_content_item_ids, null) is not null then
    raise exception 'Invalid content identifier.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  -- Re-read and lock the *current* record, never trust the Flutter snapshot.
  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) selected
      on selected.id = ci.id
    order by ci.id
    for update of ci
  loop
    seen_count := seen_count + 1;

    -- QA/private patient items are not legitimate editorial submissions.
    -- Unsourced Qur'an editorial drafts may be SUBMITTED for human review;
    -- they are NOT source-verified or published by this function.
    if item.status <> 'draft'
       or item.visibility not in ('staff_only', 'public')
       or item.slug ~* '(^|[-_])(qa|test|fixture|sample|synthetic)([-_]|$)'
       or item.title ilike '%QA TEST%'
    then
      skipped_count := skipped_count + 1;
      continue;
    end if;

    begin
      perform public.transition_content_item(
        item.id,
        'submit',
        'Super Admin sent selected draft for human review; not published.',
        gen_random_uuid()
      );
      submitted_count := submitted_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
      -- A failed item's status and audit changes roll back together.
    end;
  end loop;

  -- Report IDs missing since selection as skipped; do not fabricate success.
  skipped_count := skipped_count + (
    select count(*)
    from (select distinct unnest(p_content_item_ids) as id) requested
    where not exists (
      select 1 from public.content_items ci where ci.id = requested.id
    )
  );

  return jsonb_build_object(
    'submitted', submitted_count,
    'skipped', skipped_count,
    'failed', failed_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.submit_selected_content_drafts_for_review(uuid[], uuid)
  from public, anon;
grant execute on function public.submit_selected_content_drafts_for_review(uuid[], uuid)
  to authenticated;

-- --- Canonical source: 20261014100000_manage_selected_content_reviews.sql ---
-- Review-queue bulk operations: safe correction and reversible archive.
-- Never bulk approve canonical scripture or publish items without source review.
create or replace function public.manage_selected_content_reviews(
  p_content_item_ids uuid[],
  p_action text,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  item public.content_items;
  changed_count integer := 0;
  skipped_count integer := 0;
  failed_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  request_size integer;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  request_size := coalesce(array_length(p_content_item_ids, 1), 0);
  if p_action not in ('return_to_draft', 'archive')
      or p_action is null or p_request_id is null
      or request_size < 1 or request_size > 100
      or array_position(p_content_item_ids, null) is not null then
    raise exception 'Invalid review bulk action or selection.'
      using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) requested
      on ci.id = requested.id
    order by ci.id
    for update of ci
  loop
    -- A concurrent state change or private QA item must never be modified.
    if item.status <> 'review'
       or item.visibility not in ('staff_only','public')
       or item.slug ~* '(^|[-_])(qa|test|fixture|sample|synthetic)([-_]|$)'
       or item.title ilike '%QA TEST%' then
      skipped_count := skipped_count + 1;
      continue;
    end if;
    begin
      if p_action = 'archive' then
        perform public.transition_content_item(
          item.id, 'archive',
          'Super Admin archived a selected review item (soft delete).',
          gen_random_uuid()
        );
      elsif item.type in ('quran','hadith') then
        -- Canonical "reject" already resets verified metadata and audits.
        perform public.transition_content_item(
          item.id, 'reject',
          'Returned from review for correction; Quran/Hadith not verified.',
          gen_random_uuid()
        );
      else
        -- The standard reject transition only accepts canonical items.
        -- Editorial review items need an equally audited return path.
        update public.content_items
        set status = 'draft',
            verification_status = 'not_required',
            verified_by = null,
            verified_at = null,
            published_at = null,
            updated_by = caller_user_id
        where id = item.id;

        insert into public.content_reviews(
          content_item_id, reviewer_user_id, decision, notes
        ) values (
          item.id, caller_user_id, 'rejected',
          'Sent back for editing from bulk review; never published.'
        );

        insert into public.admin_audit_logs(
          actor_user_id, action, entity_type, entity_id, request_id, metadata
        ) values (
          caller_user_id, 'content_item_return_to_draft', 'content_item',
          item.id, gen_random_uuid(),
          jsonb_build_object(
            'batch_request_id', p_request_id,
            'from_status','review', 'to_status','draft',
            'visibility',item.visibility, 'review_required',true
          )
        );
      end if;
      changed_count := changed_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
    end;
  end loop;

  skipped_count := skipped_count + (
    select count(*)
    from (select distinct unnest(p_content_item_ids) as id) requested
    where not exists (
      select 1 from public.content_items ci where ci.id = requested.id
    )
  );

  return jsonb_build_object(
    'changed', changed_count,
    'skipped', skipped_count,
    'failed', failed_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.manage_selected_content_reviews(uuid[],text,uuid)
  from public, anon;
grant execute on function public.manage_selected_content_reviews(uuid[],text,uuid)
  to authenticated;

-- Defense-in-depth: ensure that the Patient provisioning RPC stays server-only.

REVOKE ALL ON FUNCTION public.finalize_patient_provisioning(uuid,uuid,text,text,text,uuid) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.finalize_patient_provisioning(uuid,uuid,text,text,text,uuid) TO service_role;

-- Add Quran ARTICLE editorial reference metadata, without changing any actual verses or publishing content.

-- Staging-first reference reconciliation of 101 Sukun Life Qur'an/editorial items.
-- Quran source compared for METADATA ONLY, using the 6,236-verse Uthmani corpus
-- at nuqayah/quran-text GitHub blob fcc214311897921d08bbc56879b82aa38328a5f3.
-- IMPORTANT: Normalized script/partial-verse matching is not byte-perfect
-- canonical verification. Do NOT publish, change Arabic, or clear review state.
-- The existing canonical ayah_end_number is intentionally restricted to
-- content_type='quran'. These records are ARTICLE excerpts, not canonical.
-- Provide a separately named end-ayah field that cannot be confused with
-- published canonical Quran content.
ALTER TABLE public.content_items
  ADD COLUMN IF NOT EXISTS editorial_ayah_end_number integer;
DO $bounds$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.content_items'::regclass
      AND conname = 'content_items_editorial_ayah_bounds'
  ) THEN
    ALTER TABLE public.content_items
      ADD CONSTRAINT content_items_editorial_ayah_bounds
      CHECK (
        editorial_ayah_end_number IS NULL
        OR (
          type = 'article'
          AND ayah_number IS NOT NULL
          AND editorial_ayah_end_number >= ayah_number
        )
      );
  END IF;
END
$bounds$;

CREATE TABLE IF NOT EXISTS public.quran_reference_reconciliation_audit (
  content_item_id uuid NOT NULL REFERENCES public.content_items(id),
  audit_version text NOT NULL,
  matched_surah smallint,
  matched_ayah integer,
  matched_end_ayah integer,
  approximate_text_similarity numeric(6,4),
  partial_verse_excerpt boolean NOT NULL DEFAULT false,
  decision text NOT NULL,
  original_arabic_md5 text NOT NULL,
  comparison_source text NOT NULL,
  reference_checked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(content_item_id, audit_version)
);
ALTER TABLE public.quran_reference_reconciliation_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.quran_reference_reconciliation_audit FROM public, anon, authenticated;


