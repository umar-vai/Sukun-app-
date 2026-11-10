-- Default reminder name per care template (owner request 2026-11-10).
--
-- A Super Admin sets, in the template editor, the name the phone shows when
-- this template's reminder fires. Bulk import fills the per-row
-- "notification name" box with it, and the admin can still change it for one
-- person before importing. Null keeps the old behaviour (template title).
-- Additive only: one nullable column, and the save function learns the field.

alter table public.care_templates
  add column if not exists notification_title text;
alter table public.care_templates
  drop constraint if exists care_templates_notification_title_length;
alter table public.care_templates
  add constraint care_templates_notification_title_length
  check (notification_title is null
         or char_length(btrim(notification_title)) between 1 and 120);

comment on column public.care_templates.notification_title is
  'Default reminder name for rows imported from this template. Null = template title.';

create or replace function public.admin_save_care_template(p_template jsonb)
returns public.care_templates
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_id text := nullif(btrim(coalesce(p_template->>'id', '')), '');
  v_category text := btrim(coalesce(p_template->>'category', ''));
  v_title text := btrim(coalesce(p_template->>'title', ''));
  v_instruction text := btrim(coalesce(p_template->>'instruction', ''));
  v_notification_title text :=
    nullif(btrim(coalesce(p_template->>'notification_title', '')), '');
  v_action_type text;
  v_times time[] := '{}';
  v_refs text[] := '{}';
  v_value text;
  v_prefix text;
  v_next integer;
  v_before public.care_templates;
  v_saved public.care_templates;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_template is null or jsonb_typeof(p_template) <> 'object' then
    raise exception 'Invalid template.' using errcode = '22023';
  end if;

  if v_notification_title is not null
     and char_length(v_notification_title) > 120 then
    raise exception 'Reminder name is too long.' using errcode = '22023';
  end if;

  v_prefix := case v_category
    when 'amal' then 'a' when 'supplement' then 's' when 'bath' then 'b'
    when 'audio' then 'u' when 'special' then 'x' end;
  if v_prefix is null then
    raise exception 'Invalid template category.' using errcode = '22023';
  end if;
  v_action_type := coalesce(
    nullif(btrim(coalesce(p_template->>'action_type', '')), ''),
    case v_category when 'special' then 'amal' else v_category end
  );

  if jsonb_typeof(coalesce(p_template->'default_times', '[]')) <> 'array'
     or jsonb_typeof(coalesce(p_template->'resource_refs', '[]')) <> 'array' then
    raise exception 'Invalid template lists.' using errcode = '22023';
  end if;
  for v_value in
    select value from jsonb_array_elements_text(coalesce(p_template->'default_times', '[]'))
  loop
    if v_value !~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' then
      raise exception 'Invalid reminder time.' using errcode = '22023';
    end if;
    if not (v_value::time = any(v_times)) then
      v_times := array_append(v_times, v_value::time);
    end if;
  end loop;
  select coalesce(array_agg(t order by t), '{}') into v_times from unnest(v_times) t;
  for v_value in
    select value from jsonb_array_elements_text(coalesce(p_template->'resource_refs', '[]'))
  loop
    if v_value !~ '^(quran:[0-9]{1,3}|[a-z0-9][a-z0-9-]{0,119})$'
       or (v_value ~ '^quran:' and split_part(v_value, ':', 2)::integer not between 1 and 114) then
      raise exception 'Invalid content link.' using errcode = '22023';
    end if;
    if not (v_value = any(v_refs)) then
      v_refs := array_append(v_refs, v_value);
    end if;
  end loop;

  if v_id is null then
    -- New template: next free number for its category letter.
    perform pg_advisory_xact_lock(hashtextextended('care_templates:' || v_prefix, 0));
    select coalesce(max(substring(ct.id from 2)::integer), 0) + 1 into v_next
    from public.care_templates ct
    where ct.id like v_prefix || '%';
    if v_next > 99 then
      raise exception 'No free template number in this category.' using errcode = '22023';
    end if;
    v_id := v_prefix || lpad(v_next::text, 2, '0');
  else
    select ct.* into v_before from public.care_templates ct where ct.id = v_id for update;
    if not found then
      raise exception 'Template was not found.' using errcode = 'P0002';
    end if;
  end if;

  insert into public.care_templates as ct (
    id, category, title, instruction, action_type, default_times,
    resource_refs, requires_resource, sort_order, is_active, updated_by,
    notification_title
  ) values (
    v_id, v_category, v_title, v_instruction, v_action_type, v_times, v_refs,
    coalesce((p_template->>'requires_resource')::boolean, false),
    coalesce(
      (p_template->>'sort_order')::integer,
      (select coalesce(max(o.sort_order), 0) + 10 from public.care_templates o
       where o.category = v_category)
    ),
    coalesce((p_template->>'is_active')::boolean, true),
    v_actor,
    v_notification_title
  )
  on conflict (id) do update set
    category = excluded.category,
    title = excluded.title,
    instruction = excluded.instruction,
    action_type = excluded.action_type,
    default_times = excluded.default_times,
    resource_refs = excluded.resource_refs,
    requires_resource = excluded.requires_resource,
    sort_order = coalesce((p_template->>'sort_order')::integer, ct.sort_order),
    is_active = excluded.is_active,
    notification_title = excluded.notification_title,
    updated_at = now(),
    updated_by = v_actor
  returning * into v_saved;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, metadata
  ) values (
    v_actor,
    case when v_before.id is null then 'care_template.created' else 'care_template.updated' end,
    'care_template',
    null,
    jsonb_build_object(
      'template_id', v_saved.id,
      'before', case when v_before.id is null then null else to_jsonb(v_before) end,
      'after', to_jsonb(v_saved)
    )
  );
  return v_saved;
end;
$$;

revoke all on function public.admin_save_care_template(jsonb) from public, anon;
grant execute on function public.admin_save_care_template(jsonb) to authenticated;
