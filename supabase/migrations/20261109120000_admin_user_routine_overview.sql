-- Read-only overview of one user's routines for Super Admin / raqi, split by
-- who set them: routines created by an admin RPC (found through the audit
-- log) versus routines the user added for themselves. Used for the
-- prescription PDF and the "self-added reminders" section.
--
-- Additive SECURITY DEFINER function; owner RLS on the tables is unchanged.
-- Every call is audited.
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
          'title', pa.title,
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
