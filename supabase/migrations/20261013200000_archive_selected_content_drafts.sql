-- Admin-only bulk soft delete: archive selected DRAFT items.
-- Avoid client snapshot races and preserve evidence, audit history, and linked records.
create or replace function public.archive_selected_content_drafts(
  p_content_item_ids uuid[],
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  item public.content_items;
  archived_count integer := 0;
  skipped_count integer := 0;
  failed_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  requested_count integer;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  requested_count := coalesce(array_length(p_content_item_ids, 1), 0);
  if p_request_id is null or requested_count < 1 or requested_count > 100 then
    raise exception 'Select between 1 and 100 draft items.'
      using errcode = '22023';
  end if;
  if array_position(p_content_item_ids, null) is not null then
    raise exception 'Invalid content identifier.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  -- Recheck every status *after* obtaining its row lock. A draft published
  -- by another administrator in the meantime must never be archived here.
  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) selected
      on selected.id = ci.id
    order by ci.id
    for update of ci
  loop
    if item.status <> 'draft' then
      skipped_count := skipped_count + 1;
      continue;
    end if;

    begin
      perform public.transition_content_item(
        item.id,
        'archive',
        'Super Admin bulk draft archive (soft delete; preserves history).',
        gen_random_uuid()
      );
      archived_count := archived_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
    end;
  end loop;

  return jsonb_build_object(
    'archived', archived_count,
    'skipped', skipped_count,
    'failed', failed_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.archive_selected_content_drafts(uuid[],uuid)
  from public, anon;
grant execute on function public.archive_selected_content_drafts(uuid[],uuid)
  to authenticated;
