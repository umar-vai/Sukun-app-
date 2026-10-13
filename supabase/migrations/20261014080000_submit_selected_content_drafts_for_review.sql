-- Review is a queue transition, never a publication.
-- The existing transition_content_item function owns status, reviewer history
-- and server audit. This wrapper only batches SELECTED eligible draft IDs.
create or replace function public.submit_selected_content_drafts_for_review(
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
  submitted_count integer := 0;
  skipped_count integer := 0;
  failed_count integer := 0;
  failed_item_ids uuid[] := array[]::uuid[];
  requested_count integer;
  seen_count integer := 0;
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

  -- Re-read and lock the *current* record, never trust the Flutter snapshot.
  for item in
    select ci.*
    from public.content_items ci
    join (select distinct unnest(p_content_item_ids) as id) selected
      on selected.id = ci.id
    order by ci.id
    for update of ci
  loop
    seen_count := seen_count + 1;

    -- QA/private patient items are not legitimate editorial submissions.
    -- Unsourced Qur'an editorial drafts may be SUBMITTED for human review;
    -- they are NOT source-verified or published by this function.
    if item.status <> 'draft'
       or item.visibility not in ('staff_only', 'public')
       or item.slug ~* '(^|[-_])(qa|test|fixture|sample|synthetic)([-_]|$)'
       or item.title ilike '%QA TEST%'
    then
      skipped_count := skipped_count + 1;
      continue;
    end if;

    begin
      perform public.transition_content_item(
        item.id,
        'submit',
        'Super Admin sent selected draft for human review; not published.',
        gen_random_uuid()
      );
      submitted_count := submitted_count + 1;
    exception when others then
      failed_count := failed_count + 1;
      failed_item_ids := array_append(failed_item_ids, item.id);
      -- A failed item's status and audit changes roll back together.
    end;
  end loop;

  -- Report IDs missing since selection as skipped; do not fabricate success.
  skipped_count := skipped_count + (
    select count(*)
    from (select distinct unnest(p_content_item_ids) as id) requested
    where not exists (
      select 1 from public.content_items ci where ci.id = requested.id
    )
  );

  return jsonb_build_object(
    'submitted', submitted_count,
    'skipped', skipped_count,
    'failed', failed_count,
    'failed_ids', to_jsonb(failed_item_ids)
  );
end;
$$;

revoke all on function public.submit_selected_content_drafts_for_review(uuid[], uuid)
  from public, anon;
grant execute on function public.submit_selected_content_drafts_for_review(uuid[], uuid)
  to authenticated;
