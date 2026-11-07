-- Clinical bulk operations use the existing draft plan and its RLS policies.
alter table public.plan_actions
  add column official_template_id text,
  add column prescription_item_id uuid;
alter table public.plan_actions alter column prescription_item_id set default gen_random_uuid();
alter table public.plan_actions add constraint plan_actions_official_template_id
  check (official_template_id ~ '^[asbux][0-9]{2}$');

create index plan_actions_official_template_lookup_idx
  on public.plan_actions (care_plan_id, official_template_id)
  where official_template_id is not null and review_status <> 'rejected';
create unique index plan_actions_prescription_item_per_version_idx
  on public.plan_actions (care_plan_id, prescription_item_id)
  where prescription_item_id is not null;

create function public.import_official_plan_actions(
  p_plan_id uuid, p_templates jsonb, p_request_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  plan_row public.care_plans;
  previous public.admin_audit_logs;
  imported integer;
begin
  if actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_request_id is null
    or jsonb_typeof(p_templates) is distinct from 'array'
    or pg_column_size(p_templates) > 262144 then
    raise exception 'Invalid template batch.' using errcode = '22023';
  end if;
  if jsonb_array_length(p_templates) not between 1 and 100 then
    raise exception 'Choose between 1 and 100 templates.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into previous from public.admin_audit_logs
    where actor_user_id = actor and action = 'care_plan.templates_imported'
      and request_id = p_request_id;
  if found then
    if previous.entity_id <> p_plan_id then
      raise exception 'Request belongs to a different plan.' using errcode = '22023';
    end if;
    return (previous.metadata ->> 'count')::integer;
  end if;

  select * into plan_row from public.care_plans
    where id = p_plan_id and status = 'draft' for update;
  if not found then
    raise exception 'Editable draft plan not found.' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from jsonb_array_elements(p_templates) as entry
    where jsonb_typeof(entry) <> 'object'
      or coalesce(entry ->> 'id', '') !~ '^(a(0[1-9]|1[01])|s(0[1-9]|10)|b0[1-9]|u(0[1-9]|1[0-3])|x0[1-8])$'
      or coalesce(char_length(btrim(entry ->> 'title')), 0) not between 1 and 160
      or coalesce(char_length(btrim(entry ->> 'instruction')), 0) not between 1 and 3000
  ) then
    raise exception 'A template has invalid draft fields.' using errcode = '22023';
  end if;

  with existing as (
    select official_template_id, sort_order from public.plan_actions
    where care_plan_id = p_plan_id and review_status <> 'rejected'
  ), candidates as (
    select distinct on (entry ->> 'id') entry, position
    from jsonb_array_elements(p_templates) with ordinality as batch(entry, position)
    where not exists (
      select 1 from existing where official_template_id = entry ->> 'id'
    )
    order by entry ->> 'id', position
  )
  insert into public.plan_actions (
    care_plan_id, official_template_id, type, title, instruction, frequency_rule,
    start_date, end_date, sort_order, review_status, reminder_enabled, created_by
  )
  select p_plan_id, entry ->> 'id',
    case left(entry ->> 'id', 1)
      when 's' then 'supplement' when 'b' then 'bath' when 'u' then 'audio'
      else 'amal'
    end,
    btrim(entry ->> 'title'), btrim(entry ->> 'instruction'),
    '{"type":"daily","interval":1}'::jsonb,
    plan_row.start_date, plan_row.end_date,
    (select coalesce(max(sort_order), -1) from existing)
      + row_number() over (order by position),
    'needs_review', false, actor
  from candidates;
  get diagnostics imported = row_count;

  if (select count(*) from public.plan_actions
      where care_plan_id = p_plan_id and review_status <> 'rejected') > 100 then
    raise exception 'The clinical batch supports up to 100 actions.' using errcode = '22023';
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id, request_id, metadata
  ) values (
    actor, 'care_plan.templates_imported', 'care_plan', p_plan_id, plan_row.patient_id,
    p_request_id, jsonb_build_object('count', imported)
  );
  return imported;
end;
$$;

create function public.update_prescription_draft_actions(
  p_plan_id uuid, p_action_ids uuid[], p_patch jsonb, p_request_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  plan_row public.care_plans;
  previous public.admin_audit_logs;
  new_frequency jsonb := p_patch -> 'frequency';
  new_start date;
  new_end date;
  new_time time;
  new_reminder boolean;
  remove_selected boolean := p_patch = '{"remove":true}'::jsonb;
  previous_schedule jsonb;
begin
  if actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_request_id is null or coalesce(cardinality(p_action_ids), 0) not between 1 and 100
    or jsonb_typeof(p_patch) is distinct from 'object' or p_patch = '{}'::jsonb
    or pg_column_size(p_patch) > 4096
    or (not remove_selected and p_patch - array[
      'frequency', 'start_date', 'end_date', 'exact_time', 'reminder_enabled', 'time_window'
    ] <> '{}'::jsonb) then
    raise exception 'Invalid action batch.' using errcode = '22023';
  end if;
  new_start := (p_patch ->> 'start_date')::date;
  new_end := (p_patch ->> 'end_date')::date;
  new_time := (p_patch ->> 'exact_time')::time;
  new_reminder := (p_patch ->> 'reminder_enabled')::boolean;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into previous from public.admin_audit_logs
    where actor_user_id = actor and action = 'care_plan.batch_updated'
      and request_id = p_request_id;
  if found then
    if previous.entity_id <> p_plan_id then
      raise exception 'Request belongs to a different plan.' using errcode = '22023';
    end if;
    return;
  end if;

  select * into plan_row from public.care_plans
    where id = p_plan_id and status = 'draft' for update;
  if not found then
    raise exception 'Editable draft plan not found.' using errcode = 'P0002';
  end if;
  if (select count(*) from public.plan_actions
      where care_plan_id = p_plan_id and id = any(p_action_ids)
        and review_status <> 'rejected') <> cardinality(p_action_ids) then
    raise exception 'Each selected action must belong to this draft.' using errcode = '22023';
  end if;

  if p_patch ? 'frequency' then
    if jsonb_typeof(new_frequency) is distinct from 'object' then
      raise exception 'Invalid recurrence.' using errcode = '22023';
    end if;
    case new_frequency ->> 'type'
    when 'daily' then
      if coalesce(new_frequency ->> 'interval', '') !~ '^[1-9][0-9]{0,2}$' then
        raise exception 'Invalid daily interval.' using errcode = '22023';
      end if;
    when 'weekly' then
      if jsonb_typeof(new_frequency -> 'weekdays') is distinct from 'array' then
        raise exception 'Invalid weekdays.' using errcode = '22023';
      end if;
      if jsonb_array_length(new_frequency -> 'weekdays') not between 1 and 7
        or exists (select 1 from jsonb_array_elements(new_frequency -> 'weekdays') as weekday
                   where weekday::text !~ '^[1-7]$')
        or (select count(distinct weekday) from jsonb_array_elements(new_frequency -> 'weekdays') as weekday)
          <> jsonb_array_length(new_frequency -> 'weekdays') then
        raise exception 'Invalid weekdays.' using errcode = '22023';
      end if;
    else
      raise exception 'Invalid recurrence.' using errcode = '22023';
    end case;
  end if;
  if (p_patch ? 'start_date' and new_start is null)
    or (p_patch ? 'reminder_enabled' and new_reminder is null)
    or exists (
      select 1 from public.plan_actions pa
      cross join lateral (select coalesce(new_start, pa.start_date) as starts,
        case when p_patch ? 'end_date' then new_end else pa.end_date end as ends,
        case when p_patch ? 'exact_time' then new_time else pa.exact_time end as exact,
        coalesce(new_reminder, pa.reminder_enabled) as remind) as proposed
      where pa.id = any(p_action_ids) and not remove_selected and (
        proposed.starts < plan_row.start_date
        or proposed.starts > plan_row.end_date
        or proposed.ends < proposed.starts
        or proposed.ends > plan_row.end_date
        or (proposed.remind and (proposed.exact is null or proposed.exact >= time '24:00'))
      )
    ) then
    raise exception 'Use dates within this plan and set an exact time for reminders.' using errcode = '22023';
  end if;

  select jsonb_agg(to_jsonb(prior)) into previous_schedule
  from (
    select id, start_date, end_date, exact_time, time_window, frequency_rule,
      reminder_enabled, review_status
    from public.plan_actions where care_plan_id = p_plan_id and id = any(p_action_ids)
  ) prior;

  update public.plan_actions pa set
    start_date = coalesce(new_start, pa.start_date),
    end_date = case when p_patch ? 'end_date' then new_end else pa.end_date end,
    exact_time = case when p_patch ? 'exact_time' then new_time else pa.exact_time end,
    time_window = case when p_patch ? 'time_window' then p_patch ->> 'time_window' else pa.time_window end,
    frequency_rule = coalesce(new_frequency, pa.frequency_rule),
    reminder_enabled = case when remove_selected then false else coalesce(new_reminder, pa.reminder_enabled) end,
    review_status = case when remove_selected then 'rejected'::public.action_review_status
      else 'needs_review'::public.action_review_status end
  where pa.care_plan_id = p_plan_id and pa.id = any(p_action_ids);

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id, request_id, metadata
  ) values (
    actor, 'care_plan.batch_updated', 'care_plan', p_plan_id, plan_row.patient_id,
    p_request_id, jsonb_build_object(
      'action_ids', p_action_ids, 'removed', remove_selected,
      'previous_schedule', previous_schedule, 'changed_at', now()
    )
  );
end;
$$;

create function private.validate_official_prescription_publication()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.status = 'draft' and new.status = 'active' and exists (
    select 1 from public.plan_actions pa
    where pa.care_plan_id = new.id and pa.official_template_id is not null
      and pa.review_status <> 'rejected' and (
        pa.review_status <> 'approved'
        or nullif(btrim(pa.instruction), '') is null
        or pa.instruction ~ '[{](দিন|বার|মিনিট)[}]'
        or pa.start_date < new.start_date
        or pa.start_date > new.end_date
        or pa.end_date > new.end_date
        or (pa.reminder_enabled and pa.exact_time is null)
        or (
          (pa.official_template_id like 'u%' or pa.official_template_id in ('a05', 'a06', 'a07'))
          and not exists (
            select 1 from public.plan_action_resources par
            join public.content_items ci on ci.id = par.content_item_id
            where par.plan_action_id = pa.id and ci.status = 'published'
              and ci.visibility in ('public', 'patient_only', 'assigned_only')
              and (ci.type not in ('quran', 'hadith') or ci.verification_status = 'verified')
              and (pa.official_template_id not like 'u%' or ci.type = 'audio')
          )
          and not (
            pa.official_template_id not like 'u%' and exists (
              select 1 from public.plan_action_quran_surahs q where q.plan_action_id = pa.id
            )
          )
        )
      )
  ) then
    raise exception 'Official template instructions and resources require review.' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger care_plans_validate_official_prescription
before update of status on public.care_plans
for each row execute function private.validate_official_prescription_publication();

revoke execute on function public.import_official_plan_actions(uuid, jsonb, uuid) from public, anon;
revoke execute on function public.update_prescription_draft_actions(uuid, uuid[], jsonb, uuid) from public, anon;
grant execute on function public.import_official_plan_actions(uuid, jsonb, uuid) to authenticated;
grant execute on function public.update_prescription_draft_actions(uuid, uuid[], jsonb, uuid) to authenticated;

-- Save the editable action and all chosen resource relations in one transaction.
-- The legacy save_plan_action signature remains available to existing clients.
create function public.save_prescription_studio_action(
  p_action jsonb, p_resource_ids uuid[], p_surahs jsonb, p_template_id text default null
)
returns public.plan_actions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  request uuid;
  plan_id uuid;
  previous public.admin_audit_logs;
  saved public.plan_actions;
begin
  if actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  -- Retain the existing single-action instruction contract for legacy records.
  -- Bounded bulk imports remain separately limited to 256 KiB.
  if jsonb_typeof(p_action) is distinct from 'object'
    or p_resource_ids is null or coalesce(cardinality(p_resource_ids), 0) > 16
    or jsonb_typeof(p_surahs) is distinct from 'array'
    or (p_template_id is not null and p_template_id !~
      '^(a(0[1-9]|1[01])|s(0[1-9]|10)|b0[1-9]|u(0[1-9]|1[0-3])|x0[1-8])$')
  then
    raise exception 'Invalid prescription action.' using errcode = '22023';
  end if;
  request := (p_action ->> 'p_request_id')::uuid;
  plan_id := (p_action ->> 'p_care_plan_id')::uuid;
  if request is null or plan_id is null then
    raise exception 'Action request and plan are required.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(request::text, 0));
  select * into previous from public.admin_audit_logs
    where actor_user_id = actor and action = 'care_plan.studio_action_saved' and request_id = request;
  if found then
    select * into saved from public.plan_actions where id = previous.entity_id and care_plan_id = plan_id;
    if not found then
      raise exception 'Request belongs to a different plan.' using errcode = '22023';
    end if;
    return saved;
  end if;

  saved := public.save_plan_action(
    p_care_plan_id := plan_id,
    p_type := p_action ->> 'p_type',
    p_title := p_action ->> 'p_title',
    p_frequency_rule := p_action -> 'p_frequency_rule',
    p_start_date := (p_action ->> 'p_start_date')::date,
    p_action_id := (p_action ->> 'p_action_id')::uuid,
    p_instruction := p_action ->> 'p_instruction',
    p_count_target := (p_action ->> 'p_count_target')::integer,
    p_duration_minutes := (p_action ->> 'p_duration_minutes')::integer,
    p_time_window := p_action ->> 'p_time_window',
    p_exact_time := (p_action ->> 'p_exact_time')::time,
    p_end_date := (p_action ->> 'p_end_date')::date,
    p_review_status := (p_action ->> 'p_review_status')::public.action_review_status,
    p_reminder_enabled := (p_action ->> 'p_reminder_enabled')::boolean,
    p_content_item_id := (p_action ->> 'p_content_item_id')::uuid,
    p_resource_usage_note := p_action ->> 'p_resource_usage_note',
    p_request_id := request
  );
  if saved.care_plan_id <> plan_id then
    raise exception 'Request belongs to a different plan.' using errcode = '22023';
  end if;

  if p_template_id is not null then
    update public.plan_actions
      set official_template_id = p_template_id
      where id = saved.id returning * into saved;
  end if;
  perform public.replace_draft_action_resources(saved.id, p_resource_ids, request);
  perform public.replace_draft_action_quran_surahs(saved.id, p_surahs, request);

  insert into public.admin_audit_logs(
    actor_user_id, action, entity_type, entity_id, patient_id, request_id, metadata
  )
  select actor, 'care_plan.studio_action_saved', 'plan_action', saved.id, cp.patient_id,
    request, jsonb_build_object('care_plan_id', plan_id)
  from public.care_plans cp where cp.id = plan_id;
  return saved;
end;
$$;

revoke execute on function public.save_prescription_studio_action(jsonb, uuid[], jsonb, text)
  from public, anon;
grant execute on function public.save_prescription_studio_action(jsonb, uuid[], jsonb, text)
  to authenticated;

create function public.undo_prescription_draft_batch(p_plan_id uuid, p_request_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  plan_row public.care_plans;
  operation public.admin_audit_logs;
  previous_rows jsonb;
begin
  if actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  select * into plan_row from public.care_plans
    where id = p_plan_id and status = 'draft' for update;
  if not found then
    raise exception 'Editable draft plan not found.' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.admin_audit_logs
    where actor_user_id = actor and action = 'care_plan.batch_undone'
      and request_id = p_request_id and entity_id = p_plan_id) then
    return;
  end if;
  select * into operation from public.admin_audit_logs
    where actor_user_id = actor and action = 'care_plan.batch_updated'
      and request_id = p_request_id and entity_id = p_plan_id;
  previous_rows := operation.metadata -> 'previous_schedule';
  if previous_rows is null then
    raise exception 'The original batch was not found.' using errcode = 'P0002';
  end if;
  if (select count(*) from public.plan_actions pa
    join jsonb_array_elements(previous_rows) item on pa.id = (item ->> 'id')::uuid
    where pa.care_plan_id = p_plan_id
      and pa.updated_at = (operation.metadata ->> 'changed_at')::timestamptz
  ) <> jsonb_array_length(previous_rows) then
    raise exception 'The draft changed after this operation.' using errcode = '40001';
  end if;

  update public.plan_actions pa set
    start_date = prior.start_date, end_date = prior.end_date,
    exact_time = prior.exact_time, time_window = prior.time_window,
    frequency_rule = prior.frequency_rule, reminder_enabled = prior.reminder_enabled,
    review_status = prior.review_status
  from jsonb_to_recordset(previous_rows) as prior(
    id uuid, start_date date, end_date date, exact_time time, time_window text,
    frequency_rule jsonb, reminder_enabled boolean, review_status public.action_review_status
  )
  where pa.id = prior.id and pa.care_plan_id = p_plan_id;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id, request_id
  ) values (
    actor, 'care_plan.batch_undone', 'care_plan', p_plan_id, plan_row.patient_id, p_request_id
  );
end;
$$;

revoke execute on function public.undo_prescription_draft_batch(uuid, uuid) from public, anon;
grant execute on function public.undo_prescription_draft_batch(uuid, uuid) to authenticated;

-- Expand explicit sessions and consecutive stages into ordinary plan actions.
-- The scheduler and completion model continue to use one task per action/day.
create function public.expand_prescription_action_schedule(
  p_plan_id uuid, p_action_id uuid, p_stage_days integer[], p_times time[],
  p_request_id uuid
)
returns uuid[]
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  plan_row public.care_plans;
  source public.plan_actions;
  previous public.admin_audit_logs;
  action_ids uuid[] := '{}';
  next_id uuid;
  next_start date;
  next_end date;
  next_time time;
  next_order integer;
  slot_count integer := coalesce(cardinality(p_stage_days), cardinality(p_times), 1);
begin
  if actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_request_id is null or (p_stage_days is not null and p_times is not null)
    or ((p_stage_days is not null or p_times is not null) and slot_count not between 2 and 12)
    or (p_stage_days is not null and (array_ndims(p_stage_days) <> 1 or array_lower(p_stage_days, 1) <> 1))
    or (p_times is not null and (array_ndims(p_times) <> 1 or array_lower(p_times, 1) <> 1))
    or exists (select 1 from unnest(p_stage_days) d where d is null or d not between 1 and 365)
    or exists (select 1 from unnest(p_times) t where t is null or t >= time '24:00')
    or (p_times is not null and (select count(distinct t) from unnest(p_times) t) <> slot_count)
  then
    raise exception 'Provide distinct times or consecutive stage lengths.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into previous from public.admin_audit_logs
    where actor_user_id = actor and action = 'care_plan.schedule_expanded'
      and request_id = p_request_id;
  if found then
    if previous.entity_id <> p_plan_id or previous.metadata ->> 'source_id' <> p_action_id::text then
      raise exception 'Request belongs to a different action.' using errcode = '22023';
    end if;
    return array(select jsonb_array_elements_text(previous.metadata -> 'action_ids')::uuid);
  end if;

  select * into plan_row from public.care_plans
    where id = p_plan_id and status = 'draft' for update;
  if not found then
    raise exception 'Editable draft plan not found.' using errcode = 'P0002';
  end if;
  select * into source from public.plan_actions
    where id = p_action_id and care_plan_id = p_plan_id and review_status <> 'rejected';
  if not found then
    raise exception 'Editable action not found.' using errcode = 'P0002';
  end if;

  select coalesce(max(sort_order), -1) + 1 into next_order
    from public.plan_actions where care_plan_id = p_plan_id and review_status <> 'rejected';
  if (select count(*) from public.plan_actions where care_plan_id = p_plan_id
      and review_status <> 'rejected') + greatest(slot_count - 1, 1) > 100 then
    raise exception 'The clinical batch supports up to 100 actions.' using errcode = '22023';
  end if;

  next_start := source.start_date;
  for slot in 1..slot_count loop
    next_end := case when p_stage_days is null then source.end_date
      else next_start + p_stage_days[slot] - 1 end;
    next_time := case when p_times is null then source.exact_time else p_times[slot] end;
    if next_start < plan_row.start_date or next_start > plan_row.end_date or next_end > plan_row.end_date then
      raise exception 'Schedule must fit within the care plan dates.' using errcode = '22023';
    end if;

    if slot = 1 and slot_count > 1 then
      update public.plan_actions set start_date = next_start, end_date = next_end,
        exact_time = next_time,
        time_window = case when p_times is null then source.time_window else null end,
        review_status = 'needs_review', reminder_enabled = false
      where id = source.id returning id into next_id;
    else
      insert into public.plan_actions (
        care_plan_id, official_template_id, type, title, instruction, count_target, duration_minutes,
        frequency_rule, time_window, exact_time, start_date, end_date, sort_order,
        review_status, reminder_enabled, created_by
      ) values (
        p_plan_id, source.official_template_id, source.type, source.title, source.instruction,
        source.count_target, source.duration_minutes, source.frequency_rule,
        case when p_times is null then source.time_window else null end,
        next_time, next_start, next_end, next_order, 'needs_review', false, actor
      ) returning id into next_id;

      insert into public.plan_action_resources (
        plan_action_id, content_item_id, usage_note, sort_order, created_by
      )
      select next_id, content_item_id, usage_note, sort_order, actor
        from public.plan_action_resources where plan_action_id = source.id;

      insert into public.plan_action_quran_surahs (
        plan_action_id, surah_number, title, sort_order, created_by
      )
      select next_id, surah_number, title, sort_order, actor
        from public.plan_action_quran_surahs where plan_action_id = source.id;
      next_order := next_order + 1;
    end if;
    action_ids := array_append(action_ids, next_id);
    if p_stage_days is not null then
      next_start := next_end + 1;
    end if;
  end loop;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id, request_id, metadata
  ) values (
    actor, 'care_plan.schedule_expanded', 'care_plan', p_plan_id, plan_row.patient_id,
    p_request_id, jsonb_build_object('source_id', source.id, 'action_ids', action_ids)
  );
  return action_ids;
end;
$$;

revoke execute on function public.expand_prescription_action_schedule(uuid, uuid, integer[], time[], uuid)
  from public, anon;
grant execute on function public.expand_prescription_action_schedule(uuid, uuid, integer[], time[], uuid)
  to authenticated;

-- Preserve official template provenance and relative schedules in a new reviewable version.
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
      if source_action.official_template_id is not null and p_end_date is not null and (
        p_start_date + (source_action.start_date - source_plan.start_date) > p_end_date
        or p_start_date + (source_action.end_date - source_plan.start_date) > p_end_date
      ) then
        raise exception 'The new version dates do not cover the copied schedule.' using errcode = '22023';
      end if;

      insert into public.plan_actions (
        care_plan_id, type, title, instruction, count_target,
        duration_minutes, frequency_rule, time_window, exact_time,
        start_date, end_date, sort_order, review_status,
        reminder_enabled, ai_source, created_by, official_template_id, prescription_item_id
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
        case when source_action.official_template_id is null then p_start_date
          else p_start_date + (source_action.start_date - source_plan.start_date) end,
        case when source_action.official_template_id is null then p_end_date
          when source_action.end_date is null then p_end_date
          else p_start_date + (source_action.end_date - source_plan.start_date) end,
        source_action.sort_order,
        'needs_review',
        source_action.reminder_enabled,
        null,
        caller_user_id,
        source_action.official_template_id,
        coalesce(source_action.prescription_item_id, source_action.id)
      ) returning id into created_action_id;

      insert into public.plan_action_resources (
        plan_action_id, content_item_id, usage_note, sort_order, created_by
      )
      select
        created_action_id, par.content_item_id, par.usage_note, par.sort_order, caller_user_id
      from public.plan_action_resources par
      where par.plan_action_id = source_action.id;

      insert into public.plan_action_quran_surahs (
        plan_action_id, surah_number, title, sort_order, created_by
      )
      select created_action_id, q.surah_number, q.title, q.sort_order, caller_user_id
      from public.plan_action_quran_surahs q
      where q.plan_action_id = source_action.id;
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

-- Retain the parent plan bounds for all existing and newly imported actions.
create or replace function public.ensure_patient_tasks(
  p_local_date date,
  p_timezone_offset_minutes integer
)
returns setof public.task_instances
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  caller_patient_id uuid;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select p.id into caller_patient_id
  from public.patients p
  join public.user_roles ur
    on ur.user_id = p.user_id and ur.role = 'patient'
  where p.user_id = caller_user_id
    and p.status = 'active';

  if caller_patient_id is null then
    raise exception 'An active patient account is required.' using errcode = '42501';
  end if;
  if p_timezone_offset_minutes is null
    or p_timezone_offset_minutes < -720
    or p_timezone_offset_minutes > 840 then
    raise exception 'A valid timezone offset is required.' using errcode = '22023';
  end if;
  if p_local_date is distinct from (
    now() + make_interval(mins => p_timezone_offset_minutes)
  )::date then
    raise exception 'Tasks can only be generated for the patient''s current day.'
      using errcode = '22023';
  end if;

  insert into public.task_instances (
    plan_action_id,
    patient_id,
    occurrence_date,
    scheduled_at,
    timezone_offset_minutes
  )
  select
    pa.id,
    caller_patient_id,
    p_local_date,
    case
      when pa.exact_time is null then null
      else (
        p_local_date + pa.exact_time
        - make_interval(mins => p_timezone_offset_minutes)
      ) at time zone 'UTC'
    end,
    p_timezone_offset_minutes
  from public.care_plans cp
  join public.plan_actions pa on pa.care_plan_id = cp.id
  where cp.patient_id = caller_patient_id
    and cp.status = 'active'
    and pa.review_status = 'approved'
    and p_local_date between cp.start_date and coalesce(cp.end_date, p_local_date)
    and p_local_date between pa.start_date and coalesce(pa.end_date, p_local_date)
    and (
      (
        pa.frequency_rule ->> 'type' = 'daily'
        and (p_local_date - pa.start_date)
          % ((pa.frequency_rule ->> 'interval')::integer) = 0
      )
      or (
        pa.frequency_rule ->> 'type' = 'weekly'
        and (extract(isodow from p_local_date)::integer)::text in (
          select jsonb_array_elements_text(pa.frequency_rule -> 'weekdays')
        )
      )
    )
  on conflict (plan_action_id, occurrence_date) do nothing;

  return query
  select ti.*
  from public.task_instances ti
  join public.plan_actions pa on pa.id = ti.plan_action_id
  join public.care_plans cp on cp.id = pa.care_plan_id
  where ti.patient_id = caller_patient_id
    and ti.occurrence_date = p_local_date
    and cp.status = 'active'
    and p_local_date between cp.start_date and coalesce(cp.end_date, p_local_date)
    and pa.review_status = 'approved'
    and ti.status <> 'cancelled'
  order by coalesce(ti.scheduled_at, 'infinity'::timestamptz), pa.sort_order;
end;
$$;

-- Retain the parent plan bounds for all existing and newly imported actions.
create or replace function public.ensure_patient_reminder_tasks(
  p_start_date date,
  p_end_date date,
  p_timezone_offset_minutes integer
)
returns setof public.task_instances
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  caller_patient_id uuid;
  patient_today date;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select p.id into caller_patient_id
  from public.patients p
  join public.user_roles ur
    on ur.user_id = p.user_id and ur.role = 'patient'
  where p.user_id = caller_user_id and p.status = 'active';
  if caller_patient_id is null then
    raise exception 'An active patient account is required.' using errcode = '42501';
  end if;

  if p_timezone_offset_minutes is null
    or p_timezone_offset_minutes < -720
    or p_timezone_offset_minutes > 840 then
    raise exception 'A valid timezone offset is required.' using errcode = '22023';
  end if;
  patient_today := (
    now() + make_interval(mins => p_timezone_offset_minutes)
  )::date;
  if p_start_date is distinct from patient_today
    or p_end_date < p_start_date
    or p_end_date > p_start_date + 30 then
    raise exception 'Reminder tasks may only be generated for the next 31 days.'
      using errcode = '22023';
  end if;

  insert into public.task_instances (
    plan_action_id, patient_id, occurrence_date, scheduled_at,
    timezone_offset_minutes
  )
  select
    pa.id,
    caller_patient_id,
    day.local_date,
    (
      day.local_date + pa.exact_time
      - make_interval(mins => p_timezone_offset_minutes)
    ) at time zone 'UTC',
    p_timezone_offset_minutes
  from public.care_plans cp
  join public.plan_actions pa on pa.care_plan_id = cp.id
  cross join lateral generate_series(
    p_start_date,
    p_end_date,
    interval '1 day'
  ) generated_day
  cross join lateral (select generated_day::date as local_date) day
  where cp.patient_id = caller_patient_id
    and cp.status = 'active'
    and pa.review_status = 'approved'
    and day.local_date between cp.start_date and coalesce(cp.end_date, day.local_date)
    and pa.reminder_enabled
    and pa.exact_time is not null
    and day.local_date between pa.start_date and coalesce(pa.end_date, day.local_date)
    and (
      (
        pa.frequency_rule ->> 'type' = 'daily'
        and (day.local_date - pa.start_date)
          % ((pa.frequency_rule ->> 'interval')::integer) = 0
      )
      or (
        pa.frequency_rule ->> 'type' = 'weekly'
        and (extract(isodow from day.local_date)::integer)::text in (
          select jsonb_array_elements_text(pa.frequency_rule -> 'weekdays')
        )
      )
    )
  on conflict (plan_action_id, occurrence_date) do nothing;

  return query
  select ti.*
  from public.task_instances ti
  join public.plan_actions pa on pa.id = ti.plan_action_id
  join public.care_plans cp on cp.id = pa.care_plan_id
  where ti.patient_id = caller_patient_id
    and cp.status = 'active'
    and pa.review_status = 'approved'
    and ti.occurrence_date between cp.start_date and coalesce(cp.end_date, ti.occurrence_date)
    and pa.reminder_enabled
    and pa.exact_time is not null
    and ti.occurrence_date between p_start_date and p_end_date
    and ti.status in ('pending', 'snoozed')
  order by ti.scheduled_at;
end;
$$;
