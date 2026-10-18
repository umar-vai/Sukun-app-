-- Public Sukun Life announcements are deliberately separate from private
-- patient notification_events and medical/care-plan records.
-- This migration is source-only until the Supabase deployment gate passes.

create table public.universal_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  body text not null check (char_length(btrim(body)) between 1 and 5000),
  image_path text,
  link_url text,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'archived')),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  expires_at timestamptz,
  constraint announcement_image_path_valid check (
    image_path is null or
    (char_length(image_path) between 5 and 240 and
     image_path ~ '^[a-zA-Z0-9_/-]+\.(png|jpg|jpeg|webp)$' and
     image_path !~ '(^/|//|[.][.])')
  ),
  constraint announcement_https_link_only check (
    link_url is null or
    (char_length(link_url) <= 1500 and link_url ~* '^https://[^[:space:]]+$')
  ),
  constraint announcement_dates_valid check (
    expires_at is null or expires_at > created_at
  )
);

create index universal_announcements_feed_idx
  on public.universal_announcements (published_at desc, id)
  where status = 'published';

create or replace function private.stamp_universal_announcement()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.created_by := auth.uid();
    end if;
    if new.status = 'published' then
      new.published_at := now();
    else
      new.published_at := null;
    end if;
  elsif new.created_by is distinct from old.created_by then
    raise exception 'Announcement creator cannot be changed.'
      using errcode = '23514';
  elsif new.status = 'published' and old.status is distinct from 'published' then
    new.published_at := now();
  elsif new.status <> 'published' then
    new.published_at := null;
  else
    new.published_at := old.published_at;
  end if;
  return new;
end;
$$;

create trigger stamp_universal_announcement_trigger
before insert or update on public.universal_announcements
for each row execute function private.stamp_universal_announcement();

alter table public.universal_announcements enable row level security;
revoke all on public.universal_announcements from public, anon, authenticated;
grant select on public.universal_announcements to anon, authenticated;
grant insert, update on public.universal_announcements to authenticated;

create policy announcements_published_read on public.universal_announcements
  for select to anon, authenticated
  using (
    status = 'published'
    and published_at <= now()
    and (expires_at is null or expires_at > now())
  );

create policy announcements_admin_read on public.universal_announcements
  for select to authenticated using ((select private.is_super_admin()));

create policy announcements_admin_insert on public.universal_announcements
  for insert to authenticated with check ((select private.is_super_admin()));

create policy announcements_admin_update on public.universal_announcements
  for update to authenticated using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));


-- Retain notice history. Admins archive a notice instead of deleting it.
create or replace function private.audit_universal_announcement()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, metadata
  ) values (
    auth.uid(),
    case
      when tg_op = 'INSERT' then 'universal_announcement_created'
      when new.status = 'published' and old.status <> 'published'
        then 'universal_announcement_published'
      when new.status = 'archived' and old.status <> 'archived'
        then 'universal_announcement_archived'
      else 'universal_announcement_updated'
    end,
    'universal_announcement', new.id,
    jsonb_build_object('status', new.status)
  );
  return new;
end;
$$;

create trigger audit_universal_announcement_trigger
after insert or update on public.universal_announcements
for each row execute function private.audit_universal_announcement();

-- Public assets only, with strict admin upload rights. NEVER store patient
-- photographs, prescriptions, contact details or confidential media here.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'sukun-announcement-images', 'sukun-announcement-images',
  true, 3145728, array['image/png','image/jpeg','image/webp']
)
on conflict (id) do nothing;

create policy sukun_announcement_image_admin_upload on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'sukun-announcement-images'
    and (select private.is_super_admin())
    and (storage.extension(name) = any(array['png','jpg','jpeg','webp']))
  );

create policy sukun_announcement_image_admin_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'sukun-announcement-images'
    and (select private.is_super_admin())
  );

-- A protected private-schema dispatch record is queued once per publication.
-- It is NOT a claim of FCM delivery. Only a separately reviewed server-side
-- sender can transition this state after a verified provider response.
create table private.universal_announcement_outbox (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.universal_announcements(id),
  published_at timestamptz not null,
  status text not null default 'pending'
    check (status in ('pending','sending','sent','failed','cancelled')),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  provider_message_id text,
  error_code text,
  unique (announcement_id, published_at)
);

alter table private.universal_announcement_outbox enable row level security;
revoke all on private.universal_announcement_outbox from public, anon, authenticated;

create or replace function private.enqueue_universal_announcement()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  new_publication boolean := false;
begin
  if tg_op = 'INSERT' then
    new_publication := new.status = 'published';
  elsif tg_op = 'UPDATE' then
    new_publication := new.status = 'published'
      and old.status is distinct from 'published';
    if old.status = 'published' and new.status <> 'published' then
      update private.universal_announcement_outbox o
         set status = 'cancelled'
       where o.announcement_id = new.id
         and o.status = 'pending';
    end if;
  end if;
  if new_publication and new.published_at is not null then
    insert into private.universal_announcement_outbox (
      announcement_id, published_at
    ) values (new.id, new.published_at) on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger enqueue_universal_announcement_trigger
after insert or update of status on public.universal_announcements
for each row execute function private.enqueue_universal_announcement();

revoke execute on function private.stamp_universal_announcement()
  from public, anon, authenticated;
revoke execute on function private.enqueue_universal_announcement()
  from public, anon, authenticated;
revoke execute on function private.audit_universal_announcement()
  from public, anon, authenticated;

comment on table public.universal_announcements is
  'Public, non-clinical broadcast announcements. Drafts are visible only to verified super admins.';
comment on table private.universal_announcement_outbox is
  'Server-only broadcast dispatch queue; pending does not imply Firebase delivery.';
