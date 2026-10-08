-- Phase 4B: private prescription document capture and multimodal AI extraction.
-- This is additive: existing typed prescriptions and AI requests remain valid.

create table public.prescription_attachments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete restrict,
  prescription_id uuid references public.prescriptions (id) on delete restrict,
  care_plan_id uuid references public.care_plans (id) on delete restrict,
  uploaded_by uuid not null references auth.users (id) on delete restrict,
  bucket_id text not null default 'prescription-private',
  storage_path text not null unique,
  original_filename text not null,
  mime_type text not null,
  byte_size bigint not null,
  session_date date,
  visibility public.record_visibility not null default 'patient',
  extraction_status text not null default 'pending_upload',
  processing_request_id uuid unique,
  normalized_result jsonb,
  provider_model text,
  uploaded_at timestamptz,
  processing_started_at timestamptz,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint prescription_attachments_filename_not_blank check (
    btrim(original_filename) <> ''
  ),
  constraint prescription_attachments_path_not_blank check (
    btrim(storage_path) <> ''
  ),
  constraint prescription_attachments_size check (
    byte_size between 1 and 10485760
  ),
  constraint prescription_attachments_mime check (
    mime_type in ('application/pdf', 'image/jpeg', 'image/png')
  ),
  constraint prescription_attachments_bucket check (
    bucket_id = 'prescription-private'
  ),
  constraint prescription_attachments_status check (
    extraction_status in (
      'pending_upload', 'processing', 'succeeded', 'failed', 'manual_required'
    )
  ),
  constraint prescription_attachments_result check (
    normalized_result is null or jsonb_typeof(normalized_result) = 'object'
  ),
  constraint prescription_attachments_completion check (
    (extraction_status = 'succeeded'
      and prescription_id is not null
      and care_plan_id is not null
      and processed_at is not null
      and normalized_result is not null)
    or extraction_status <> 'succeeded'
  )
);

create index prescription_attachments_patient_created_idx
  on public.prescription_attachments (patient_id, created_at desc);
create index prescription_attachments_prescription_idx
  on public.prescription_attachments (prescription_id)
  where prescription_id is not null;

alter table public.ai_generation_requests
  add column attachment_id uuid
    references public.prescription_attachments (id) on delete restrict;

create index ai_generation_requests_attachment_idx
  on public.ai_generation_requests (attachment_id)
  where attachment_id is not null;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'prescription-private',
  'prescription-private',
  false,
  10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do nothing;

alter table public.prescription_attachments enable row level security;

revoke all on public.prescription_attachments from public, anon, authenticated;
grant select on public.prescription_attachments to authenticated;

create policy prescription_attachments_select_admin
on public.prescription_attachments for select to authenticated
using ((select private.is_super_admin()));

create policy prescription_private_objects_insert_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'prescription-private'
  and (select private.is_super_admin())
  and exists (
    select 1
    from public.prescription_attachments pa
    where pa.bucket_id = storage.objects.bucket_id
      and pa.storage_path = storage.objects.name
      and pa.uploaded_by = (select auth.uid())
      and pa.extraction_status = 'pending_upload'
  )
);

create policy prescription_private_objects_select_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'prescription-private'
  and (select private.is_super_admin())
  and exists (
    select 1
    from public.prescription_attachments pa
    where pa.bucket_id = storage.objects.bucket_id
      and pa.storage_path = storage.objects.name
  )
);

create policy prescription_private_objects_delete_pending_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'prescription-private'
  and (select private.is_super_admin())
  and exists (
    select 1
    from public.prescription_attachments pa
    where pa.bucket_id = storage.objects.bucket_id
      and pa.storage_path = storage.objects.name
      and pa.extraction_status in ('pending_upload', 'failed', 'manual_required')
  )
);

create or replace function public.create_prescription_attachment(
  p_patient_id uuid,
  p_original_filename text,
  p_mime_type text,
  p_byte_size bigint,
  p_session_date date default null,
  p_visibility public.record_visibility default 'patient',
  p_request_id uuid default gen_random_uuid()
)
returns public.prescription_attachments
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  existing_attachment_id uuid;
  attachment_id uuid := gen_random_uuid();
  extension text;
  created_attachment public.prescription_attachments%rowtype;
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
  if p_original_filename is null or btrim(p_original_filename) = '' then
    raise exception 'Choose a prescription file.' using errcode = '22023';
  end if;
  if p_mime_type not in ('application/pdf', 'image/jpeg', 'image/png') then
    raise exception 'Use a PDF, JPG, or PNG prescription.' using errcode = '22023';
  end if;
  if p_byte_size is null or p_byte_size < 1 or p_byte_size > 10485760 then
    raise exception 'Prescription files must be 10 MB or smaller.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.patients p
    where p.id = p_patient_id and p.status = 'active'
  ) then
    raise exception 'An active patient was not found.' using errcode = 'P0002';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_attachment_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'prescription_attachment.created'
    and aal.request_id = p_request_id;

  if existing_attachment_id is not null then
    select pa.* into created_attachment
    from public.prescription_attachments pa
    where pa.id = existing_attachment_id;
    if found then return created_attachment; end if;
  end if;

  extension := case p_mime_type
    when 'application/pdf' then 'pdf'
    when 'image/png' then 'png'
    else 'jpg'
  end;

  insert into public.prescription_attachments (
    id,
    patient_id,
    uploaded_by,
    storage_path,
    original_filename,
    mime_type,
    byte_size,
    session_date,
    visibility
  ) values (
    attachment_id,
    p_patient_id,
    caller_user_id,
    p_patient_id::text || '/' || attachment_id::text || '/source.' || extension,
    btrim(p_original_filename),
    p_mime_type,
    p_byte_size,
    p_session_date,
    p_visibility
  ) returning * into created_attachment;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id,
    'prescription_attachment.created',
    'prescription_attachment',
    created_attachment.id,
    created_attachment.patient_id,
    p_request_id,
    jsonb_build_object(
      'mime_type', created_attachment.mime_type,
      'byte_size', created_attachment.byte_size
    )
  );

  return created_attachment;
end;
$$;

create or replace function public.finalize_prescription_attachment(
  p_attachment_id uuid,
  p_actor_user_id uuid,
  p_request_id uuid,
  p_extracted_text text,
  p_normalized_result jsonb,
  p_provider_model text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  attachment_row public.prescription_attachments%rowtype;
  created_prescription public.prescriptions%rowtype;
  created_plan public.care_plans%rowtype;
  next_plan_version integer;
begin
  if current_user not in ('service_role', 'postgres', 'supabase_admin') then
    raise exception 'Server authorization is required.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_actor_user_id and ur.role = 'super_admin'
  ) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_extracted_text is null or btrim(p_extracted_text) = '' then
    raise exception 'The prescription text could not be read.' using errcode = '22023';
  end if;
  if p_normalized_result is null or jsonb_typeof(p_normalized_result) <> 'object' then
    raise exception 'A normalized extraction result is required.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_attachment_id::text, 0));
  select pa.* into attachment_row
  from public.prescription_attachments pa
  where pa.id = p_attachment_id
  for update;
  if not found then
    raise exception 'Prescription attachment was not found.' using errcode = 'P0002';
  end if;

  if attachment_row.extraction_status = 'succeeded' then
    return jsonb_build_object(
      'attachment_id', attachment_row.id,
      'prescription_id', attachment_row.prescription_id,
      'care_plan_id', attachment_row.care_plan_id,
      'normalized_result', attachment_row.normalized_result
    );
  end if;
  if attachment_row.processing_request_id is distinct from p_request_id
    or attachment_row.extraction_status <> 'processing' then
    raise exception 'Prescription extraction is not active.' using errcode = '55000';
  end if;

  insert into public.prescriptions (
    patient_id, source_type, raw_text, session_date, visibility, created_by
  ) values (
    attachment_row.patient_id,
    'imported',
    btrim(p_extracted_text),
    attachment_row.session_date,
    attachment_row.visibility,
    p_actor_user_id
  ) returning * into created_prescription;

  insert into public.prescription_versions (
    prescription_id, version, raw_text, visibility, change_note, created_by
  ) values (
    created_prescription.id,
    1,
    created_prescription.raw_text,
    created_prescription.visibility,
    'Initial extraction from preserved private attachment',
    p_actor_user_id
  );

  select coalesce(max(cp.version), 0) + 1 into next_plan_version
  from public.care_plans cp
  where cp.patient_id = attachment_row.patient_id;

  insert into public.care_plans (
    patient_id, prescription_id, version, name, start_date, status, created_by
  ) values (
    attachment_row.patient_id,
    created_prescription.id,
    next_plan_version,
    'Care Plan',
    current_date,
    'draft',
    p_actor_user_id
  ) returning * into created_plan;

  insert into public.ai_generation_requests (
    request_id, care_plan_id, prescription_id, requested_by,
    status, normalized_result, attachment_id
  ) values (
    p_request_id,
    created_plan.id,
    created_prescription.id,
    p_actor_user_id,
    'succeeded',
    p_normalized_result,
    attachment_row.id
  );

  update public.prescription_attachments
  set prescription_id = created_prescription.id,
      care_plan_id = created_plan.id,
      extraction_status = 'succeeded',
      normalized_result = p_normalized_result,
      provider_model = nullif(btrim(p_provider_model), ''),
      processed_at = now(),
      updated_at = now()
  where id = attachment_row.id;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values
    (
      p_actor_user_id,
      'prescription_attachment.extraction_succeeded',
      'prescription_attachment',
      attachment_row.id,
      attachment_row.patient_id,
      p_request_id,
      jsonb_build_object('prescription_id', created_prescription.id)
    ),
    (
      p_actor_user_id,
      'prescription.created',
      'prescription',
      created_prescription.id,
      attachment_row.patient_id,
      p_request_id,
      jsonb_build_object('source_type', 'imported', 'attachment_id', attachment_row.id)
    ),
    (
      p_actor_user_id,
      'care_plan.draft_created',
      'care_plan',
      created_plan.id,
      attachment_row.patient_id,
      p_request_id,
      jsonb_build_object('version', created_plan.version, 'attachment_id', attachment_row.id)
    ),
    (
      p_actor_user_id,
      'prescription.ai_actions_generated',
      'care_plan',
      created_plan.id,
      attachment_row.patient_id,
      p_request_id,
      jsonb_build_object(
        'attachment_id', attachment_row.id,
        'action_count', jsonb_array_length(p_normalized_result -> 'actions')
      )
    );

  return jsonb_build_object(
    'attachment_id', attachment_row.id,
    'prescription_id', created_prescription.id,
    'care_plan_id', created_plan.id,
    'normalized_result', p_normalized_result
  );
end;
$$;

create or replace function public.save_ai_plan_action(
  p_care_plan_id uuid,
  p_type text,
  p_title text,
  p_frequency_rule jsonb,
  p_start_date date,
  p_source_evidence text,
  p_ai_request_id uuid,
  p_action_id uuid default null,
  p_instruction text default null,
  p_count_target integer default null,
  p_duration_minutes integer default null,
  p_time_window text default null,
  p_exact_time time default null,
  p_end_date date default null,
  p_review_status public.action_review_status default 'approved',
  p_reminder_enabled boolean default false,
  p_content_item_id uuid default null,
  p_resource_usage_note text default null,
  p_attachment_id uuid default null,
  p_confidence numeric default null,
  p_ambiguities jsonb default '[]'::jsonb,
  p_human_edited boolean default false,
  p_request_id uuid default gen_random_uuid()
)
returns public.plan_actions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved_action public.plan_actions%rowtype;
  patient_id_value uuid;
begin
  if p_source_evidence is null or btrim(p_source_evidence) = '' then
    raise exception 'Source evidence is required for an AI action.' using errcode = '22023';
  end if;
  if char_length(btrim(p_source_evidence)) > 600 then
    raise exception 'Source evidence is too long.' using errcode = '22023';
  end if;
  if p_ambiguities is null or jsonb_typeof(p_ambiguities) <> 'array' then
    raise exception 'AI ambiguities must be an array.' using errcode = '22023';
  end if;
  if p_confidence is not null and (p_confidence < 0 or p_confidence > 1) then
    raise exception 'AI confidence must be between 0 and 1.' using errcode = '22023';
  end if;

  saved_action := public.save_plan_action(
    p_care_plan_id,
    p_type,
    p_title,
    p_frequency_rule,
    p_start_date,
    p_action_id,
    p_instruction,
    p_count_target,
    p_duration_minutes,
    p_time_window,
    p_exact_time,
    p_end_date,
    p_review_status,
    p_reminder_enabled,
    p_content_item_id,
    p_resource_usage_note,
    p_request_id
  );

  update public.plan_actions
  set ai_source = jsonb_build_object(
        'request_id', p_ai_request_id,
        'attachment_id', p_attachment_id,
        'source_evidence', btrim(p_source_evidence),
        'confidence', p_confidence,
        'ambiguities', p_ambiguities,
        'human_approved', p_review_status = 'approved',
        'human_edited', p_human_edited
      ),
      updated_at = now()
  where id = saved_action.id
  returning * into saved_action;

  select cp.patient_id into patient_id_value
  from public.care_plans cp where cp.id = p_care_plan_id;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    (select auth.uid()),
    'plan_action.ai_review_approved',
    'plan_action',
    saved_action.id,
    patient_id_value,
    gen_random_uuid(),
    jsonb_build_object(
      'care_plan_id', p_care_plan_id,
      'ai_request_id', p_ai_request_id,
      'attachment_id', p_attachment_id
    )
  );

  if p_human_edited then
    insert into public.admin_audit_logs (
      actor_user_id, action, entity_type, entity_id, patient_id,
      request_id, metadata
    ) values (
      (select auth.uid()),
      'plan_action.ai_review_edited',
      'plan_action',
      saved_action.id,
      patient_id_value,
      gen_random_uuid(),
      jsonb_build_object('ai_request_id', p_ai_request_id)
    );
  end if;

  return saved_action;
end;
$$;

create or replace function public.record_ai_suggestion_deleted(
  p_care_plan_id uuid,
  p_ai_request_id uuid,
  p_suggestion_index integer,
  p_request_id uuid default gen_random_uuid()
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  patient_id_value uuid;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  select cp.patient_id into patient_id_value
  from public.care_plans cp
  where cp.id = p_care_plan_id and cp.status = 'draft';
  if patient_id_value is null then
    raise exception 'An editable draft plan was not found.' using errcode = 'P0002';
  end if;
  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id,
    'plan_action.ai_suggestion_deleted',
    'care_plan',
    p_care_plan_id,
    patient_id_value,
    p_request_id,
    jsonb_build_object(
      'ai_request_id', p_ai_request_id,
      'suggestion_index', p_suggestion_index
    )
  );
end;
$$;

revoke execute on function public.create_prescription_attachment(
  uuid, text, text, bigint, date, public.record_visibility, uuid
) from public, anon;
grant execute on function public.create_prescription_attachment(
  uuid, text, text, bigint, date, public.record_visibility, uuid
) to authenticated;

revoke execute on function public.finalize_prescription_attachment(
  uuid, uuid, uuid, text, jsonb, text
) from public, anon, authenticated;
grant execute on function public.finalize_prescription_attachment(
  uuid, uuid, uuid, text, jsonb, text
) to service_role;

revoke execute on function public.save_ai_plan_action(
  uuid, text, text, jsonb, date, text, uuid, uuid, text, integer, integer,
  text, time, date, public.action_review_status, boolean, uuid, text, uuid,
  numeric, jsonb, boolean, uuid
) from public, anon;
grant execute on function public.save_ai_plan_action(
  uuid, text, text, jsonb, date, text, uuid, uuid, text, integer, integer,
  text, time, date, public.action_review_status, boolean, uuid, text, uuid,
  numeric, jsonb, boolean, uuid
) to authenticated;

revoke execute on function public.record_ai_suggestion_deleted(
  uuid, uuid, integer, uuid
) from public, anon;
grant execute on function public.record_ai_suggestion_deleted(
  uuid, uuid, integer, uuid
) to authenticated;

comment on table public.prescription_attachments is
  'Private, immutable source documents for prescription extraction. Patients have no direct access.';
comment on function public.create_prescription_attachment(
  uuid, text, text, bigint, date, public.record_visibility, uuid
) is
  'Creates an audited Super Admin-only upload intent for a validated private prescription document.';
comment on function public.finalize_prescription_attachment(
  uuid, uuid, uuid, text, jsonb, text
) is
  'Service-only transaction that preserves extracted text, creates a linked draft plan, and stores normalized AI suggestions.';

