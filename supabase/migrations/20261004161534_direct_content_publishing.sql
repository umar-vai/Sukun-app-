-- Super Admin direct-publishing policy.
--
-- Historical review/verification fields and records are intentionally retained,
-- but they no longer gate publication. Canonical source/reference validation,
-- RLS, server-verified Super Admin authorization, and lifecycle audit events
-- remain authoritative.

alter table public.content_items
  drop constraint content_items_canonical_publication;

alter table public.content_items
  add constraint content_items_canonical_publication
    check (
      status <> 'published'
      or type not in ('quran', 'hadith')
      or (
        nullif(btrim(source_type), '') is not null
        and lower(btrim(source_type)) <> 'generative_ai'
        and nullif(btrim(source_reference), '') is not null
      )
    );

comment on table public.content_reviews is
  'Admin-only content lifecycle history. Legacy review/verification events are retained; direct publish is the active workflow.';

create or replace function public.transition_content_item(
  p_content_item_id uuid,
  p_transition text,
  p_notes text default null,
  p_request_id uuid default gen_random_uuid()
)
returns public.content_items
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  item public.content_items;
  existing_entity_id uuid;
  canonical boolean;
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
  if p_transition not in ('submit', 'verify', 'reject', 'publish', 'unpublish', 'archive') then
    raise exception 'Unsupported content transition.' using errcode = '22023';
  end if;
  if p_notes is not null and char_length(p_notes) > 4000 then
    raise exception 'Lifecycle notes must be 4000 characters or fewer.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_entity_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'content_item_' || p_transition
    and aal.request_id = p_request_id;
  if existing_entity_id is not null then
    select ci.* into item
    from public.content_items ci where ci.id = existing_entity_id;
    if found then return item; end if;
  end if;

  select ci.* into item
  from public.content_items ci
  where ci.id = p_content_item_id
  for update;
  if not found then
    raise exception 'Content item was not found.' using errcode = 'P0002';
  end if;
  canonical := item.type in ('quran', 'hadith');

  -- Retain legacy transitions for historical clients, but the current app does
  -- not expose them and publication does not depend on them.
  if p_transition = 'submit' then
    if item.status <> 'draft' then
      raise exception 'Only draft content can be submitted for review.' using errcode = '55000';
    end if;
    update public.content_items
    set status = 'review',
        verification_status = case when canonical then 'pending' else 'not_required' end,
        verified_by = null,
        verified_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'verify' then
    if not canonical or item.status <> 'review' then
      raise exception 'Only Qur''an or Hadith content in review can be verified.'
        using errcode = '55000';
    end if;
    if nullif(btrim(item.source_reference), '') is null
      or nullif(btrim(item.source_type), '') is null
      or lower(btrim(item.source_type)) = 'generative_ai'
      or nullif(btrim(item.source_edition), '') is null then
      raise exception 'Verified canonical content requires approved source metadata.'
        using errcode = '22023';
    end if;
    if item.bangla_text is not null
      and nullif(btrim(item.translation_source), '') is null then
      raise exception 'Bangla canonical text requires an approved translation source.'
        using errcode = '22023';
    end if;
    if item.type = 'quran' and nullif(btrim(item.arabic_text), '') is null then
      raise exception 'Verified Qur''an content requires sourced Arabic text.'
        using errcode = '22023';
    end if;
    if item.type = 'hadith' and (
      nullif(btrim(item.collection_name), '') is null
      or nullif(btrim(item.book_name), '') is null
      or nullif(btrim(item.hadith_number), '') is null
    ) then
      raise exception 'Verified Hadith requires collection, book, and Hadith number.'
        using errcode = '22023';
    end if;
    update public.content_items
    set status = 'verified', verification_status = 'verified',
        verified_by = caller_user_id, verified_at = now(), updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'reject' then
    if not canonical or item.status <> 'review' then
      raise exception 'Only canonical content in review can be rejected.' using errcode = '55000';
    end if;
    update public.content_items
    set verification_status = 'rejected', verified_by = null, verified_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'publish' then
    if item.status = 'archived' then
      raise exception 'Archived content cannot be published.' using errcode = '55000';
    end if;
    if item.status = 'published' then
      raise exception 'Content is already published.' using errcode = '55000';
    end if;
    update public.content_items
    set status = 'published', published_at = now(), archived_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'unpublish' then
    if item.status <> 'published' then
      raise exception 'Only published content can be unpublished.' using errcode = '55000';
    end if;
    update public.content_items
    set status = 'draft', published_at = null, updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'archive' then
    if item.status = 'archived' then
      raise exception 'Content is already archived.' using errcode = '55000';
    end if;
    update public.content_items
    set status = 'archived', published_at = null, archived_at = now(),
        updated_by = caller_user_id
    where id = item.id returning * into item;
  end if;

  insert into public.content_reviews (
    content_item_id, reviewer_user_id, decision, notes
  ) values (
    item.id,
    caller_user_id,
    case p_transition
      when 'submit' then 'submitted'
      when 'verify' then 'verified'
      when 'reject' then 'rejected'
      when 'publish' then 'published'
      when 'unpublish' then 'unpublished'
      when 'archive' then 'archived'
    end,
    nullif(btrim(p_notes), '')
  );

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    caller_user_id,
    'content_item_' || p_transition,
    'content_item',
    item.id,
    p_request_id,
    jsonb_build_object(
      'type', item.type,
      'status', item.status,
      'visibility', item.visibility,
      'verification_status', item.verification_status,
      'direct_publish_policy', p_transition = 'publish'
    )
  );

  return item;
end;
$$;

create or replace function public.save_content_collection(
  p_type public.content_collection_type,
  p_title text,
  p_slug text,
  p_content_item_ids uuid[],
  p_collection_id uuid default null,
  p_title_bn text default null,
  p_summary text default null,
  p_visibility public.resource_visibility default 'public',
  p_request_id uuid default gen_random_uuid()
)
returns public.content_collections
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  saved_collection public.content_collections;
  existing_entity_id uuid;
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
  if p_title is null or btrim(p_title) = '' then
    raise exception 'Collection title is required.' using errcode = '22023';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Collection slug must use lowercase words and hyphens.' using errcode = '22023';
  end if;
  if p_visibility not in ('public', 'patient_only') then
    raise exception 'Collections support public or patient-only visibility.' using errcode = '22023';
  end if;
  if cardinality(p_content_item_ids) is null or cardinality(p_content_item_ids) = 0 then
    raise exception 'Select at least one Qur''an Ayah.' using errcode = '22023';
  end if;
  if cardinality(p_content_item_ids) <> (
    select count(distinct requested_id)
    from unnest(p_content_item_ids) as requested(requested_id)
  ) then
    raise exception 'A collection cannot contain duplicate Ayat.' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(p_content_item_ids) requested(requested_id)
    left join public.content_items ci on ci.id = requested.requested_id
    where ci.id is null or ci.type <> 'quran' or ci.status = 'archived'
  ) then
    raise exception 'Collections may only reference active canonical Qur''an Ayat.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_entity_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'content_collection_saved'
    and aal.request_id = p_request_id;
  if existing_entity_id is not null then
    select cc.* into saved_collection
    from public.content_collections cc where cc.id = existing_entity_id;
    if found then return saved_collection; end if;
  end if;

  if p_collection_id is null then
    insert into public.content_collections (
      type, title, title_bn, slug, summary, visibility, created_by, updated_by
    ) values (
      p_type, btrim(p_title), nullif(btrim(p_title_bn), ''), p_slug,
      nullif(btrim(p_summary), ''), p_visibility, caller_user_id, caller_user_id
    ) returning * into saved_collection;
  else
    update public.content_collections
    set type = p_type,
        title = btrim(p_title),
        title_bn = nullif(btrim(p_title_bn), ''),
        slug = p_slug,
        summary = nullif(btrim(p_summary), ''),
        visibility = p_visibility,
        updated_by = caller_user_id,
        updated_at = now()
    where id = p_collection_id and status = 'draft'
    returning * into saved_collection;
    if not found then
      raise exception 'Only a draft collection can be edited.' using errcode = '55000';
    end if;
    delete from public.content_collection_items where collection_id = saved_collection.id;
  end if;

  insert into public.content_collection_items (
    collection_id, content_item_id, sort_order, created_by
  )
  select saved_collection.id, requested_id, ordinal - 1, caller_user_id
  from unnest(p_content_item_ids) with ordinality requested(requested_id, ordinal);

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    caller_user_id, 'content_collection_saved', 'content_collection',
    saved_collection.id, p_request_id,
    jsonb_build_object('type', saved_collection.type, 'item_count', cardinality(p_content_item_ids))
  );
  return saved_collection;
end;
$$;

create or replace function public.transition_content_collection(
  p_collection_id uuid,
  p_transition text,
  p_request_id uuid default gen_random_uuid()
)
returns public.content_collections
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  saved_collection public.content_collections;
  existing_entity_id uuid;
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
  if p_transition not in ('publish', 'unpublish', 'archive') then
    raise exception 'Unsupported collection transition.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_entity_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'content_collection_transitioned'
    and aal.request_id = p_request_id;
  if existing_entity_id is not null then
    select cc.* into saved_collection
    from public.content_collections cc where cc.id = existing_entity_id;
    if found then return saved_collection; end if;
  end if;

  select cc.* into saved_collection
  from public.content_collections cc where cc.id = p_collection_id for update;
  if not found then
    raise exception 'Collection was not found.' using errcode = 'P0002';
  end if;

  if p_transition = 'publish' then
    if saved_collection.status <> 'draft' then
      raise exception 'Only a draft collection can be published.' using errcode = '55000';
    end if;
    if not exists (
      select 1 from public.content_collection_items cci
      where cci.collection_id = p_collection_id
    ) or exists (
      select 1 from public.content_collection_items cci
      join public.content_items ci on ci.id = cci.content_item_id
      where cci.collection_id = p_collection_id and ci.status <> 'published'
    ) then
      raise exception 'Publish every Ayah before publishing its collection.' using errcode = '55000';
    end if;
    update public.content_collections
    set status = 'published', published_at = now(), archived_at = null,
        updated_by = caller_user_id, updated_at = now()
    where id = p_collection_id returning * into saved_collection;
  elsif p_transition = 'unpublish' then
    if saved_collection.status <> 'published' then
      raise exception 'Only a published collection can be unpublished.' using errcode = '55000';
    end if;
    update public.content_collections
    set status = 'draft', published_at = null, archived_at = null,
        updated_by = caller_user_id, updated_at = now()
    where id = p_collection_id returning * into saved_collection;
  else
    if saved_collection.status = 'archived' then
      raise exception 'Collection is already archived.' using errcode = '55000';
    end if;
    update public.content_collections
    set status = 'archived', published_at = null, archived_at = now(),
        updated_by = caller_user_id, updated_at = now()
    where id = p_collection_id returning * into saved_collection;
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    caller_user_id, 'content_collection_transitioned', 'content_collection',
    saved_collection.id, p_request_id,
    jsonb_build_object('transition', p_transition, 'status', saved_collection.status)
  );
  return saved_collection;
end;
$$;
