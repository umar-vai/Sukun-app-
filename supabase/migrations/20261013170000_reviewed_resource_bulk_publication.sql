-- Reviewed Sukun Life resources: authenticated, audited, atomic batch publication.
-- Scope deliberately excludes unfinished Qur'an passages and test/private data.
create or replace function public.publish_reviewed_resource_batch(
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
  ok_count integer := 0;
  failed_count integer := 0;
  skipped_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  allowed_book boolean;
  allowed_audio boolean;
  before_visibility public.resource_visibility;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_request_id is null or p_content_item_ids is null
     or coalesce(array_length(p_content_item_ids, 1), 0) < 1
     or array_length(p_content_item_ids, 1) > 100 then
    raise exception 'Choose between one and 100 reviewed content items.'
      using errcode = '22023';
  end if;
  if array_position(p_content_item_ids, null) is not null then
    raise exception 'Invalid content identifier.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  -- Locks/reloads current database rows: never write an old screen snapshot.
  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) requested
      on requested.id = ci.id
    order by ci.id
    for update of ci
  loop
    allowed_book :=
      item.slug like 'srg2024-%'
      and item.slug not like 'srg2024-qur-%'
      and item.type in ('article', 'dua', 'amal')
      and item.rights_note like
        'Sukun Life owner attested app-use rights on 2026-10-12.%'
      and item.source_reference is not null
      and btrim(item.source_reference) <> ''
      and item.arabic_text is null
      or false;

    -- Dua source material contains Arabic: retain source-based Dua, but do
    -- not let an ARTICLE with unverified Arabic masquerade as a Qur'an Ayah.
    if item.type = 'dua' and item.slug like 'srg2024-dua-%'
       and item.rights_note like
         'Sukun Life owner attested app-use rights on 2026-10-12.%'
       and nullif(btrim(item.source_reference), '') is not null then
      allowed_book := true;
    end if;

    allowed_audio :=
      item.slug like 'sukun-ruqyahbd-%'
      and item.type = 'audio'
      and item.media_source_type = 'direct_audio_url'
      and item.media_url like 'https://files.ruqyahbd.org/audio/%'
      and split_part(item.media_url, '/', 3) = 'files.ruqyahbd.org'
      and item.rights_note like
        'Owner-attested Sukun Life audio authorization (2026-10-12).%'
      and nullif(btrim(item.source_reference), '') is not null;

    if item.status not in ('draft', 'review')
       or item.visibility not in ('staff_only', 'public')
       or item.title ilike '%QA TEST%'
       or item.title like '%সূত্র যাচাই প্রয়োজন%'
       or item.slug ~* '(^|[-_])(qa|test|fixture|sample|synthetic)([-_]|$)'
       or not (allowed_book or allowed_audio) then
      skipped_count := skipped_count + 1;
      continue;
    end if;

    begin
      before_visibility := item.visibility;
      if item.visibility = 'staff_only' then
        update public.content_items
        set visibility = 'public',
            updated_by = caller_user_id
        where id = item.id;
        insert into public.admin_audit_logs(
          actor_user_id, action, entity_type, entity_id, request_id, metadata
        ) values (
          caller_user_id, 'content_item_visibility_public', 'content_item',
          item.id, gen_random_uuid(),
          jsonb_build_object('batch_request_id', p_request_id,
                             'previous_visibility', before_visibility,
                             'reason', 'user-reviewed authorized source batch')
        );
      end if;

      if item.status = 'draft' then
        perform public.transition_content_item(
          item.id, 'submit',
          'Super Admin reviewed source batch submission.',
          gen_random_uuid()
        );
      end if;
      perform public.transition_content_item(
        item.id, 'publish',
        'Super Admin reviewed source batch publication.',
        gen_random_uuid()
      );
      ok_count := ok_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
      -- The inner subtransaction reverts both visibility and status.
    end;
  end loop;

  return jsonb_build_object(
    'published', ok_count,
    'failed', failed_count,
    'skipped', skipped_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.publish_reviewed_resource_batch(uuid[],uuid)
  from public, anon;
grant execute on function public.publish_reviewed_resource_batch(uuid[],uuid)
  to authenticated;
