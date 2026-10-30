-- Explicit Super Admin-only delegation and scoped, audited progress reads.
-- Individual users still own all personal routine, action and progress rows.
-- This migration deliberately does NOT expand their existing RLS policies.
-- Admin-created ROUTINES remain inactive until their owner opts in.
-- Their actions are ready but cannot schedule while the parent routine is off.
create or replace function public.admin_create_user_routine(
  p_target_user_id uuid,
  p_title text,
  p_actions jsonb
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
  v_provider text;
  v_reference text;
  v_cms_id uuid;
  v_count integer := 0;
  v_index integer;
  v_seen text[];
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
      or jsonb_array_length(p_actions) not between 1 and 12 then
    raise exception 'Invalid routine title or action count'
      using errcode = '22023';
  end if;

  -- Do not turn on notifications or change clinical patient plans on behalf
  -- of the target. User will enable this personal draft explicitly.
  insert into public.personal_routines(owner_user_id,title,is_active)
  values(p_target_user_id,btrim(p_title),false)
  returning id into v_routine;

  for v_step in select value from jsonb_array_elements(p_actions) loop
    v_step_title := btrim(coalesce(v_step->>'title',''));
    if jsonb_typeof(v_step) <> 'object'
       or char_length(v_step_title) not between 1 and 160
       or jsonb_typeof(v_step->'resources') <> 'array'
       or jsonb_array_length(v_step->'resources') > 16
    then
      raise exception 'Invalid action or resource count'
        using errcode = '22023';
    end if;
    insert into public.personal_routine_actions(
      routine_id,owner_user_id,title,notification_title,
      schedule_kind,resource_provider,is_active
    ) values (
      v_routine,p_target_user_id,v_step_title,v_step_title,
      'manual','manual',true
    ) returning id into v_action;

    v_count := v_count + 1;
    v_index := 0;
    v_seen := array[]::text[];
    for v_resource in
      select value from jsonb_array_elements(v_step->'resources')
    loop
      v_provider := v_resource->>'provider';
      v_cms_id := null;
      v_reference := null;
      if v_provider = 'cms' then
        if (v_resource->>'content_item_id') is null then
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

      insert into public.personal_routine_action_resources(
        action_id,owner_user_id,provider,content_item_id,
        external_resource_ref,sort_order
      ) values (
        v_action,p_target_user_id,v_provider,v_cms_id,
        case when v_provider = 'cms' then null else v_reference end,
        v_index
      );
      v_index := v_index + 1;
    end loop;
  end loop;

  insert into public.admin_audit_logs(
    actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    v_actor,'personal_routine.delegated_draft_created',
    'personal_routine',v_routine,
    jsonb_build_object(
      'target_user_id',p_target_user_id,'action_count',v_count,
      'owner_opt_in_required',true
    )
  );
  return v_routine;
end;
$$;

revoke all on function public.admin_create_user_routine(uuid,text,jsonb)
  from public,anon;
grant execute on function public.admin_create_user_routine(uuid,text,jsonb)
  to authenticated;

create or replace function public.admin_get_user_routine_progress(
  p_target_user_id uuid,
  p_days integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_routines jsonb;
  v_progress jsonb;
  v_target_name text;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required'
      using errcode = '42501';
  end if;
  if p_days not in (7,30) then
    raise exception 'Only 7 or 30 days are supported'
      using errcode = '22023';
  end if;
  select p.display_name into v_target_name
  from public.profiles p where p.id = p_target_user_id;
  if not found then
    raise exception 'Target user profile was not found'
      using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]'::jsonb)
    into v_routines
  from (
    select pr.id,pr.title,pr.is_active,pr.created_at
    from public.personal_routines pr
    where pr.owner_user_id = p_target_user_id
    order by pr.created_at desc
    limit 50
  ) r;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.local_date desc),'[]'::jsonb)
    into v_progress
  from (
    select pp.local_date,pp.outcome,pa.title as action_title,
      pr.title as routine_title
    from public.personal_routine_progress pp
    join public.personal_routine_actions pa on pa.id=pp.action_id
    join public.personal_routines pr on pr.id=pa.routine_id
    where pp.owner_user_id = p_target_user_id
      and pp.local_date >= current_date-(p_days-1)
    order by pp.local_date desc,pp.occurred_at desc
    limit 250
  ) x;

  -- Audit even read-only access to a different user's check-ins.
  insert into public.admin_audit_logs(
    actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    v_actor,'personal_routine.progress_viewed',
    'user_profile',p_target_user_id,
    jsonb_build_object('days',p_days,'record_count',jsonb_array_length(v_progress))
  );
  return jsonb_build_object(
    'target_user_id',p_target_user_id,'display_name',v_target_name,
    'days',p_days,'routines',v_routines,'progress',v_progress
  );
end;
$$;

revoke all on function public.admin_get_user_routine_progress(uuid,integer)
  from public,anon;
grant execute on function public.admin_get_user_routine_progress(uuid,integer)
  to authenticated;
