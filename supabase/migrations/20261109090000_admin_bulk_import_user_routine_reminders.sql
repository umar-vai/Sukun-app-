-- One-click bulk import of Sukun templates and library resources into a
-- user's routine, with fixed daily reminder times.
--
-- Owner decision (2026-11-09): a Super Admin import is the approval, so the
-- routine starts ACTIVE instead of waiting for the user to opt in. The user
-- still controls device notifications (OS permission and the in-app bell),
-- can pause or delete the routine, and every import is audited.
--
-- Additive: new SECURITY DEFINER function only. No table, grant or RLS policy
-- on existing tables changes. Validation mirrors admin_create_user_routine.
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
    v_step_template_id := nullif(btrim(coalesce(v_step->>'official_template_id','')), '');
    v_step_time_text := btrim(coalesce(v_step->>'local_time',''));
    if char_length(v_step_title) not between 1 and 160
       or (v_step ? 'notes'
           and jsonb_typeof(v_step->'notes') not in ('string','null'))
       or (v_step ? 'official_template_id'
           and jsonb_typeof(v_step->'official_template_id') not in ('string','null'))
       or char_length(coalesce(v_step_notes,'')) > 2000
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
      v_routine,p_target_user_id,v_step_title,v_step_title,v_step_notes,
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
