-- Preserve the practitioner's resource order and usage note on draft actions.
-- Existing published links keep their data and deterministic legacy title order.
alter table public.plan_action_resources
  add column sort_order integer not null default 0
    check (sort_order >= 0);

create index plan_action_resources_action_order_idx
  on public.plan_action_resources(plan_action_id, sort_order);

-- Keep the existing invoker role/RLS and draft-only checks. This replaces the
-- already-deployed RPC body without changing its signature or grants.

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
  noted_content_id uuid;
  noted_usage_note text;
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

  select (aal.metadata ->> 'resource_count')::integer into previous_count
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'plan_action.resources_replaced'
    and aal.request_id = p_request_id
    and aal.entity_id = p_action_id
  limit 1;
  if found then
    if not exists (
      select 1 from public.admin_audit_logs aal
      where aal.actor_user_id = caller_user_id
        and aal.action = 'plan_action.resources_replaced'
        and aal.request_id = p_request_id
        and aal.entity_id = p_action_id
        and aal.metadata ->> 'resource_fingerprint' = md5(
          (select coalesce(string_agg(resource_id::text, ',' order by resource_id::text), '')
           from unnest(p_resource_ids) resource_id)
        )
    ) then
      raise exception 'A request ID cannot be reused with different resources.'
        using errcode = '22023';
    end if;
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

  -- save_plan_action writes the currently edited note to its single anchor
  -- link before this RPC replaces the full selection. Preserve that note.
  select content_item_id, usage_note
    into noted_content_id, noted_usage_note
  from public.plan_action_resources
  where plan_action_id = p_action_id and usage_note is not null
  order by created_at desc, content_item_id
  limit 1;

  delete from public.plan_action_resources
  where plan_action_id = p_action_id;

  insert into public.plan_action_resources(
    plan_action_id, content_item_id, usage_note, sort_order, created_by
  )
  select p_action_id, requested.resource_id,
    case when requested.resource_id = noted_content_id
      then noted_usage_note else null end,
    (requested.ordinality - 1)::integer, caller_user_id
  from unnest(p_resource_ids) with ordinality
    as requested(resource_id, ordinality);

  insert into public.admin_audit_logs(
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id, 'plan_action.resources_replaced', 'plan_action',
    p_action_id, target_patient_id, p_request_id,
    jsonb_build_object(
      'resource_count', requested_count,
      'resource_fingerprint', md5(
        (select coalesce(string_agg(resource_id::text, ',' order by resource_id::text), '')
         from unnest(p_resource_ids) resource_id)
      )
    )
  );

  return requested_count;
end;
$$;

revoke all on function public.replace_draft_action_resources(uuid, uuid[], uuid)
  from public, anon;
grant execute on function public.replace_draft_action_resources(uuid, uuid[], uuid)
  to authenticated;

comment on function public.replace_draft_action_resources(uuid, uuid[], uuid) is
  'Audited Super Admin-only atomic ordered replacement of approved patient-facing draft links, preserving the edited usage note.';
