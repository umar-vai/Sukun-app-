-- Preserve the meaning of publication metadata when an abandoned draft is
-- explicitly archived without ever being published. The old constraint only
-- allowed non-draft states with published_at/published_by, so archiving an
-- unapproved draft otherwise failed or would require fabricating a publish.
-- Existing published plans still require their original publication fields.
alter table public.care_plans
  drop constraint care_plans_publish_consistency;
alter table public.care_plans
  add constraint care_plans_publish_consistency check (
    (status = 'draft' and published_at is null and published_by is null)
    or (
      status = 'archived'
      and archived_at is not null
      and published_at is null
      and published_by is null
    )
    or (
      status <> 'draft'
      and published_at is not null
      and published_by is not null
    )
  );

-- Explicit, non-destructive recovery for an uploaded prescription blocked by
-- a *different* existing draft. Never replace a linked prescription silently.
-- Only an authenticated Super Admin can archive an actionless DRAFT,
-- after confirming in the client; original prescription/history are retained.
create or replace function public.archive_empty_draft_for_prescription_import(
  p_patient_id uuid,
  p_care_plan_id uuid,
  p_request_id uuid
)
returns public.care_plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  plan_row public.care_plans%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_patient_id is null or p_care_plan_id is null or p_request_id is null then
    raise exception 'Patient, draft, and request IDs are required.' using errcode = '22023';
  end if;

  -- Synchronize with finalize_prescription_attachment and lock the specific
  -- draft so a concurrent review/import cannot replace a different plan.
  perform pg_advisory_xact_lock(hashtextextended(p_patient_id::text, 1));
  select cp.* into plan_row
  from public.care_plans cp
  where cp.id = p_care_plan_id and cp.patient_id = p_patient_id
  for update;
  if not found then
    raise exception 'The selected draft was not found.' using errcode = 'P0002';
  end if;

  -- Permit an idempotent client retry only for an archive recorded by this
  -- same actor, operation, request ID and exact plan.
  if plan_row.status = 'archived' and exists (
    select 1 from public.admin_audit_logs aal
    where aal.actor_user_id = caller_id
      and aal.action = 'care_plan.empty_draft_archived_for_import'
      and aal.entity_id = p_care_plan_id
      and aal.request_id = p_request_id
  ) then
    return plan_row;
  end if;
  if plan_row.status <> 'draft' then
    raise exception 'Only a draft can be cleared for a new prescription.'
      using errcode = '55000';
  end if;
  if exists (
    select 1 from public.plan_actions pa
    where pa.care_plan_id = p_care_plan_id
  ) or exists (
    select 1 from public.task_instances ti
    join public.plan_actions pa on pa.id = ti.plan_action_id
    where pa.care_plan_id = p_care_plan_id
  ) then
    raise exception 'This draft contains work. Review it instead of archiving automatically.'
      using errcode = '55000';
  end if;

  update public.care_plans
  set status = 'archived', archived_at = now(), updated_at = now()
  where id = p_care_plan_id and patient_id = p_patient_id and status = 'draft'
  returning * into plan_row;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_id,
    'care_plan.empty_draft_archived_for_import',
    'care_plan',
    plan_row.id,
    plan_row.patient_id,
    p_request_id,
    jsonb_build_object(
      'plan_version', plan_row.version,
      'original_prescription_id', plan_row.prescription_id
    )
  ) on conflict (actor_user_id, action, request_id)
    where request_id is not null do nothing;

  return plan_row;
end;
$$;
revoke all on function public.archive_empty_draft_for_prescription_import(uuid,uuid,uuid) from public, anon;
grant execute on function public.archive_empty_draft_for_prescription_import(uuid,uuid,uuid) to authenticated;
comment on function public.archive_empty_draft_for_prescription_import(uuid,uuid,uuid)
is 'Authenticated super-admin-confirmed archive of an actionless draft only, retaining linked prescription and audit history.';
