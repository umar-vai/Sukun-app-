-- Dedicated Phase 5 browsing structure. Collections reference canonical content
-- items; Qur'an text is never copied into a collection row.

create type public.content_collection_type as enum (
  'selected_ayat',
  'ruqyah_ayat'
);

create table public.content_collections (
  id uuid primary key default gen_random_uuid(),
  type public.content_collection_type not null,
  title text not null,
  title_bn text,
  slug text not null,
  summary text,
  visibility public.resource_visibility not null default 'public',
  status public.content_status not null default 'draft',
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_by uuid not null references auth.users (id) on delete restrict,
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint content_collections_title_not_blank check (btrim(title) <> ''),
  constraint content_collections_slug_format check (
    slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  constraint content_collections_summary_length check (
    summary is null or char_length(summary) <= 1000
  ),
  constraint content_collections_supported_status check (
    status in ('draft', 'published', 'archived')
  ),
  constraint content_collections_publish_consistency check (
    (status = 'published' and published_at is not null and archived_at is null)
    or (status = 'archived' and archived_at is not null)
    or (status = 'draft' and archived_at is null)
  )
);

create unique index content_collections_slug_lower_key
  on public.content_collections (lower(slug));
create index content_collections_browse_idx
  on public.content_collections (type, status, visibility, title);

create table public.content_collection_items (
  collection_id uuid not null
    references public.content_collections (id) on delete restrict,
  content_item_id uuid not null
    references public.content_items (id) on delete restrict,
  sort_order integer not null default 0,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (collection_id, content_item_id),
  constraint content_collection_items_sort_nonnegative check (sort_order >= 0)
);

create index content_collection_items_order_idx
  on public.content_collection_items (collection_id, sort_order, content_item_id);
create index content_collection_items_content_idx
  on public.content_collection_items (content_item_id);

create or replace function private.can_read_content_collection(
  target_collection_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.content_collections cc
      where cc.id = target_collection_id
        and cc.status = 'published'
        and (
          cc.visibility = 'public'
          or (
            cc.visibility = 'patient_only'
            and (select private.current_patient_id()) is not null
          )
        )
    );
$$;

revoke execute on function private.can_read_content_collection(uuid)
  from public, anon, authenticated;
grant execute on function private.can_read_content_collection(uuid)
  to anon, authenticated;

alter table public.content_collections enable row level security;
alter table public.content_collection_items enable row level security;

create policy content_collections_select_anon
on public.content_collections for select to anon
using ((select private.can_read_content_collection(id)));

create policy content_collections_select_authenticated
on public.content_collections for select to authenticated
using ((select private.can_read_content_collection(id)));

create policy content_collections_insert_admin
on public.content_collections for insert to authenticated
with check ((select private.is_super_admin()));

create policy content_collections_update_admin
on public.content_collections for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy content_collection_items_select_anon
on public.content_collection_items for select to anon
using (
  (select private.can_read_content_collection(collection_id))
  and (select private.can_read_content_item(content_item_id))
);

create policy content_collection_items_select_authenticated
on public.content_collection_items for select to authenticated
using (
  (select private.can_read_content_collection(collection_id))
  and (select private.can_read_content_item(content_item_id))
);

create policy content_collection_items_insert_admin
on public.content_collection_items for insert to authenticated
with check ((select private.is_super_admin()));

create policy content_collection_items_update_admin
on public.content_collection_items for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy content_collection_items_delete_admin
on public.content_collection_items for delete to authenticated
using ((select private.is_super_admin()));

revoke all on table public.content_collections from public, anon, authenticated;
revoke all on table public.content_collection_items from public, anon, authenticated;
grant select on table public.content_collections to anon, authenticated;
grant select on table public.content_collection_items to anon, authenticated;
grant insert, update on table public.content_collections to authenticated;
grant insert, update, delete on table public.content_collection_items
  to authenticated;

create or replace function public.install_standard_resource_taxonomy(
  p_request_id uuid default gen_random_uuid()
)
returns setof public.content_categories
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  root_record record;
  taxonomy_root_id uuid;
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
  if exists (
    select 1 from public.admin_audit_logs aal
    where aal.actor_user_id = caller_user_id
      and aal.action = 'standard_resource_taxonomy_installed'
      and aal.request_id = p_request_id
  ) then
    return query
      select cc.* from public.content_categories cc
      where cc.slug in ('dua-azkar', 'ruqyah')
         or cc.slug like 'dua-azkar-%'
         or cc.slug like 'ruqyah-%'
      order by cc.sort_order, cc.name;
    return;
  end if;

  for root_record in
    select * from (values
      ('dua-azkar', 'Dua & Azkar', 'দুআ ও আযকার', 100),
      ('ruqyah', 'Ruqyah', 'রুকইয়াহ', 200)
    ) as roots(slug, name, name_bn, sort_order)
  loop
    insert into public.content_categories (
      name, name_bn, slug, sort_order, is_active, created_by, updated_by
    ) values (
      root_record.name, root_record.name_bn, root_record.slug,
      root_record.sort_order, true, caller_user_id, caller_user_id
    ) on conflict (slug) do nothing;
  end loop;

  select id into taxonomy_root_id
  from public.content_categories where slug = 'dua-azkar';
  insert into public.content_categories (
    parent_id, name, name_bn, slug, sort_order, is_active, created_by, updated_by
  )
  select taxonomy_root_id, child.name, child.name_bn, child.slug,
         child.sort_order, true, caller_user_id, caller_user_id
  from (values
    ('Morning Azkar', 'সকালের আযকার', 'dua-azkar-morning', 101),
    ('Evening Azkar', 'সন্ধ্যার আযকার', 'dua-azkar-evening', 102),
    ('Masnun Dua', 'মাসনূন দুআ', 'dua-azkar-masnun', 103),
    ('Sleep', 'ঘুম', 'dua-azkar-sleep', 104),
    ('Travel', 'সফর', 'dua-azkar-travel', 105),
    ('Protection', 'সুরক্ষা', 'dua-azkar-protection', 106),
    ('Distress', 'দুশ্চিন্তা ও কষ্ট', 'dua-azkar-distress', 107)
  ) as child(name, name_bn, slug, sort_order)
  on conflict (slug) do nothing;

  select id into taxonomy_root_id
  from public.content_categories where slug = 'ruqyah';
  insert into public.content_categories (
    parent_id, name, name_bn, slug, sort_order, is_active, created_by, updated_by
  )
  select taxonomy_root_id, child.name, child.name_bn, child.slug,
         child.sort_order, true, caller_user_id, caller_user_id
  from (values
    ('Ruqyah Ayat', 'রুকইয়াহ আয়াত', 'ruqyah-ayat', 201),
    ('Ruqyah Audio', 'রুকইয়াহ অডিও', 'ruqyah-audio', 202),
    ('Self-Ruqyah Guide', 'সেলফ-রুকইয়াহ গাইড', 'ruqyah-self-guide', 203),
    ('Protection', 'সুরক্ষা', 'ruqyah-protection', 204),
    ('Evil Eye', 'বদনজর', 'ruqyah-evil-eye', 205),
    ('Jinn', 'জিন', 'ruqyah-jinn', 206),
    ('Sihr', 'সিহর', 'ruqyah-sihr', 207),
    ('Wellness', 'সুস্থতা', 'ruqyah-wellness', 208)
  ) as child(name, name_bn, slug, sort_order)
  on conflict (slug) do nothing;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, request_id, metadata
  ) values (
    caller_user_id, 'standard_resource_taxonomy_installed',
    'content_category', p_request_id,
    jsonb_build_object('taxonomy_version', 1)
  );

  return query
    select cc.* from public.content_categories cc
    where cc.slug in ('dua-azkar', 'ruqyah')
       or cc.slug like 'dua-azkar-%'
       or cc.slug like 'ruqyah-%'
    order by cc.sort_order, cc.name;
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
    raise exception 'Collection slug must use lowercase words and hyphens.'
      using errcode = '22023';
  end if;
  if p_visibility not in ('public', 'patient_only') then
    raise exception 'Collections support public or patient-only visibility.'
      using errcode = '22023';
  end if;
  if cardinality(p_content_item_ids) is null or cardinality(p_content_item_ids) = 0 then
    raise exception 'Select at least one verified Qur''an Ayah.' using errcode = '22023';
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
    where ci.id is null
       or ci.type <> 'quran'
       or ci.verification_status <> 'verified'
       or ci.status not in ('verified', 'published')
  ) then
    raise exception 'Collections may only reference verified canonical Qur''an Ayat.'
      using errcode = '22023';
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
    delete from public.content_collection_items
    where collection_id = saved_collection.id;
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
      where cci.collection_id = p_collection_id
        and (ci.status <> 'published' or ci.verification_status <> 'verified')
    ) then
      raise exception 'Publish every verified Ayah before publishing its collection.'
        using errcode = '55000';
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
    set status = 'archived', archived_at = now(),
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

revoke all on function public.install_standard_resource_taxonomy(uuid)
  from public, anon, authenticated;
revoke all on function public.save_content_collection(
  public.content_collection_type, text, text, uuid[], uuid, text, text,
  public.resource_visibility, uuid
) from public, anon, authenticated;
revoke all on function public.transition_content_collection(uuid, text, uuid)
  from public, anon, authenticated;

grant execute on function public.install_standard_resource_taxonomy(uuid)
  to authenticated;
grant execute on function public.save_content_collection(
  public.content_collection_type, text, text, uuid[], uuid, text, text,
  public.resource_visibility, uuid
) to authenticated;
grant execute on function public.transition_content_collection(uuid, text, uuid)
  to authenticated;
