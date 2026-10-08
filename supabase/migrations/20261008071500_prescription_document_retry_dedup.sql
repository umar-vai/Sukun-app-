-- Make prescription document retries safe when the same patient already has
-- the empty draft created by a prior successful extraction of the same file.
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
  retry_source public.prescription_attachments%rowtype;
  existing_draft public.care_plans%rowtype;
  created_prescription public.prescriptions%rowtype;
  created_plan public.care_plans%rowtype;
  existing_draft_action_count bigint;
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

  -- Serialize finalization per patient as well as per attachment so two uploads
  -- cannot both attempt to create the one allowed draft plan.
  perform pg_advisory_xact_lock(
    hashtextextended(attachment_row.patient_id::text, 1)
  );

  select cp.* into existing_draft
  from public.care_plans cp
  where cp.patient_id = attachment_row.patient_id
    and cp.status = 'draft'
  for update;

  if found then
    select count(*) into existing_draft_action_count
    from public.plan_actions pa
    where pa.care_plan_id = existing_draft.id;

    if existing_draft_action_count > 0 then
      raise exception
        'This patient already has a draft care plan with actions. Review or finish that draft before importing another prescription.'
        using errcode = '55000';
    end if;

    -- A retry of the exact same uploaded file should reuse the prescription and
    -- empty draft created by the prior successful extraction instead of trying
    -- to create a second draft and violating the one-draft-per-patient rule.
    select pa.* into retry_source
    from public.prescription_attachments pa
    where pa.patient_id = attachment_row.patient_id
      and pa.id <> attachment_row.id
      and pa.extraction_status = 'succeeded'
      and pa.original_filename = attachment_row.original_filename
      and pa.mime_type = attachment_row.mime_type
      and pa.byte_size = attachment_row.byte_size
      and pa.care_plan_id = existing_draft.id
      and pa.prescription_id = existing_draft.prescription_id
    order by pa.processed_at desc nulls last, pa.created_at desc
    limit 1;

    if found then
      insert into public.ai_generation_requests (
        request_id, care_plan_id, prescription_id, requested_by,
        status, normalized_result, attachment_id
      ) values (
        p_request_id,
        existing_draft.id,
        retry_source.prescription_id,
        p_actor_user_id,
        'succeeded',
        p_normalized_result,
        attachment_row.id
      );

      update public.prescription_attachments
      set prescription_id = retry_source.prescription_id,
          care_plan_id = existing_draft.id,
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
          'prescription_attachment.retry_reused',
          'prescription_attachment',
          attachment_row.id,
          attachment_row.patient_id,
          p_request_id,
          jsonb_build_object(
            'source_attachment_id', retry_source.id,
            'prescription_id', retry_source.prescription_id,
            'care_plan_id', existing_draft.id
          )
        ),
        (
          p_actor_user_id,
          'prescription.ai_actions_generated',
          'care_plan',
          existing_draft.id,
          attachment_row.patient_id,
          p_request_id,
          jsonb_build_object(
            'attachment_id', attachment_row.id,
            'action_count', jsonb_array_length(p_normalized_result -> 'actions'),
            'retry_reused', true
          )
        );

      return jsonb_build_object(
        'attachment_id', attachment_row.id,
        'prescription_id', retry_source.prescription_id,
        'care_plan_id', existing_draft.id,
        'normalized_result', p_normalized_result
      );
    end if;

    raise exception
      'This patient already has an empty draft from another prescription. Review or finish that draft before importing a different prescription.'
      using errcode = '55000';
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

comment on function public.finalize_prescription_attachment(
  uuid, uuid, uuid, text, jsonb, text
) is
  'Service-only transaction that finalizes prescription extraction and safely reuses an empty draft for exact same-file retries.';
