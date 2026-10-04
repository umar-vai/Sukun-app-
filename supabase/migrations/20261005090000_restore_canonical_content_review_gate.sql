-- Restore the reviewed publication lifecycle requested for the simplified CMS.
-- This is a forward-only change: historical direct-publish migrations and
-- lifecycle records remain intact.

with returned_to_review as (
  update public.content_items
  set status = 'review',
      published_at = null,
      updated_at = now()
  where type in ('quran', 'hadith')
    and status = 'published'
    and verification_status <> 'verified'
  returning id, type, verification_status
)
insert into public.admin_audit_logs (
  actor_user_id, action, entity_type, entity_id, request_id, metadata
)
select
  null,
  'content_item_policy_returned_to_review',
  'content_item',
  id,
  gen_random_uuid(),
  jsonb_build_object(
    'type', type,
    'previous_status', 'published',
    'new_status', 'review',
    'verification_status', verification_status,
    'reason', 'canonical_source_verification_required',
    'actor_kind', 'system_migration'
  )
from returned_to_review;

alter table public.content_items
  drop constraint content_items_canonical_publication;

alter table public.content_items
  add constraint content_items_canonical_publication
    check (
      status <> 'published'
      or type not in ('quran', 'hadith')
      or (
        verification_status = 'verified'
        and verified_by is not null
        and verified_at is not null
        and nullif(btrim(source_type), '') is not null
        and lower(btrim(source_type)) <> 'generative_ai'
        and nullif(btrim(source_reference), '') is not null
      )
    );

comment on table public.content_reviews is
  'Admin-only review, verification, publication, and archive history for content resources.';

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
      raise exception 'Only Qur''an or Hadith content awaiting review can be verified.'
        using errcode = '55000';
    end if;
    if nullif(btrim(item.source_reference), '') is null
      or nullif(btrim(item.source_type), '') is null
      or lower(btrim(item.source_type)) = 'generative_ai'
      or nullif(btrim(item.source_edition), '') is null then
      raise exception 'Source verification requires an approved source name and edition or version.'
        using errcode = '22023';
    end if;
    if item.bangla_text is not null
      and nullif(btrim(item.translation_source), '') is null then
      raise exception 'Bangla canonical text requires its approved translation source.'
        using errcode = '22023';
    end if;
    if item.type = 'quran' and nullif(btrim(item.arabic_text), '') is null then
      raise exception 'Qur''an source verification requires sourced Arabic text.'
        using errcode = '22023';
    end if;
    if item.type = 'hadith' and (
      nullif(btrim(item.collection_name), '') is null
      or nullif(btrim(item.book_name), '') is null
      or nullif(btrim(item.hadith_number), '') is null
    ) then
      raise exception 'Hadith source verification requires collection, book, and Hadith number.'
        using errcode = '22023';
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
    if canonical and (
      item.status <> 'verified'
      or item.verification_status <> 'verified'
      or item.verified_by is null
      or item.verified_at is null
    ) then
      raise exception 'Qur''an and Hadith must pass source verification before publishing.'
        using errcode = '55000';
    end if;
    if not canonical and item.status <> 'review' then
      raise exception 'This resource must be submitted for review before publishing.'
        using errcode = '55000';
    end if;
    update public.content_items
    set status = 'published',
        published_at = now(),
        archived_at = null,
        updated_by = caller_user_id
    where id = item.id returning * into item;
  elsif p_transition = 'unpublish' then
    if item.status <> 'published' then
      raise exception 'Only published content can be unpublished.' using errcode = '55000';
    end if;
    update public.content_items
    set status = case when canonical then 'verified' else 'review' end,
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
      'review_gate_enforced', true
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
  'Audited Super Admin content lifecycle. Canonical Qur''an/Hadith require source verification before publication.';
