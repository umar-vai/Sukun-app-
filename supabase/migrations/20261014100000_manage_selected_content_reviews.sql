-- Review-queue bulk operations: safe correction and reversible archive.
-- Never bulk approve canonical scripture or publish items without source review.
create or replace function public.manage_selected_content_reviews(
  p_content_item_ids uuid[],
  p_action text,
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
  changed_count integer := 0;
  skipped_count integer := 0;
  failed_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  request_size integer;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  request_size := coalesce(array_length(p_content_item_ids, 1), 0);
  if p_action not in ('return_to_draft', 'archive')
      or p_action is null or p_request_id is null
      or request_size < 1 or request_size > 100
      or array_position(p_content_item_ids, null) is not null then
    raise exception 'Invalid review bulk action or selection.'
      using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) requested
      on ci.id = requested.id
    order by ci.id
    for update of ci
  loop
    -- A concurrent state change or private QA item must never be modified.
    if item.status <> 'review'
       or item.visibility not in ('staff_only','public')
       or item.slug ~* '(^|[-_])(qa|test|fixture|sample|synthetic)([-_]|$)'
       or item.title ilike '%QA TEST%' then
      skipped_count := skipped_count + 1;
      continue;
    end if;
    begin
      if p_action = 'archive' then
        perform public.transition_content_item(
          item.id, 'archive',
          'Super Admin archived a selected review item (soft delete).',
          gen_random_uuid()
        );
      elsif item.type in ('quran','hadith') then
        -- Canonical "reject" already resets verified metadata and audits.
        perform public.transition_content_item(
          item.id, 'reject',
          'Returned from review for correction; Quran/Hadith not verified.',
          gen_random_uuid()
        );
      else
        -- The standard reject transition only accepts canonical items.
        -- Editorial review items need an equally audited return path.
        update public.content_items
        set status = 'draft',
            verification_status = 'not_required',
            verified_by = null,
            verified_at = null,
            published_at = null,
            updated_by = caller_user_id
        where id = item.id;

        insert into public.content_reviews(
          content_item_id, reviewer_user_id, decision, notes
        ) values (
          item.id, caller_user_id, 'rejected',
          'Sent back for editing from bulk review; never published.'
        );

        insert into public.admin_audit_logs(
          actor_user_id, action, entity_type, entity_id, request_id, metadata
        ) values (
          caller_user_id, 'content_item_return_to_draft', 'content_item',
          item.id, gen_random_uuid(),
          jsonb_build_object(
            'batch_request_id', p_request_id,
            'from_status','review', 'to_status','draft',
            'visibility',item.visibility, 'review_required',true
          )
        );
      end if;
      changed_count := changed_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
    end;
  end loop;

  skipped_count := skipped_count + (
    select count(*)
    from (select distinct unnest(p_content_item_ids) as id) requested
    where not exists (
      select 1 from public.content_items ci where ci.id = requested.id
    )
  );

  return jsonb_build_object(
    'changed', changed_count,
    'skipped', skipped_count,
    'failed', failed_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.manage_selected_content_reviews(uuid[],text,uuid)
  from public, anon;
grant execute on function public.manage_selected_content_reviews(uuid[],text,uuid)
  to authenticated;
