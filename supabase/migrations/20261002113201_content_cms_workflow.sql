-- Audited Super Admin content workflow and structured canonical resource metadata.
-- Canonical Qur'an/Hadith text must be human-sourced, reviewed, and explicitly
-- published. Published resources are immutable until explicitly unpublished.

alter table public.content_items
  add column parent_content_id uuid references public.content_items (id) on delete restrict,
  add column chapter_number integer,
  add column surah_name text,
  add column surah_name_bn text,
  add column ayah_end_number integer,
  add column source_edition text,
  add column language_code text;

alter table public.content_items
  add constraint content_items_parent_not_self
    check (parent_content_id is distinct from id),
  add constraint content_items_chapter_number_positive
    check (chapter_number is null or chapter_number > 0),
  add constraint content_items_language_code_format
    check (language_code is null or language_code ~ '^[a-z]{2,3}(?:-[A-Z]{2})?$'),
  add constraint content_items_ayah_range
    check (
      ayah_end_number is null
      or (
        type = 'quran'
        and ayah_number is not null
        and ayah_end_number >= ayah_number
      )
    ),
  add constraint content_items_book_parent
    check (type <> 'book_chapter' or parent_content_id is not null),
  add constraint content_items_canonical_source_metadata
    check (
      status <> 'published'
      or type not in ('quran', 'hadith')
      or (
        nullif(btrim(source_type), '') is not null
        and lower(btrim(source_type)) <> 'generative_ai'
        and nullif(btrim(source_edition), '') is not null
        and (
          nullif(btrim(bangla_text), '') is null
          or nullif(btrim(translation_source), '') is not null
        )
        and (
          type <> 'quran'
          or nullif(btrim(arabic_text), '') is not null
        )
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

create unique index content_items_parent_chapter_number_unique
  on public.content_items (parent_content_id, chapter_number)
  where parent_content_id is not null and chapter_number is not null;
create index content_items_parent_content_id_idx
  on public.content_items (parent_content_id);
create index content_items_quran_reference_idx
  on public.content_items (surah_number, ayah_number, ayah_end_number)
  where type = 'quran';
create index content_items_hadith_reference_idx
  on public.content_items (collection_name, book_name, hadith_number)
  where type = 'hadith';

create table public.content_reviews (
  id bigint generated always as identity primary key,
  content_item_id uuid not null references public.content_items (id) on delete restrict,
  reviewer_user_id uuid not null references auth.users (id) on delete restrict,
  decision text not null,
  notes text,
  created_at timestamptz not null default now(),
  constraint content_reviews_decision_valid check (
    decision in (
      'submitted', 'verified', 'rejected', 'published', 'unpublished', 'archived'
    )
  ),
  constraint content_reviews_notes_length check (
    notes is null or char_length(notes) <= 4000
  )
);

comment on table public.content_reviews is
  'Admin-only content lifecycle and canonical-source review history. Notes are never patient-readable.';

create index content_reviews_content_item_created_idx
  on public.content_reviews (content_item_id, created_at desc);
create index content_reviews_reviewer_idx
  on public.content_reviews (reviewer_user_id);

alter table public.content_reviews enable row level security;

create policy content_reviews_select_admin
on public.content_reviews for select to authenticated
using ((select private.is_super_admin()));

create policy content_reviews_insert_admin
on public.content_reviews for insert to authenticated
with check (
  (select private.is_super_admin())
  and reviewer_user_id = (select auth.uid())
);

revoke all on public.content_reviews from public, anon, authenticated;
grant select, insert on public.content_reviews to authenticated;
grant usage, select on sequence public.content_reviews_id_seq to authenticated;

create or replace function public.save_content_category(
  p_name text,
  p_slug text,
  p_category_id uuid default null,
  p_parent_id uuid default null,
  p_name_bn text default null,
  p_sort_order integer default 0,
  p_is_active boolean default true,
  p_request_id uuid default gen_random_uuid()
)
returns public.content_categories
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  saved_category public.content_categories;
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

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select aal.entity_id into existing_entity_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'content_category_saved'
    and aal.request_id = p_request_id;
  if existing_entity_id is not null then
    select cc.* into saved_category
    from public.content_categories cc where cc.id = existing_entity_id;
    if found then return saved_category; end if;
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Category name is required.' using errcode = '22023';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Category slug must use lowercase words and hyphens.'
      using errcode = '22023';
  end if;
  if p_sort_order < 0 then
    raise exception 'Sort order cannot be negative.' using errcode = '22023';
  end if;
  if p_parent_id is not null and not exists (
    select 1 from public.content_categories cc where cc.id = p_parent_id
  ) then
    raise exception 'Parent category was not found.' using errcode = 'P0002';
  end if;
  if p_category_id is not null and p_parent_id = p_category_id then
    raise exception 'A category cannot be its own parent.' using errcode = '22023';
  end if;
  if p_category_id is not null and p_parent_id is not null and exists (
    with recursive descendants as (
      select cc.id from public.content_categories cc
      where cc.parent_id = p_category_id
      union all
      select child.id from public.content_categories child
      join descendants d on child.parent_id = d.id
    )
    select 1 from descendants where id = p_parent_id
  ) then
    raise exception 'A category cannot be moved below one of its descendants.'
      using errcode = '22023';
  end if;

  if p_category_id is null then
    insert into public.content_categories (
      parent_id, name, name_bn, slug, sort_order, is_active, created_by, updated_by
    ) values (
      p_parent_id,
      btrim(p_name),
      nullif(btrim(p_name_bn), ''),
      p_slug,
      p_sort_order,
      p_is_active,
      caller_user_id,
      caller_user_id
    ) returning * into saved_category;
  else
    update public.content_categories
    set parent_id = p_parent_id,
        name = btrim(p_name),
        name_bn = nullif(btrim(p_name_bn), ''),
        slug = p_slug,
        sort_order = p_sort_order,
        is_active = p_is_active,
        updated_by = caller_user_id
    where id = p_category_id
    returning * into saved_category;
    if not found then
      raise exception 'Category was not found.' using errcode = 'P0002';
    end if;
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    caller_user_id,
    'content_category_saved',
    'content_category',
    saved_category.id,
    p_request_id,
    jsonb_build_object(
      'operation', case when p_category_id is null then 'created' else 'updated' end,
      'slug', saved_category.slug,
      'is_active', saved_category.is_active
    )
  );

  return saved_category;
end;
$$;

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
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  saved_item public.content_items;
  current_item public.content_items;
  existing_entity_id uuid;
  canonical boolean := p_type in ('quran', 'hadith');
  next_verification public.verification_status;
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
    select ci.* into saved_item
    from public.content_items ci where ci.id = existing_entity_id;
    if found then return saved_item; end if;
  end if;

  if p_status not in ('draft', 'review') then
    raise exception 'Content can only be saved as draft or submitted for review.'
      using errcode = '22023';
  end if;
  if p_title is null or btrim(p_title) = '' then
    raise exception 'Content title is required.' using errcode = '22023';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Content slug must use lowercase words and hyphens.'
      using errcode = '22023';
  end if;
  if p_category_id is not null and not exists (
    select 1 from public.content_categories cc
    where cc.id = p_category_id and cc.is_active
  ) then
    raise exception 'An active category was not found.' using errcode = 'P0002';
  end if;
  if p_parent_content_id is not null and not exists (
    select 1 from public.content_items ci
    where ci.id = p_parent_content_id and ci.type = 'book'
  ) then
    raise exception 'Book chapter parent must be an existing book.' using errcode = '22023';
  end if;
  if p_type = 'book_chapter' and (p_parent_content_id is null or p_chapter_number is null) then
    raise exception 'Book chapters require a parent book and chapter number.'
      using errcode = '22023';
  end if;
  if canonical and lower(coalesce(btrim(p_source_type), '')) = 'generative_ai' then
    raise exception 'Canonical Qur''an and Hadith content cannot use a generative AI source.'
      using errcode = '22023';
  end if;
  if p_type = 'quran' and (
    p_surah_number is null or p_surah_number not between 1 and 114
    or p_ayah_number is null or p_ayah_number <= 0
  ) then
    raise exception 'Qur''an content requires a valid Surah and Ayah reference.'
      using errcode = '22023';
  end if;
  if p_source_url is not null and p_source_url !~ '^https://' then
    raise exception 'Source URL must use HTTPS.' using errcode = '22023';
  end if;

  if p_content_item_id is not null then
    select ci.* into current_item
    from public.content_items ci
    where ci.id = p_content_item_id
    for update;
    if not found then
      raise exception 'Content item was not found.' using errcode = 'P0002';
    end if;
    if current_item.status in ('published', 'archived') then
      raise exception 'Published or archived content cannot be edited.' using errcode = '55000';
    end if;
  end if;

  next_verification := case when canonical then 'pending' else 'not_required' end;

  if p_content_item_id is null then
    insert into public.content_items (
      type, category_id, parent_content_id, title, title_bn, slug, summary, body,
      arabic_text, bangla_text, transliteration, translation, reference_text,
      source_type, source_reference, source_url, source_edition, translation_source,
      verification_status, surah_number, surah_name, surah_name_bn, ayah_number,
      ayah_end_number, collection_name, book_name, hadith_number, narrator, grade,
      author, publisher, chapter_number, language_code, rights_note, thumbnail_url,
      media_source_type, media_url, youtube_video_id, visibility, status,
      created_by, updated_by
    ) values (
      p_type, p_category_id, p_parent_content_id, btrim(p_title),
      nullif(btrim(p_title_bn), ''), p_slug, nullif(btrim(p_summary), ''),
      nullif(btrim(p_body), ''), nullif(btrim(p_arabic_text), ''),
      nullif(btrim(p_bangla_text), ''), nullif(btrim(p_transliteration), ''),
      nullif(btrim(p_translation), ''), nullif(btrim(p_reference_text), ''),
      nullif(btrim(p_source_type), ''), nullif(btrim(p_source_reference), ''),
      nullif(btrim(p_source_url), ''), nullif(btrim(p_source_edition), ''),
      nullif(btrim(p_translation_source), ''), next_verification,
      p_surah_number::smallint, nullif(btrim(p_surah_name), ''),
      nullif(btrim(p_surah_name_bn), ''), p_ayah_number, p_ayah_end_number,
      nullif(btrim(p_collection_name), ''), nullif(btrim(p_book_name), ''),
      nullif(btrim(p_hadith_number), ''), nullif(btrim(p_narrator), ''),
      nullif(btrim(p_grade), ''), nullif(btrim(p_author), ''),
      nullif(btrim(p_publisher), ''), p_chapter_number,
      nullif(btrim(p_language_code), ''), nullif(btrim(p_rights_note), ''),
      nullif(btrim(p_thumbnail_url), ''), p_media_source_type,
      nullif(btrim(p_media_url), ''), nullif(btrim(p_youtube_video_id), ''),
      p_visibility, p_status, caller_user_id, caller_user_id
    ) returning * into saved_item;
  else
    update public.content_items
    set type = p_type,
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
        verified_by = null,
        verified_at = null,
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
        published_at = null,
        archived_at = null,
        updated_by = caller_user_id
    where id = p_content_item_id
    returning * into saved_item;
  end if;

  if p_status = 'review' then
    insert into public.content_reviews (
      content_item_id, reviewer_user_id, decision
    ) values (saved_item.id, caller_user_id, 'submitted');
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    caller_user_id,
    'content_item_saved',
    'content_item',
    saved_item.id,
    p_request_id,
    jsonb_build_object(
      'operation', case when p_content_item_id is null then 'created' else 'updated' end,
      'type', saved_item.type,
      'status', saved_item.status,
      'visibility', saved_item.visibility,
      'canonical', canonical
    )
  );

  return saved_item;
end;
$$;

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
    raise exception 'Review notes must be 4000 characters or fewer.' using errcode = '22023';
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
    if canonical and (item.status <> 'verified' or item.verification_status <> 'verified') then
      raise exception 'Qur''an and Hadith must be verified before publication.'
        using errcode = '55000';
    end if;
    if not canonical and item.status <> 'review' then
      raise exception 'Non-canonical content must be reviewed before publication.'
        using errcode = '55000';
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
    set status = 'review', published_at = null, updated_by = caller_user_id
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
      'verification_status', item.verification_status
    )
  );

  return item;
end;
$$;

revoke all on function public.save_content_category(
  text, text, uuid, uuid, text, integer, boolean, uuid
) from public, anon, authenticated;
grant execute on function public.save_content_category(
  text, text, uuid, uuid, text, integer, boolean, uuid
) to authenticated;

revoke all on function public.save_content_item(
  public.content_type, text, text, public.resource_visibility, public.content_status,
  uuid, uuid, uuid, text, text, text, text, text, text, text, text, text, text,
  text, text, text, integer, text, text, integer, integer, text, text, text,
  text, text, text, text, integer, text, text, text, public.media_source_type,
  text, text, uuid
) from public, anon, authenticated;
grant execute on function public.save_content_item(
  public.content_type, text, text, public.resource_visibility, public.content_status,
  uuid, uuid, uuid, text, text, text, text, text, text, text, text, text, text,
  text, text, text, integer, text, text, integer, integer, text, text, text,
  text, text, text, text, integer, text, text, text, public.media_source_type,
  text, text, uuid
) to authenticated;

revoke all on function public.transition_content_item(uuid, text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.transition_content_item(uuid, text, text, uuid)
  to authenticated;
