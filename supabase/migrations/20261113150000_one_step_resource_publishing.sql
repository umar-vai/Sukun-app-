-- One-step resource publishing (owner decision, 2026-11-13).
--
-- The Super Admin adds or edits a resource and it is published in the same
-- step. There is no separate submit/verify/publish review, no draft, no
-- mandatory source/edition/translation-source fields and no mandatory
-- rights/licensing note. For Qur'an and Hadith, the saving Super Admin is
-- recorded as the verifier (verified_by / verified_at) at the moment of
-- publication, so the existing "published canonical text is verified"
-- invariant and every reader that checks verification_status keep working.
--
-- Kept: Super Admin check in the database, idempotent request ids, audit
-- logs, lifecycle history rows, the ban on generative-AI canonical text, the
-- structural Qur'an (Surah/Ayah + Arabic) and Hadith (collection, book,
-- number) requirements, HTTPS-only links, archive instead of delete.
--
-- Forward-only. Historical review records stay intact, and the older
-- submit/verify/reject transitions remain callable for compatibility.

-- 1. Publication integrity: drop source-metadata and rights-note gates.
alter table public.content_items
  drop constraint if exists content_items_canonical_publication;
alter table public.content_items
  add constraint content_items_canonical_publication
    check (
      status <> 'published'
      or type not in ('quran', 'hadith')
      or (
        verification_status = 'verified'
        and verified_by is not null
        and verified_at is not null
        and lower(coalesce(btrim(source_type), '')) <> 'generative_ai'
      )
    );

alter table public.content_items
  drop constraint if exists content_items_canonical_source_metadata;
alter table public.content_items
  add constraint content_items_canonical_source_metadata
    check (
      status <> 'published'
      or type not in ('quran', 'hadith')
      or (
        (type <> 'quran' or nullif(btrim(arabic_text), '') is not null)
        and (
          type <> 'hadith'
          or (
            nullif(btrim(collection_name), '') is not null
            and nullif(btrim(book_name), '') is not null
            and nullif(btrim(hadith_number), '') is not null
          )
        )
      )
    );

alter table public.content_items
  drop constraint if exists content_items_published_media_rights;

create or replace function private.enforce_content_item_publication_integrity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status <> 'published' then
    return new;
  end if;

  if new.type in ('quran', 'hadith') then
    if lower(coalesce(btrim(new.source_type), '')) = 'generative_ai' then
      raise exception 'Canonical Qur''an and Hadith content cannot use a generative AI source.'
        using errcode = '22023';
    end if;
    if new.type = 'quran'
      and nullif(btrim(new.arabic_text), '') is null then
      raise exception 'Publishing a Qur''an resource requires its Arabic text. Use the Audio content type for a recitation-only resource.'
        using errcode = '22023';
    end if;
    if new.type = 'hadith' and (
      nullif(btrim(new.collection_name), '') is null
      or nullif(btrim(new.book_name), '') is null
      or nullif(btrim(new.hadith_number), '') is null
    ) then
      raise exception 'Publishing Hadith requires collection, book, and Hadith number.'
        using errcode = '22023';
    end if;
  end if;

  return new;
end;
$$;

-- 2. save_content_item: p_status 'published' saves and publishes in one
--    transaction, and published resources can be edited in place.
create or replace function public.save_content_item(
  p_type public.content_type,
  p_title text,
  p_slug text,
  p_visibility public.resource_visibility,
  p_status public.content_status,
  p_content_item_id uuid default null,
  p_category_id uuid default null,
  p_parent_content_id uuid default null,
  p_title_bn text default null,
  p_summary text default null,
  p_body text default null,
  p_arabic_text text default null,
  p_bangla_text text default null,
  p_transliteration text default null,
  p_translation text default null,
  p_reference_text text default null,
  p_source_type text default null,
  p_source_reference text default null,
  p_source_url text default null,
  p_source_edition text default null,
  p_translation_source text default null,
  p_surah_number integer default null,
  p_surah_name text default null,
  p_surah_name_bn text default null,
  p_ayah_number integer default null,
  p_ayah_end_number integer default null,
  p_collection_name text default null,
  p_book_name text default null,
  p_hadith_number text default null,
  p_narrator text default null,
  p_grade text default null,
  p_author text default null,
  p_publisher text default null,
  p_chapter_number integer default null,
  p_language_code text default null,
  p_rights_note text default null,
  p_thumbnail_url text default null,
  p_media_source_type public.media_source_type default null,
  p_media_url text default null,
  p_youtube_video_id text default null,
  p_request_id uuid default gen_random_uuid()
)
returns public.content_items
language plpgsql
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  saved_item public.content_items;
  current_item public.content_items;
  existing_entity_id uuid;
  canonical boolean := p_type in ('quran', 'hadith');
  publishing boolean := p_status = 'published';
  next_verification public.verification_status;
  next_verified_by uuid;
  next_verified_at timestamptz;
  next_published_at timestamptz;
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
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_entity_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'content_item_saved'
    and aal.request_id = p_request_id;
  if existing_entity_id is not null then
    select ci.* into saved_item from public.content_items ci where ci.id = existing_entity_id;
    if found then return saved_item; end if;
  end if;
  if p_status not in ('draft', 'review', 'published') then
    raise exception 'Content can be saved as draft, review or published.' using errcode = '22023';
  end if;
  if p_title is null or btrim(p_title) = '' then
    raise exception 'Content title is required.' using errcode = '22023';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Content slug must use lowercase words and hyphens.' using errcode = '22023';
  end if;
  if p_category_id is not null and not exists (
    select 1 from public.content_categories cc where cc.id = p_category_id and cc.is_active
  ) then
    raise exception 'An active category was not found.' using errcode = 'P0002';
  end if;
  if p_parent_content_id is not null and not exists (
    select 1 from public.content_items ci where ci.id = p_parent_content_id and ci.type = 'book'
  ) then
    raise exception 'Book chapter parent must be an existing book.' using errcode = '22023';
  end if;
  if p_type = 'book_chapter' and (p_parent_content_id is null or p_chapter_number is null) then
    raise exception 'Book chapters require a parent book and chapter number.' using errcode = '22023';
  end if;
  if canonical and lower(coalesce(btrim(p_source_type), '')) = 'generative_ai' then
    raise exception 'Canonical Qur''an and Hadith content cannot use a generative AI source.' using errcode = '22023';
  end if;
  if p_type = 'quran' and (
    p_surah_number is null or p_surah_number not between 1 and 114
    or p_ayah_number is null or p_ayah_number <= 0
  ) then
    raise exception 'Qur''an content requires a valid Surah and Ayah reference.' using errcode = '22023';
  end if;
  if p_source_url is not null and p_source_url !~ '^https://' then
    raise exception 'Source URL must use HTTPS.' using errcode = '22023';
  end if;
  if p_content_item_id is not null then
    select ci.* into current_item from public.content_items ci where ci.id = p_content_item_id for update;
    if not found then
      raise exception 'Content item was not found.' using errcode = 'P0002';
    end if;
    if current_item.status = 'archived' then
      raise exception 'Archived content cannot be edited.' using errcode = '55000';
    end if;
    if current_item.status = 'published' and not publishing then
      raise exception 'Published content can only be saved as published.' using errcode = '55000';
    end if;
  end if;

  if publishing and canonical then
    next_verification := 'verified';
    next_verified_by := caller_user_id;
    next_verified_at := now();
  elsif canonical then
    next_verification := 'pending';
  else
    next_verification := 'not_required';
  end if;
  next_published_at := case when publishing then now() else null end;

  if p_content_item_id is null then
    insert into public.content_items (
      type, category_id, parent_content_id, title, title_bn, slug, summary, body,
      arabic_text, bangla_text, transliteration, translation, reference_text,
      source_type, source_reference, source_url, source_edition, translation_source,
      verification_status, verified_by, verified_at,
      surah_number, surah_name, surah_name_bn, ayah_number, ayah_end_number,
      collection_name, book_name, hadith_number, narrator, grade, author, publisher,
      chapter_number, language_code, rights_note, thumbnail_url,
      media_source_type, media_url, youtube_video_id,
      visibility, status, published_at, created_by, updated_by
    ) values (
      p_type, p_category_id, p_parent_content_id, btrim(p_title), nullif(btrim(p_title_bn), ''),
      p_slug, nullif(btrim(p_summary), ''), nullif(btrim(p_body), ''),
      nullif(btrim(p_arabic_text), ''), nullif(btrim(p_bangla_text), ''),
      nullif(btrim(p_transliteration), ''), nullif(btrim(p_translation), ''),
      nullif(btrim(p_reference_text), ''),
      nullif(btrim(p_source_type), ''), nullif(btrim(p_source_reference), ''),
      nullif(btrim(p_source_url), ''), nullif(btrim(p_source_edition), ''),
      nullif(btrim(p_translation_source), ''),
      next_verification, next_verified_by, next_verified_at,
      p_surah_number::smallint, nullif(btrim(p_surah_name), ''), nullif(btrim(p_surah_name_bn), ''),
      p_ayah_number, p_ayah_end_number,
      nullif(btrim(p_collection_name), ''), nullif(btrim(p_book_name), ''),
      nullif(btrim(p_hadith_number), ''), nullif(btrim(p_narrator), ''),
      nullif(btrim(p_grade), ''), nullif(btrim(p_author), ''), nullif(btrim(p_publisher), ''),
      p_chapter_number, nullif(btrim(p_language_code), ''), nullif(btrim(p_rights_note), ''),
      nullif(btrim(p_thumbnail_url), ''),
      p_media_source_type, nullif(btrim(p_media_url), ''), nullif(btrim(p_youtube_video_id), ''),
      p_visibility, p_status, next_published_at, caller_user_id, caller_user_id
    ) returning * into saved_item;
  else
    update public.content_items set
      type = p_type,
      category_id = p_category_id,
      parent_content_id = p_parent_content_id,
      title = btrim(p_title),
      title_bn = nullif(btrim(p_title_bn), ''),
      slug = p_slug,
      summary = nullif(btrim(p_summary), ''),
      body = nullif(btrim(p_body), ''),
      arabic_text = nullif(btrim(p_arabic_text), ''),
      bangla_text = nullif(btrim(p_bangla_text), ''),
      transliteration = nullif(btrim(p_transliteration), ''),
      translation = nullif(btrim(p_translation), ''),
      reference_text = nullif(btrim(p_reference_text), ''),
      source_type = nullif(btrim(p_source_type), ''),
      source_reference = nullif(btrim(p_source_reference), ''),
      source_url = nullif(btrim(p_source_url), ''),
      source_edition = nullif(btrim(p_source_edition), ''),
      translation_source = nullif(btrim(p_translation_source), ''),
      verification_status = next_verification,
      verified_by = next_verified_by,
      verified_at = next_verified_at,
      surah_number = p_surah_number::smallint,
      surah_name = nullif(btrim(p_surah_name), ''),
      surah_name_bn = nullif(btrim(p_surah_name_bn), ''),
      ayah_number = p_ayah_number,
      ayah_end_number = p_ayah_end_number,
      collection_name = nullif(btrim(p_collection_name), ''),
      book_name = nullif(btrim(p_book_name), ''),
      hadith_number = nullif(btrim(p_hadith_number), ''),
      narrator = nullif(btrim(p_narrator), ''),
      grade = nullif(btrim(p_grade), ''),
      author = nullif(btrim(p_author), ''),
      publisher = nullif(btrim(p_publisher), ''),
      chapter_number = p_chapter_number,
      language_code = nullif(btrim(p_language_code), ''),
      rights_note = nullif(btrim(p_rights_note), ''),
      thumbnail_url = nullif(btrim(p_thumbnail_url), ''),
      media_source_type = p_media_source_type,
      media_url = nullif(btrim(p_media_url), ''),
      youtube_video_id = nullif(btrim(p_youtube_video_id), ''),
      visibility = p_visibility,
      status = p_status,
      -- An edit of an already published resource keeps its first publish time.
      published_at = case
        when publishing and current_item.status = 'published' then current_item.published_at
        else next_published_at
      end,
      archived_at = null,
      updated_by = caller_user_id
    where id = p_content_item_id
    returning * into saved_item;
  end if;

  if p_status = 'review' then
    insert into public.content_reviews (content_item_id, reviewer_user_id, decision)
    values (saved_item.id, caller_user_id, 'submitted');
  elsif publishing then
    insert into public.content_reviews (content_item_id, reviewer_user_id, decision, notes)
    values (
      saved_item.id, caller_user_id, 'published',
      case
        when p_content_item_id is null then 'Added and published in one step.'
        when current_item.status = 'published' then 'Edited and kept published.'
        else 'Edited and published in one step.'
      end
    );
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    caller_user_id, 'content_item_saved', 'content_item', saved_item.id, p_request_id,
    jsonb_build_object(
      'operation', case when p_content_item_id is null then 'created' else 'updated' end,
      'type', saved_item.type,
      'status', saved_item.status,
      'visibility', saved_item.visibility,
      'canonical', canonical,
      'one_step_publish', publishing
    )
  );
  return saved_item;
end;
$$;

revoke all on function public.save_content_item(
  public.content_type, text, text, public.resource_visibility, public.content_status,
  uuid, uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  text, text, integer, text, text, integer, integer, text, text, text, text, text, text,
  text, integer, text, text, text, public.media_source_type, text, text, uuid
) from public, anon, authenticated;
grant execute on function public.save_content_item(
  public.content_type, text, text, public.resource_visibility, public.content_status,
  uuid, uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  text, text, integer, text, text, integer, integer, text, text, text, text, text, text,
  text, integer, text, text, text, public.media_source_type, text, text, uuid
) to authenticated;

comment on function public.save_content_item(
  public.content_type, text, text, public.resource_visibility, public.content_status,
  uuid, uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  text, text, integer, text, text, integer, integer, text, text, text, text, text, text,
  text, integer, text, text, text, public.media_source_type, text, text, uuid
) is 'Audited Super Admin save. p_status published saves and publishes in one step; Qur''an/Hadith are verified by the saving Super Admin.';

-- 3. transition_content_item: 'publish' works from any unpublished state and
--    verifies Qur'an/Hadith as the publishing Super Admin.
create or replace function public.transition_content_item(
  p_content_item_id uuid,
  p_transition text,
  p_notes text default null,
  p_request_id uuid default gen_random_uuid()
)
returns public.content_items
language plpgsql
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
    raise exception 'Review notes must be 4000 characters or fewer.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_entity_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'content_item_' || p_transition
    and aal.request_id = p_request_id;
  if existing_entity_id is not null then
    select ci.* into item from public.content_items ci where ci.id = existing_entity_id;
    if found then return item; end if;
  end if;

  select ci.* into item from public.content_items ci where ci.id = p_content_item_id for update;
  if not found then
    raise exception 'Content item was not found.' using errcode = 'P0002';
  end if;
  canonical := item.type in ('quran', 'hadith');

  if p_transition = 'submit' then
    if item.status <> 'draft' then
      raise exception 'Only draft content can be submitted for review.' using errcode = '55000';
    end if;
    update public.content_items
    set status = 'review',
        verification_status = case
          when canonical then 'pending'::public.verification_status
          else 'not_required'::public.verification_status
        end,
        verified_by = null,
        verified_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'verify' then
    if not canonical or item.status <> 'review' then
      raise exception 'Only Qur''an or Hadith content awaiting review can be verified.'
        using errcode = '55000';
    end if;
    update public.content_items
    set status = 'verified',
        verification_status = 'verified',
        verified_by = caller_user_id,
        verified_at = now(),
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'reject' then
    if not canonical or item.status <> 'review' then
      raise exception 'Only Qur''an or Hadith content awaiting review can be returned.'
        using errcode = '55000';
    end if;
    update public.content_items
    set status = 'draft',
        verification_status = 'rejected',
        verified_by = null,
        verified_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'publish' then
    if item.status = 'published' then
      raise exception 'Content is already published.' using errcode = '55000';
    end if;
    update public.content_items
    set status = 'published',
        verification_status = case
          when canonical then 'verified'::public.verification_status
          else 'not_required'::public.verification_status
        end,
        verified_by = case
          when not canonical then null
          when item.verification_status = 'verified' then item.verified_by
          else caller_user_id
        end,
        verified_at = case
          when not canonical then null
          when item.verification_status = 'verified' then item.verified_at
          else now()
        end,
        published_at = now(),
        archived_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'unpublish' then
    if item.status <> 'published' then
      raise exception 'Only published content can be unpublished.' using errcode = '55000';
    end if;
    update public.content_items
    set status = case
          when canonical then 'verified'::public.content_status
          else 'review'::public.content_status
        end,
        published_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'archive' then
    if item.status = 'archived' then
      raise exception 'Content is already archived.' using errcode = '55000';
    end if;
    update public.content_items
    set status = 'archived',
        published_at = null,
        archived_at = now(),
        updated_by = caller_user_id
    where id = item.id returning * into item;
  end if;

  insert into public.content_reviews (content_item_id, reviewer_user_id, decision, notes)
  values (
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
      'one_step_publish', true
    )
  );

  return item;
end;
$$;

revoke all on function public.transition_content_item(uuid, text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.transition_content_item(uuid, text, text, uuid)
  to authenticated;

comment on function public.transition_content_item(uuid, text, text, uuid) is
  'Audited Super Admin content lifecycle. Publish works from any unpublished state; Qur''an/Hadith are verified by the publishing Super Admin.';
