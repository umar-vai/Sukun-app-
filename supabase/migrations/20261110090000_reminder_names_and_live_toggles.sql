-- Reminder names and live reminder switches (owner request 2026-11-10).
--
-- 1. plan_actions.notification_title: the short name the patient's phone shows
--    for a care reminder (owner decision: shown on the lock screen). Empty
--    means the old generic text. Web push stays generic (server never sends
--    patient text).
-- 2. New care plan versions copy the name with the action.
-- 3. set_draft_action_notification_title: set the name on a draft action.
-- 4. admin_set_plan_action_reminder: Super Admin switches one approved live
--    reminder on or off at once, without a new plan version. Audited. Times,
--    names and instructions still change only through a new version.
-- 5. Routine import accepts an optional notification_title per row.
-- 6. Routine overview returns action ids and names, and
--    admin_set_user_routine_action_reminder switches an admin-set routine
--    action on or off (never the user's self-added ones). Audited.
-- 7. Owner decision: the Qital-Tadmir, Khuruj and Ayatush Shifa audios become
--    assigned_only (patients they are prescribed to can play them; still
--    hidden from public Resources).

alter table public.plan_actions
  add column if not exists notification_title text;
alter table public.plan_actions
  drop constraint if exists plan_actions_notification_title_length;
alter table public.plan_actions
  add constraint plan_actions_notification_title_length
  check (notification_title is null
         or char_length(btrim(notification_title)) between 1 and 120);

comment on column public.plan_actions.notification_title is
  'Short reminder name shown in the patient device notification. Null = generic text.';

-- Published actions stay locked. The one exception: the reminder on/off flag
-- of an ACTIVE plan, and only inside admin_set_plan_action_reminder (which
-- sets a transaction-local flag). Every clinical field must be unchanged.
create or replace function private.prevent_non_draft_action_rewrite()
returns trigger
language plpgsql
set search_path to ''
as $function$
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
    if tg_op = 'UPDATE'
       and target_status = 'active'::public.care_plan_status
       and current_setting('sukun.live_reminder_toggle', true) = 'on'
       and (to_jsonb(new) - 'reminder_enabled' - 'updated_at')
           = (to_jsonb(old) - 'reminder_enabled' - 'updated_at') then
      return new;
    end if;
    raise exception 'Published care plan actions cannot be rewritten.'
      using errcode = '55000';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

-- Preserve canonical links when creating a new reviewed draft version.
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
        reminder_enabled, ai_source, created_by, notification_title
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
        caller_user_id,
        source_action.notification_title
      ) returning id into created_action_id;

      insert into public.plan_action_resources (
        plan_action_id, content_item_id, usage_note, created_by
      )
      select
        created_action_id, par.content_item_id, par.usage_note, caller_user_id
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

create or replace function public.set_draft_action_notification_title(
  p_action_id uuid,
  p_notification_title text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_title text := nullif(btrim(coalesce(p_notification_title, '')), '');
begin
  if (select auth.uid()) is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if v_title is not null and char_length(v_title) > 120 then
    raise exception 'Reminder name is too long.' using errcode = '22023';
  end if;
  -- RLS limits this update to actions of draft plans.
  update public.plan_actions pa
  set notification_title = v_title, updated_at = now()
  where pa.id = p_action_id
    and exists (
      select 1 from public.care_plans cp
      where cp.id = pa.care_plan_id and cp.status = 'draft'
    );
  if not found then
    raise exception 'Draft action was not found.' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.set_draft_action_notification_title(uuid,text)
  from public, anon;
grant execute on function public.set_draft_action_notification_title(uuid,text)
  to authenticated;

create or replace function public.admin_set_plan_action_reminder(
  p_action_id uuid,
  p_enabled boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_patient uuid;
  v_previous boolean;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_enabled is null then
    raise exception 'Reminder state is required.' using errcode = '22023';
  end if;

  select cp.patient_id, pa.reminder_enabled into v_patient, v_previous
  from public.plan_actions pa
  join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = p_action_id
    and cp.status = 'active'
    and pa.review_status = 'approved'
  for update of pa;
  if not found then
    raise exception 'Live approved action was not found.' using errcode = 'P0002';
  end if;
  if v_previous is not distinct from p_enabled then
    return p_enabled;
  end if;
  if p_enabled and not exists (
    select 1 from public.plan_actions pa
    where pa.id = p_action_id and pa.exact_time is not null
  ) then
    raise exception 'A reminder needs an approved exact time.' using errcode = '22023';
  end if;

  perform set_config('sukun.live_reminder_toggle', 'on', true);
  update public.plan_actions
  set reminder_enabled = p_enabled, updated_at = now()
  where id = p_action_id;
  perform set_config('sukun.live_reminder_toggle', 'off', true);

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id, metadata
  ) values (
    v_actor,
    'plan_action.reminder_toggled',
    'plan_action',
    p_action_id,
    v_patient,
    jsonb_build_object('reminder_enabled', p_enabled)
  );
  return p_enabled;
end;
$$;

revoke all on function public.admin_set_plan_action_reminder(uuid,boolean)
  from public, anon;
grant execute on function public.admin_set_plan_action_reminder(uuid,boolean)
  to authenticated;

create or replace function public.admin_import_user_routine_reminders(
  p_target_user_id uuid,
  p_title text,
  p_actions jsonb,
  p_timezone_name text default 'Asia/Dhaka'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_routine uuid;
  v_action uuid;
  v_step jsonb;
  v_resource jsonb;
  v_step_title text;
  v_step_notes text;
  v_step_notification text;
  v_step_template_id text;
  v_step_time_text text;
  v_step_time time;
  v_provider text;
  v_reference text;
  v_cms_id uuid;
  v_first_provider text;
  v_first_cms uuid;
  v_first_reference text;
  v_count integer := 0;
  v_index integer;
  v_seen text[];
  v_timezone text := coalesce(nullif(btrim(p_timezone_name), ''), 'Asia/Dhaka');
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required'
      using errcode = '42501';
  end if;
  if p_target_user_id is null or not exists (
    select 1 from public.profiles p where p.id = p_target_user_id
  ) then
    raise exception 'Target user profile was not found'
      using errcode = '22023';
  end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 120
      or p_actions is null or jsonb_typeof(p_actions) <> 'array'
      or jsonb_array_length(p_actions) not between 1 and 120 then
    raise exception 'Invalid routine title or action count'
      using errcode = '22023';
  end if;
  if char_length(v_timezone) not between 2 and 80
      or not exists (select 1 from pg_catalog.pg_timezone_names where name = v_timezone) then
    raise exception 'Invalid timezone' using errcode = '22023';
  end if;

  insert into public.personal_routines(owner_user_id,title,is_active)
  values(p_target_user_id,btrim(p_title),true)
  returning id into v_routine;

  for v_step in select value from jsonb_array_elements(p_actions) loop
    if jsonb_typeof(v_step) <> 'object' then
      raise exception 'Invalid action or resource count'
        using errcode = '22023';
    end if;
    v_step_title := btrim(coalesce(v_step->>'title',''));
    v_step_notes := nullif(btrim(coalesce(v_step->>'notes','')), '');
    v_step_notification := coalesce(
      nullif(btrim(coalesce(v_step->>'notification_title','')), ''), v_step_title);
    v_step_template_id := nullif(btrim(coalesce(v_step->>'official_template_id','')), '');
    v_step_time_text := btrim(coalesce(v_step->>'local_time',''));
    if char_length(v_step_title) not between 1 and 160
       or (v_step ? 'notes'
           and jsonb_typeof(v_step->'notes') not in ('string','null'))
       or (v_step ? 'official_template_id'
           and jsonb_typeof(v_step->'official_template_id') not in ('string','null'))
       or char_length(coalesce(v_step_notes,'')) > 2000
       or (v_step ? 'notification_title'
           and jsonb_typeof(v_step->'notification_title') not in ('string','null'))
       or char_length(v_step_notification) not between 1 and 160
       or position('{দিন}' in coalesce(v_step_notes,'')) > 0
       or position('{বার}' in coalesce(v_step_notes,'')) > 0
       or position('{মিনিট}' in coalesce(v_step_notes,'')) > 0
       or (v_step_template_id is not null
           and v_step_template_id !~ '^[a-z][0-9]{2}$')
       or jsonb_typeof(v_step->'resources') is distinct from 'array'
       or (v_step_template_id ~ '^u[0-9]{2}$'
           and jsonb_array_length(v_step->'resources') = 0)
       or jsonb_array_length(v_step->'resources') > 16
       or v_step_time_text !~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$'
    then
      raise exception 'Invalid action or resource count'
        using errcode = '22023';
    end if;
    v_step_time := v_step_time_text::time;

    -- Validate every reference before inserting the action.
    v_seen := array[]::text[];
    v_first_provider := 'manual';
    v_first_cms := null;
    v_first_reference := null;
    for v_resource in
      select value from jsonb_array_elements(v_step->'resources')
    loop
      v_provider := v_resource->>'provider';
      v_cms_id := null;
      v_reference := null;
      if v_provider = 'cms' then
        if (v_resource->>'content_item_id') is null
           or (v_resource->>'content_item_id') !~
             '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
          raise exception 'Missing CMS identifier' using errcode = '22023';
        end if;
        v_cms_id := (v_resource->>'content_item_id')::uuid;
        if not exists (
          select 1 from public.content_items c
          where c.id = v_cms_id and c.status = 'published'
            and c.visibility = 'public'
            and (c.type <> 'quran' or c.verification_status = 'verified')
        ) then
          raise exception 'Only public verified or approved content is linkable'
            using errcode = '42501';
        end if;
        v_reference := 'cms:' || v_cms_id::text;
      elsif v_provider = 'quran' then
        v_reference := v_resource->>'external_resource_ref';
        if v_reference is null
          or v_reference !~ '^quran:[0-9]{1,3}(:[0-9]{1,3})?$'
          or split_part(v_reference,':',2)::integer not between 1 and 114
          or (split_part(v_reference,':',3) <> ''
              and split_part(v_reference,':',3)::integer not between 1 and 286)
        then
          raise exception 'Invalid canonical Quran reference'
            using errcode = '22023';
        end if;
      else
        raise exception 'Unsupported resource kind' using errcode = '22023';
      end if;
      if v_reference = any(v_seen) then
        raise exception 'Duplicate action resource' using errcode = '22023';
      end if;
      v_seen := array_append(v_seen,v_reference);
      if v_first_provider = 'manual' then
        v_first_provider := v_provider;
        v_first_cms := v_cms_id;
        v_first_reference := case when v_provider = 'quran' then v_reference end;
      end if;
    end loop;

    -- The first link is mirrored on the action row (like the self-service
    -- editor) so reminder taps open it directly.
    insert into public.personal_routine_actions(
      routine_id,owner_user_id,title,notification_title,notes,
      resource_provider,content_item_id,external_resource_ref,
      schedule_kind,local_time,timezone_name,is_active
    ) values (
      v_routine,p_target_user_id,v_step_title,v_step_notification,v_step_notes,
      v_first_provider,v_first_cms,v_first_reference,
      'fixed',v_step_time,v_timezone,true
    ) returning id into v_action;

    v_index := 0;
    for v_resource in
      select value from jsonb_array_elements(v_step->'resources')
    loop
      v_provider := v_resource->>'provider';
      insert into public.personal_routine_action_resources(
        action_id,owner_user_id,provider,content_item_id,
        external_resource_ref,sort_order
      ) values (
        v_action,p_target_user_id,v_provider,
        case when v_provider = 'cms'
          then (v_resource->>'content_item_id')::uuid end,
        case when v_provider = 'quran'
          then v_resource->>'external_resource_ref' end,
        v_index
      );
      v_index := v_index + 1;
    end loop;
    v_count := v_count + 1;
  end loop;

  insert into public.admin_audit_logs(
    actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    v_actor,'personal_routine.delegated_reminders_imported',
    'personal_routine',v_routine,
    jsonb_build_object(
      'target_user_id',p_target_user_id,'action_count',v_count,
      'owner_opt_in_required',false,'timezone',v_timezone
    )
  );
  return v_routine;
end;
$$;

revoke all on function public.admin_import_user_routine_reminders(uuid,text,jsonb,text)
  from public,anon;
grant execute on function public.admin_import_user_routine_reminders(uuid,text,jsonb,text)
  to authenticated;

create or replace function public.admin_get_user_routine_overview(
  p_target_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_routines jsonb;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required'
      using errcode = '42501';
  end if;
  if p_target_user_id is null or not exists (
    select 1 from public.profiles p where p.id = p_target_user_id
  ) then
    raise exception 'Target user profile was not found'
      using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]'::jsonb)
    into v_routines
  from (
    select
      pr.id,
      pr.title,
      pr.is_active,
      pr.created_at,
      exists (
        select 1 from public.admin_audit_logs aal
        where aal.entity_type = 'personal_routine'
          and aal.entity_id = pr.id
          and aal.action in (
            'personal_routine.delegated_draft_created',
            'personal_routine.delegated_reminders_imported'
          )
      ) as assigned_by_admin,
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', pa.id,
          'title', pa.title,
          'notification_title', pa.notification_title,
          'notes', pa.notes,
          'schedule_kind', pa.schedule_kind,
          'local_time', pa.local_time,
          'is_active', pa.is_active,
          'resource_type', case
            when pa.resource_provider = 'quran' then 'quran'
            when pa.resource_provider = 'hadith' then 'hadith'
            else ci.type::text
          end
        ) order by pa.local_time nulls last, pa.created_at)
        from public.personal_routine_actions pa
        left join public.content_items ci on ci.id = pa.content_item_id
        where pa.routine_id = pr.id
      ), '[]'::jsonb) as actions
    from public.personal_routines pr
    where pr.owner_user_id = p_target_user_id
    order by pr.created_at desc
    limit 50
  ) r;

  insert into public.admin_audit_logs(
    actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    v_actor,'personal_routine.overview_viewed',
    'user_profile',p_target_user_id,
    jsonb_build_object('routine_count',jsonb_array_length(v_routines))
  );
  return jsonb_build_object(
    'target_user_id',p_target_user_id,'routines',v_routines
  );
end;
$$;

revoke all on function public.admin_get_user_routine_overview(uuid)
  from public,anon;
grant execute on function public.admin_get_user_routine_overview(uuid)
  to authenticated;

-- Switch one action of an ADMIN-SET routine on or off. Routines the user
-- created for themselves are theirs to control and are refused here.
create or replace function public.admin_set_user_routine_action_reminder(
  p_action_id uuid,
  p_enabled boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_routine uuid;
  v_owner uuid;
  v_previous boolean;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required' using errcode = '42501';
  end if;
  if p_enabled is null then
    raise exception 'Reminder state is required' using errcode = '22023';
  end if;

  select pa.routine_id, pa.owner_user_id, pa.is_active
    into v_routine, v_owner, v_previous
  from public.personal_routine_actions pa
  where pa.id = p_action_id
  for update;
  if not found then
    raise exception 'Routine action was not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.admin_audit_logs aal
    where aal.entity_type = 'personal_routine'
      and aal.entity_id = v_routine
      and aal.action in (
        'personal_routine.delegated_draft_created',
        'personal_routine.delegated_reminders_imported'
      )
  ) then
    raise exception 'Only admin-set routines can be changed here'
      using errcode = '42501';
  end if;
  if v_previous is not distinct from p_enabled then
    return p_enabled;
  end if;

  update public.personal_routine_actions
  set is_active = p_enabled, updated_at = now()
  where id = p_action_id;

  insert into public.admin_audit_logs(
    actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    v_actor,'personal_routine.delegated_action_toggled',
    'personal_routine_action',p_action_id,
    jsonb_build_object(
      'routine_id',v_routine,'target_user_id',v_owner,'is_active',p_enabled
    )
  );
  return p_enabled;
end;
$$;

revoke all on function public.admin_set_user_routine_action_reminder(uuid,boolean)
  from public,anon;
grant execute on function public.admin_set_user_routine_action_reminder(uuid,boolean)
  to authenticated;

-- Owner decision 2026-11-10: prescribed patients may play these three
-- audios; they stay out of public Resources.
update public.content_items
set visibility = 'assigned_only', updated_at = now()
where slug in (
  'sukun-ruqyahbd-qital-tadmir',
  'sukun-ruqyahbd-khuruj',
  'sukun-ruqyahbd-shifa'
)
  and visibility = 'staff_only'
  and status = 'published';
