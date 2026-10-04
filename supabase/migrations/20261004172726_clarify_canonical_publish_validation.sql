-- Replace opaque check-constraint failures with stable, actionable publication
-- validation while preserving the existing constraints as defence in depth.

create or replace function private.enforce_content_item_publication_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.status <> 'published' then
    return new;
  end if;

  if new.type in ('quran', 'hadith') then
    if nullif(btrim(new.source_type), '') is null then
      raise exception 'Publishing Qur''an or Hadith requires an approved source type.'
        using errcode = '22023';
    end if;
    if lower(btrim(new.source_type)) = 'generative_ai' then
      raise exception 'Canonical Qur''an and Hadith content cannot use a generative AI source.'
        using errcode = '22023';
    end if;
    if nullif(btrim(new.source_reference), '') is null then
      raise exception 'Publishing Qur''an or Hadith requires a source reference.'
        using errcode = '22023';
    end if;
    if nullif(btrim(new.source_edition), '') is null then
      raise exception 'Publishing Qur''an or Hadith requires an edition or dataset version.'
        using errcode = '22023';
    end if;
    if new.bangla_text is not null
      and nullif(btrim(new.translation_source), '') is null then
      raise exception 'Publishing Bangla canonical text requires its translation source.'
        using errcode = '22023';
    end if;
    if new.type = 'quran'
      and nullif(btrim(new.arabic_text), '') is null then
      raise exception 'Publishing a Qur''an resource requires sourced Arabic text. Use the Audio content type for a recitation-only resource.'
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

  if new.media_source_type is not null
    and nullif(btrim(new.rights_note), '') is null then
    raise exception 'Publishing external media requires a rights or licensing note.'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_content_item_publication_integrity()
  from public, anon, authenticated;

drop trigger if exists enforce_content_item_publication_integrity
  on public.content_items;

create trigger enforce_content_item_publication_integrity
before insert or update on public.content_items
for each row
execute function private.enforce_content_item_publication_integrity();

comment on function private.enforce_content_item_publication_integrity() is
  'Provides actionable source and rights validation before content publication; direct publishing remains authorized by transition_content_item.';
