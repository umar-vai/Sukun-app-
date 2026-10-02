-- A published external media resource must record the licensing/permission
-- basis that allows Sukun Life to link to and present it.
alter table public.content_items
  add constraint content_items_published_media_rights
  check (
    status <> 'published'
    or media_source_type is null
    or nullif(btrim(rights_note), '') is not null
  ) not valid;

alter table public.content_items
  validate constraint content_items_published_media_rights;
