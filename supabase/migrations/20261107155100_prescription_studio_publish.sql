-- The practitioner's explicit publish action approves the exact saved
-- actions in the Studio. The older individually approved workflow remains available.
create function public.publish_prescription_studio(
  p_plan_id uuid, p_actions jsonb, p_request_id uuid
)
returns public.care_plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  plan_row public.care_plans;
  action_count integer;
begin
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_request_id is null or jsonb_typeof(p_actions) is distinct from 'array' then
    raise exception 'The saved action list is required.' using errcode = '22023';
  end if;
  action_count := jsonb_array_length(p_actions);
  if action_count not between 1 and 100 then
    raise exception 'Select a plan with 1 to 100 saved actions.' using errcode = '22023';
  end if;

  -- Use the same lock order as publish_care_plan and the Studio mutations.
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into plan_row from public.care_plans where id = p_plan_id for update;
  if not found then
    raise exception 'Care plan was not found.' using errcode = 'P0002';
  end if;
  if plan_row.status = 'active' then return plan_row; end if;
  if plan_row.status <> 'draft' then
    raise exception 'This plan version cannot be published.' using errcode = '22023';
  end if;

  if action_count <> (
    select count(*) from public.plan_actions
    where care_plan_id = p_plan_id and review_status <> 'rejected'
  ) or action_count <> (
    select count(distinct pa.id)
    from jsonb_to_recordset(p_actions) as snapshot(id uuid, revision timestamptz)
    join public.plan_actions pa on pa.id = snapshot.id and pa.updated_at = snapshot.revision
    where pa.care_plan_id = p_plan_id and pa.review_status <> 'rejected'
  ) then
    raise exception 'The saved actions changed before publication.' using errcode = '40001';
  end if;

  if exists (
    select 1 from public.plan_actions
    where care_plan_id = p_plan_id and review_status <> 'rejected'
      and reminder_enabled and exact_time is null
  ) then
    raise exception 'Every enabled reminder needs an exact time.' using errcode = '22023';
  end if;

  update public.plan_actions set review_status = 'approved'
  where care_plan_id = p_plan_id and review_status in ('draft', 'needs_review');

  -- Existing resource, placeholder, and publication checks run inside the
  -- transaction. A failed publication rolls back the status changes above.
  return public.publish_care_plan(p_plan_id, p_request_id);
end;
$$;

revoke execute on function public.publish_prescription_studio(uuid, jsonb, uuid) from public, anon;
grant execute on function public.publish_prescription_studio(uuid, jsonb, uuid) to authenticated;
