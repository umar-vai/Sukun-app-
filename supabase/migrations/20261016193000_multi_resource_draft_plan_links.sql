-- Smart Prescription v2: atomic, reviewed multi-resource linking for draft care actions.
-- Uses existing public.plan_action_resources, including its RLS and immutable
-- published-plan trigger. Never permits client-side automatic publication.

create or replace function public.replace_draft_action_resources(
  p_action_id uuid,
  p_resource_ids uuid[],
  p_request_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  target_patient_id uuid;
  requested_count integer;
  previous_count integer;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_action_id is null or p_request_id is null or p_resource_ids is null then
    raise exception 'Action, resource list, and request ID are required.'
      using errcode = '22023';
  end if;
  requested_count := cardinality(p_resource_ids);
  if requested_count > 16
    or array_position(p_resource_ids, null) is not null
    or requested_count <> (
      select count(distinct resource_id)
      from unnest(p_resource_ids) resource_id
    )
  then
    raise exception 'Resource IDs must be unique and contain at most 16 items.'
      using errcode = '22023';
  end if;

  -- Coordinate with action editors and plan publishing. No patient mutation
  -- is performed until both rows are locked and the draft status is checked.
  perform pg_advisory_xact_lock(hashtextextended(p_action_id::text, 0));
  select cp.patient_id into target_patient_id
  from public.plan_actions pa
  join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = p_action_id
    and cp.status = 'draft'
    and pa.review_status <> 'rejected'
  for update of pa, cp;
  if not found then
    raise exception 'An editable draft action was not found.'
      using errcode = 'P0002';
  end if;

  select cardinality(p_resource_ids) into previous_count
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'plan_action.resources_replaced'
    and aal.request_id = p_request_id
    and aal.entity_id = p_action_id
  limit 1;
  if found then
    return previous_count;
  end if;
  if exists (
    select 1 from public.admin_audit_logs aal
    where aal.actor_user_id = caller_user_id
      and aal.action = 'plan_action.resources_replaced'
      and aal.request_id = p_request_id
      and aal.entity_id <> p_action_id
  ) then
    raise exception 'Request ID cannot be reused for a different action.'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from unnest(p_resource_ids) requested(resource_id)
    left join public.content_items ci on ci.id = requested.resource_id
    where ci.id is null
      or ci.status <> 'published'
      or ci.visibility not in ('public', 'patient_only', 'assigned_only')
      or (ci.type = 'quran' and ci.verification_status is distinct from 'verified')
  ) then
    raise exception 'Only approved patient-accessible resources can be linked.'
      using errcode = '22023';
  end if;

  delete from public.plan_action_resources
  where plan_action_id = p_action_id;

  insert into public.plan_action_resources(
    plan_action_id, content_item_id, created_by
  )
  select p_action_id, resource_id, caller_user_id
  from unnest(p_resource_ids) resource_id;

  insert into public.admin_audit_logs(
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id, 'plan_action.resources_replaced', 'plan_action',
    p_action_id, target_patient_id, p_request_id,
    jsonb_build_object('resource_count', requested_count)
  );

  return requested_count;
end;
$$;

revoke all on function public.replace_draft_action_resources(uuid, uuid[], uuid)
  from public, anon;
grant execute on function public.replace_draft_action_resources(uuid, uuid[], uuid)
  to authenticated;

comment on function public.replace_draft_action_resources(uuid, uuid[], uuid) is
  'Audited Super Admin-only atomic replacement of approved patient-facing resource links on an editable draft action.';
