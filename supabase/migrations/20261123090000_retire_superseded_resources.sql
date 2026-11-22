-- Retire the resources superseded by the structured resource library
-- (owner request, 2026-11-23).
--
-- After 20261122090000_structured_resource_library.sql, the owner wants the
-- new library in place of the older Ruqyah audio and Dua/Amal items. The
-- Self-Ruqyah Guide (four chapters), Ruqyah Ayat, Qur'an, Hadith, books,
-- PDFs and articles are not touched.
--
-- Nothing is deleted. Each superseded, published item is either:
--   * hidden from public lists (visibility -> 'assigned_only') when a care
--     plan, a personal routine or a care template still links it, so those
--     links keep working for the people who have them; or
--   * archived when nothing links it.
-- Every change is written to admin_audit_logs with the previous state, and a
-- Super Admin can republish or change visibility from the content editor.
--
-- 'assigned_only' already lets a patient read a resource linked from their
-- approved plan. Personal routines did not have that rule, so this migration
-- adds it: the routine's owner (and the people who may manage that
-- routine's patient profile) can still read a resource the routine links.

-- 1. Routine-linked resources stay readable for that routine's people. ------
create or replace function private.can_read_content_item(target_content_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.content_items ci
      where ci.id = target_content_id
        and ci.status = 'published'
        and (
          ci.visibility = 'public'
          or (
            ci.visibility = 'patient_only'
            and exists (select 1 from private.accessible_patient_ids())
          )
          or (
            ci.visibility = 'assigned_only'
            and (
              exists (
                select 1
                from public.plan_action_resources par
                join public.plan_actions pa on pa.id = par.plan_action_id
                join public.care_plans cp on cp.id = pa.care_plan_id
                where par.content_item_id = ci.id
                  and pa.review_status = 'approved'
                  and cp.status <> 'draft'
                  and private.can_access_patient(cp.patient_id)
              )
              or exists (
                select 1
                from public.personal_routine_actions pra
                join public.personal_routines pr on pr.id = pra.routine_id
                where pra.content_item_id = ci.id
                  and (
                    pra.owner_user_id = (select auth.uid())
                    or pr.patient_id in (
                      select private.accessible_patient_ids()
                    )
                  )
              )
              or exists (
                select 1
                from public.personal_routine_action_resources prar
                join public.personal_routine_actions pra
                  on pra.id = prar.action_id
                join public.personal_routines pr on pr.id = pra.routine_id
                where prar.content_item_id = ci.id
                  and (
                    prar.owner_user_id = (select auth.uid())
                    or pr.patient_id in (
                      select private.accessible_patient_ids()
                    )
                  )
              )
            )
          )
        )
    );
$$;

revoke execute on function private.can_read_content_item(uuid)
  from public;
grant execute on function private.can_read_content_item(uuid)
  to anon, authenticated;

-- 2. Hide or archive the superseded items. ------------------------------------
create or replace function private.retire_superseded_resources(p_actor uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  item record;
  hidden_count integer := 0;
  archived_count integer := 0;
  linked boolean;
begin
  for item in
    select ci.id, ci.slug, ci.type, ci.visibility, cc.slug as category_slug
    from public.content_items ci
    left join public.content_categories cc on cc.id = ci.category_id
    where ci.status = 'published'
      and (
        -- Older Dua & Amal: everything that is not one of the 90 new dua.
        (ci.type in ('dua', 'amal') and ci.slug not like 'dua-ma-%')
        or (
          -- Older Ruqyah audio that is not in a library group.
          ci.type = 'audio'
          and ci.slug not like 'ruqyah-lib-%'
          and coalesce(cc.slug, '') not like 'ruqyah-lib-%'
          and (
            cc.slug = 'ruqyah'
            or cc.slug like 'ruqyah-%'
            or ci.slug like 'sukun-ruqyahbd-%'
          )
        )
      )
    order by ci.slug
  loop
    linked := exists (
        select 1 from public.plan_action_resources par
        where par.content_item_id = item.id
      )
      or exists (
        select 1 from public.personal_routine_actions pra
        where pra.content_item_id = item.id
      )
      or exists (
        select 1 from public.personal_routine_action_resources prar
        where prar.content_item_id = item.id
      )
      or exists (
        select 1 from public.care_templates ct
        where item.slug = any (ct.resource_refs)
      );

    if linked then
      if item.visibility = 'assigned_only' then
        continue;
      end if;
      update public.content_items
      set visibility = 'assigned_only'
      where id = item.id;
      hidden_count := hidden_count + 1;
      insert into public.admin_audit_logs (
        actor_user_id, action, entity_type, entity_id, metadata
      ) values (
        p_actor, 'superseded_resource_hidden', 'content_item', item.id,
        jsonb_build_object(
          'slug', item.slug,
          'previous_visibility', item.visibility,
          'reason', 'replaced by the structured resource library; still linked'
        )
      );
    else
      update public.content_items
      set status = 'archived',
          published_at = null,
          archived_at = now()
      where id = item.id;
      archived_count := archived_count + 1;
      insert into public.admin_audit_logs (
        actor_user_id, action, entity_type, entity_id, metadata
      ) values (
        p_actor, 'superseded_resource_archived', 'content_item', item.id,
        jsonb_build_object(
          'slug', item.slug,
          'previous_status', 'published',
          'previous_visibility', item.visibility,
          'reason', 'replaced by the structured resource library'
        )
      );
    end if;
  end loop;

  return jsonb_build_object(
    'hidden', hidden_count,
    'archived', archived_count
  );
end;
$$;

revoke execute on function private.retire_superseded_resources(uuid)
  from public, anon, authenticated;

do $$
declare
  actor uuid;
  result jsonb;
begin
  -- Only where the new library is installed: never empty a section.
  if (
    select count(*) from public.content_items
    where status = 'published'
      and (slug like 'dua-ma-%' or slug like 'ruqyah-lib-%')
  ) = 0 then
    raise notice 'Resource library not installed; nothing retired.';
    return;
  end if;

  select ur.user_id into actor
  from public.user_roles ur
  join auth.users u on u.id = ur.user_id
  where ur.role = 'super_admin'
  order by u.created_at, ur.user_id
  limit 1;

  result := private.retire_superseded_resources(actor);
  raise notice 'Superseded resources retired: %', result;
end;
$$;
