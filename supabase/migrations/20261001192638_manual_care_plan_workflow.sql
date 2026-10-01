-- Manual care-plan workflow. All client-callable functions are SECURITY INVOKER,
-- retain RLS enforcement, and independently verify the database-backed admin role.

create unique index care_plans_one_draft_per_patient_idx
  on public.care_plans (patient_id)
  where status = 'draft';

create or replace function private.prevent_non_draft_action_rewrite()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_plan_id uuid;
  target_status public.care_plan_status;
begin
  target_plan_id := case
    when tg_op = 'DELETE' then old.care_plan_id
    else new.care_plan_id
  end;

  select cp.status into target_status
  from public.care_plans cp
  where cp.id = target_plan_id;

  if target_status is distinct from 'draft'::public.care_plan_status then
    raise exception 'Published care plan actions cannot be rewritten.'
      using errcode = '55000';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger plan_actions_prevent_non_draft_rewrite
before update or delete on public.plan_actions
for each row execute function private.prevent_non_draft_action_rewrite();

create or replace function private.prevent_non_draft_resource_rewrite()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_action_id uuid;
  target_status public.care_plan_status;
begin
  target_action_id := case
    when tg_op = 'DELETE' then old.plan_action_id
    else new.plan_action_id
  end;

  select cp.status into target_status
  from public.plan_actions pa
  join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = target_action_id;

  if target_status is distinct from 'draft'::public.care_plan_status then
    raise exception 'Published care plan resources cannot be rewritten.'
      using errcode = '55000';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger plan_action_resources_prevent_non_draft_rewrite
before insert or update or delete on public.plan_action_resources
for each row execute function private.prevent_non_draft_resource_rewrite();

create or replace function public.create_draft_care_plan(
  p_patient_id uuid,
  p_name text,
  p_start_date date,
  p_end_date date default null,
  p_prescription_id uuid default null,
  p_copy_from_plan_id uuid default null,
  p_request_id uuid default gen_random_uuid()
)
returns public.care_plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  existing_plan_id uuid;
  source_plan public.care_plans%rowtype;
  source_action public.plan_actions%rowtype;
  created_plan public.care_plans%rowtype;
  created_action_id uuid;
  next_version integer;
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
  if p_name is null or btrim(p_name) = '' then
    raise exception 'Plan name is required.' using errcode = '22023';
  end if;
  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'Plan end date cannot be before its start date.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  select aal.entity_id into existing_plan_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'care_plan.draft_created'
    and aal.request_id = p_request_id;

  if existing_plan_id is not null then
    select cp.* into created_plan
    from public.care_plans cp
    where cp.id = existing_plan_id;
    if found then return created_plan; end if;
  end if;

  perform 1
  from public.patients p
  where p.id = p_patient_id and p.status = 'active'
  for update;
  if not found then
    raise exception 'An active patient was not found.' using errcode = 'P0002';
  end if;

  select cp.* into created_plan
  from public.care_plans cp
  where cp.patient_id = p_patient_id and cp.status = 'draft'
  limit 1;
  if found then return created_plan; end if;

  if p_prescription_id is not null and not exists (
    select 1 from public.prescriptions p
    where p.id = p_prescription_id
      and p.patient_id = p_patient_id
      and p.archived_at is null
  ) then
    raise exception 'Prescription was not found for this patient.' using errcode = 'P0002';
  end if;

  if p_copy_from_plan_id is not null then
    select cp.* into source_plan
    from public.care_plans cp
    where cp.id = p_copy_from_plan_id
      and cp.patient_id = p_patient_id
      and cp.status <> 'draft';
    if not found then
      raise exception 'Source plan was not found.' using errcode = 'P0002';
    end if;
  end if;

  select coalesce(max(cp.version), 0) + 1 into next_version
  from public.care_plans cp
  where cp.patient_id = p_patient_id;

  insert into public.care_plans (
    patient_id,
    prescription_id,
    version,
    name,
    start_date,
    end_date,
    status,
    created_by
  ) values (
    p_patient_id,
    coalesce(p_prescription_id, source_plan.prescription_id),
    next_version,
    btrim(p_name),
    p_start_date,
    p_end_date,
    'draft',
    caller_user_id
  ) returning * into created_plan;

  if p_copy_from_plan_id is not null then
    for source_action in
      select pa.*
      from public.plan_actions pa
      where pa.care_plan_id = p_copy_from_plan_id
        and pa.review_status <> 'rejected'
      order by pa.sort_order, pa.created_at
    loop
      insert into public.plan_actions (
        care_plan_id, type, title, instruction, count_target,
        duration_minutes, frequency_rule, time_window, exact_time,
        start_date, end_date, sort_order, review_status,
        reminder_enabled, ai_source, created_by
      ) values (
        created_plan.id,
        source_action.type,
        source_action.title,
        source_action.instruction,
        source_action.count_target,
        source_action.duration_minutes,
        source_action.frequency_rule,
        source_action.time_window,
        source_action.exact_time,
        p_start_date,
        p_end_date,
        source_action.sort_order,
        'needs_review',
        source_action.reminder_enabled,
        null,
        caller_user_id
      ) returning id into created_action_id;

      insert into public.plan_action_resources (
        plan_action_id, content_item_id, usage_note, created_by
      )
      select
        created_action_id, par.content_item_id, par.usage_note, caller_user_id
      from public.plan_action_resources par
      where par.plan_action_id = source_action.id;
    end loop;
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id,
    'care_plan.draft_created',
    'care_plan',
    created_plan.id,
    created_plan.patient_id,
    p_request_id,
    jsonb_build_object(
      'version', created_plan.version,
      'copied_from_plan_id', p_copy_from_plan_id
    )
  );

  return created_plan;
end;
$$;

create or replace function public.save_plan_action(
  p_care_plan_id uuid,
  p_type text,
  p_title text,
  p_frequency_rule jsonb,
  p_start_date date,
  p_action_id uuid default null,
  p_instruction text default null,
  p_count_target integer default null,
  p_duration_minutes integer default null,
  p_time_window text default null,
  p_exact_time time default null,
  p_end_date date default null,
  p_review_status public.action_review_status default 'draft',
  p_reminder_enabled boolean default false,
  p_content_item_id uuid default null,
  p_resource_usage_note text default null,
  p_request_id uuid default gen_random_uuid()
)
returns public.plan_actions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  existing_action_id uuid;
  plan_row public.care_plans%rowtype;
  saved_action public.plan_actions%rowtype;
  next_sort_order integer;
  audit_action text := case
    when p_action_id is null then 'plan_action.created'
    else 'plan_action.updated'
  end;
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

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_action_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = audit_action
    and aal.request_id = p_request_id;
  if existing_action_id is not null then
    select pa.* into saved_action
    from public.plan_actions pa where pa.id = existing_action_id;
    if found then return saved_action; end if;
  end if;

  select cp.* into plan_row
  from public.care_plans cp
  where cp.id = p_care_plan_id and cp.status = 'draft'
  for update;
  if not found then
    raise exception 'An editable draft plan was not found.' using errcode = 'P0002';
  end if;

  if p_type is null or btrim(p_type) = ''
    or p_title is null or btrim(p_title) = '' then
    raise exception 'Action type and title are required.' using errcode = '22023';
  end if;
  if p_count_target is not null and p_count_target <= 0 then
    raise exception 'Count must be positive.' using errcode = '22023';
  end if;
  if p_duration_minutes is not null and p_duration_minutes <= 0 then
    raise exception 'Duration must be positive.' using errcode = '22023';
  end if;
  if p_time_window is not null and p_time_window not in (
    'morning', 'afternoon', 'evening', 'night', 'anytime'
  ) then
    raise exception 'Unsupported time window.' using errcode = '22023';
  end if;
  if p_review_status not in ('draft', 'needs_review', 'approved') then
    raise exception 'Unsupported editable review status.' using errcode = '22023';
  end if;
  if p_start_date < plan_row.start_date
    or (plan_row.end_date is not null and p_start_date > plan_row.end_date)
    or (p_end_date is not null and p_end_date < p_start_date)
    or (
      plan_row.end_date is not null
      and p_end_date is not null
      and p_end_date > plan_row.end_date
    ) then
    raise exception 'Action dates must stay within the plan dates.' using errcode = '22023';
  end if;
  if p_frequency_rule is null
    or jsonb_typeof(p_frequency_rule) <> 'object'
    or coalesce(p_frequency_rule ->> 'type', '') not in ('daily', 'weekly') then
    raise exception 'Frequency must be daily or weekly.' using errcode = '22023';
  end if;
  if p_frequency_rule ->> 'type' = 'daily' and (
    coalesce(p_frequency_rule ->> 'interval', '') !~ '^[1-9][0-9]*$'
  ) then
    raise exception 'Daily frequency requires a positive interval.' using errcode = '22023';
  end if;
  if p_frequency_rule ->> 'type' = 'weekly' and (
    jsonb_typeof(p_frequency_rule -> 'weekdays') is distinct from 'array'
    or jsonb_array_length(p_frequency_rule -> 'weekdays') = 0
    or exists (
      select 1
      from jsonb_array_elements_text(p_frequency_rule -> 'weekdays') weekday
      where weekday !~ '^[1-7]$'
    )
    or jsonb_array_length(p_frequency_rule -> 'weekdays') <> (
      select count(distinct weekday)
      from jsonb_array_elements_text(p_frequency_rule -> 'weekdays') weekday
    )
  ) then
    raise exception 'Weekly frequency requires weekdays numbered 1 through 7.'
      using errcode = '22023';
  end if;

  if p_content_item_id is not null and not exists (
    select 1
    from public.content_items ci
    where ci.id = p_content_item_id
      and ci.status = 'published'
      and ci.visibility in ('public', 'patient_only', 'assigned_only')
  ) then
    raise exception 'Only a published patient-accessible resource can be linked.'
      using errcode = '22023';
  end if;

  if p_action_id is null then
    select coalesce(max(pa.sort_order), -1) + 1 into next_sort_order
    from public.plan_actions pa
    where pa.care_plan_id = p_care_plan_id
      and pa.review_status <> 'rejected';

    insert into public.plan_actions (
      care_plan_id, type, title, instruction, count_target,
      duration_minutes, frequency_rule, time_window, exact_time,
      start_date, end_date, sort_order, review_status,
      reminder_enabled, created_by
    ) values (
      p_care_plan_id,
      btrim(p_type),
      btrim(p_title),
      nullif(btrim(p_instruction), ''),
      p_count_target,
      p_duration_minutes,
      p_frequency_rule,
      p_time_window,
      p_exact_time,
      p_start_date,
      p_end_date,
      next_sort_order,
      p_review_status,
      p_reminder_enabled,
      caller_user_id
    ) returning * into saved_action;
  else
    select pa.* into saved_action
    from public.plan_actions pa
    where pa.id = p_action_id
      and pa.care_plan_id = p_care_plan_id
      and pa.review_status <> 'rejected'
    for update;
    if not found then
      raise exception 'Editable action was not found.' using errcode = 'P0002';
    end if;

    update public.plan_actions
    set type = btrim(p_type),
        title = btrim(p_title),
        instruction = nullif(btrim(p_instruction), ''),
        count_target = p_count_target,
        duration_minutes = p_duration_minutes,
        frequency_rule = p_frequency_rule,
        time_window = p_time_window,
        exact_time = p_exact_time,
        start_date = p_start_date,
        end_date = p_end_date,
        review_status = p_review_status,
        reminder_enabled = p_reminder_enabled
    where id = p_action_id
    returning * into saved_action;
  end if;

  delete from public.plan_action_resources par
  where par.plan_action_id = saved_action.id;
  if p_content_item_id is not null then
    insert into public.plan_action_resources (
      plan_action_id, content_item_id, usage_note, created_by
    ) values (
      saved_action.id,
      p_content_item_id,
      nullif(btrim(p_resource_usage_note), ''),
      caller_user_id
    );
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id,
    audit_action,
    'plan_action',
    saved_action.id,
    plan_row.patient_id,
    p_request_id,
    jsonb_build_object(
      'care_plan_id', saved_action.care_plan_id,
      'review_status', saved_action.review_status,
      'resource_linked', p_content_item_id is not null
    )
  );

  return saved_action;
end;
$$;

create or replace function public.reorder_plan_actions(
  p_care_plan_id uuid,
  p_action_ids uuid[],
  p_request_id uuid default gen_random_uuid()
)
returns setof public.plan_actions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  patient_id_value uuid;
  expected_count integer;
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

  select cp.patient_id into patient_id_value
  from public.care_plans cp
  where cp.id = p_care_plan_id and cp.status = 'draft'
  for update;
  if not found then
    raise exception 'An editable draft plan was not found.' using errcode = 'P0002';
  end if;

  select count(*) into expected_count
  from public.plan_actions pa
  where pa.care_plan_id = p_care_plan_id
    and pa.review_status <> 'rejected';

  if p_action_ids is null
    or cardinality(p_action_ids) <> expected_count
    or cardinality(p_action_ids) <> (
      select count(distinct action_id) from unnest(p_action_ids) action_id
    )
    or exists (
      select 1 from unnest(p_action_ids) action_id
      where not exists (
        select 1 from public.plan_actions pa
        where pa.id = action_id
          and pa.care_plan_id = p_care_plan_id
          and pa.review_status <> 'rejected'
      )
    ) then
    raise exception 'Reorder request must include each active draft action exactly once.'
      using errcode = '22023';
  end if;

  update public.plan_actions pa
  set sort_order = ordering.position - 1
  from unnest(p_action_ids) with ordinality ordering(action_id, position)
  where pa.id = ordering.action_id;

  if not exists (
    select 1 from public.admin_audit_logs aal
    where aal.actor_user_id = caller_user_id
      and aal.action = 'plan_action.reordered'
      and aal.request_id = p_request_id
  ) then
    insert into public.admin_audit_logs (
      actor_user_id, action, entity_type, entity_id, patient_id,
      request_id, metadata
    ) values (
      caller_user_id,
      'plan_action.reordered',
      'care_plan',
      p_care_plan_id,
      patient_id_value,
      p_request_id,
      jsonb_build_object('action_count', expected_count)
    );
  end if;

  return query
  select pa.* from public.plan_actions pa
  where pa.care_plan_id = p_care_plan_id
    and pa.review_status <> 'rejected'
  order by pa.sort_order, pa.created_at;
end;
$$;

create or replace function public.reject_plan_action(
  p_action_id uuid,
  p_request_id uuid default gen_random_uuid()
)
returns public.plan_actions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  patient_id_value uuid;
  rejected_action public.plan_actions%rowtype;
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

  select cp.patient_id into patient_id_value
  from public.plan_actions pa
  join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = p_action_id and cp.status = 'draft'
  for update of pa;
  if not found then
    raise exception 'Editable action was not found.' using errcode = 'P0002';
  end if;

  update public.plan_actions
  set review_status = 'rejected'
  where id = p_action_id
  returning * into rejected_action;

  if not exists (
    select 1 from public.admin_audit_logs aal
    where aal.actor_user_id = caller_user_id
      and aal.action = 'plan_action.rejected'
      and aal.request_id = p_request_id
  ) then
    insert into public.admin_audit_logs (
      actor_user_id, action, entity_type, entity_id, patient_id,
      request_id, metadata
    ) values (
      caller_user_id,
      'plan_action.rejected',
      'plan_action',
      rejected_action.id,
      patient_id_value,
      p_request_id,
      jsonb_build_object('care_plan_id', rejected_action.care_plan_id)
    );
  end if;

  return rejected_action;
end;
$$;

create or replace function public.publish_care_plan(
  p_care_plan_id uuid,
  p_request_id uuid default gen_random_uuid()
)
returns public.care_plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  plan_row public.care_plans%rowtype;
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

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select cp.* into plan_row
  from public.care_plans cp
  where cp.id = p_care_plan_id
  for update;
  if not found then
    raise exception 'Care plan was not found.' using errcode = 'P0002';
  end if;
  if plan_row.status = 'active' then return plan_row; end if;
  if plan_row.status <> 'draft' then
    raise exception 'Only a draft plan can be published.' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.plan_actions pa
    where pa.care_plan_id = p_care_plan_id
      and pa.review_status = 'approved'
  ) then
    raise exception 'At least one approved action is required.' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.plan_actions pa
    where pa.care_plan_id = p_care_plan_id
      and pa.review_status not in ('approved', 'rejected')
  ) then
    raise exception 'Resolve every draft or needs-review action before publishing.'
      using errcode = '22023';
  end if;
  if exists (
    select 1
    from public.plan_action_resources par
    join public.plan_actions pa on pa.id = par.plan_action_id
    join public.content_items ci on ci.id = par.content_item_id
    where pa.care_plan_id = p_care_plan_id
      and pa.review_status = 'approved'
      and (
        ci.status <> 'published'
        or ci.visibility not in ('public', 'patient_only', 'assigned_only')
      )
  ) then
    raise exception 'Every linked resource must be published and patient-accessible.'
      using errcode = '22023';
  end if;

  update public.care_plans
  set status = 'inactive'
  where patient_id = plan_row.patient_id and status = 'active';

  update public.care_plans
  set status = 'active', published_at = now(), published_by = caller_user_id
  where id = p_care_plan_id
  returning * into plan_row;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id,
    'care_plan.published',
    'care_plan',
    plan_row.id,
    plan_row.patient_id,
    p_request_id,
    jsonb_build_object('version', plan_row.version)
  )
  on conflict (actor_user_id, action, request_id)
    where request_id is not null do nothing;

  return plan_row;
end;
$$;

create or replace function public.archive_care_plan(
  p_care_plan_id uuid,
  p_request_id uuid default gen_random_uuid()
)
returns public.care_plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  plan_row public.care_plans%rowtype;
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

  select cp.* into plan_row
  from public.care_plans cp
  where cp.id = p_care_plan_id
  for update;
  if not found then
    raise exception 'Care plan was not found.' using errcode = 'P0002';
  end if;
  if plan_row.status = 'archived' then return plan_row; end if;
  if plan_row.status = 'draft' then
    raise exception 'Unpublished drafts cannot be archived.' using errcode = '22023';
  end if;

  update public.care_plans
  set status = 'archived', archived_at = now()
  where id = p_care_plan_id
  returning * into plan_row;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id,
    'care_plan.archived',
    'care_plan',
    plan_row.id,
    plan_row.patient_id,
    p_request_id,
    jsonb_build_object('version', plan_row.version)
  )
  on conflict (actor_user_id, action, request_id)
    where request_id is not null do nothing;

  return plan_row;
end;
$$;

revoke execute on function public.create_draft_care_plan(
  uuid, text, date, date, uuid, uuid, uuid
) from public, anon, authenticated;
revoke execute on function public.save_plan_action(
  uuid, text, text, jsonb, date, uuid, text, integer, integer,
  text, time, date, public.action_review_status, boolean, uuid, text, uuid
) from public, anon, authenticated;
revoke execute on function public.reorder_plan_actions(uuid, uuid[], uuid)
  from public, anon, authenticated;
revoke execute on function public.reject_plan_action(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function public.publish_care_plan(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function public.archive_care_plan(uuid, uuid)
  from public, anon, authenticated;

grant execute on function public.create_draft_care_plan(
  uuid, text, date, date, uuid, uuid, uuid
) to authenticated;
grant execute on function public.save_plan_action(
  uuid, text, text, jsonb, date, uuid, text, integer, integer,
  text, time, date, public.action_review_status, boolean, uuid, text, uuid
) to authenticated;
grant execute on function public.reorder_plan_actions(uuid, uuid[], uuid)
  to authenticated;
grant execute on function public.reject_plan_action(uuid, uuid)
  to authenticated;
grant execute on function public.publish_care_plan(uuid, uuid)
  to authenticated;
grant execute on function public.archive_care_plan(uuid, uuid)
  to authenticated;

comment on function public.create_draft_care_plan(
  uuid, text, date, date, uuid, uuid, uuid
) is 'Creates one versioned draft per patient and can safely copy a published version for review.';
comment on function public.save_plan_action(
  uuid, text, text, jsonb, date, uuid, text, integer, integer,
  text, time, date, public.action_review_status, boolean, uuid, text, uuid
) is 'Creates or updates a reviewed manual plan action and its canonical resource link.';
comment on function public.publish_care_plan(uuid, uuid) is
  'Publishes a fully reviewed plan and deactivates the previous active version without generating times.';
