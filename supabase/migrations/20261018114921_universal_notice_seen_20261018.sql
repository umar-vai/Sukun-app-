-- Durable per-account popup acknowledgement for public universal notices.
-- Guest viewers use per-installation local storage; authenticated viewers use
-- these private receipts, so they do not see a publication twice across devices.
-- This is independent from private patient reminders and notification_events.

create table public.universal_notice_seen (
  user_id uuid not null default auth.uid() references auth.users(id)
    on delete cascade,
  announcement_id uuid not null
    references public.universal_announcements(id) on delete cascade,
  published_at timestamptz not null,
  seen_at timestamptz not null default now(),
  primary key (user_id, announcement_id, published_at)
);

create index universal_notice_seen_user_recent_idx
  on public.universal_notice_seen (user_id, seen_at desc);

alter table public.universal_notice_seen enable row level security;
revoke all on public.universal_notice_seen from public, anon, authenticated;
grant select, insert on public.universal_notice_seen to authenticated;

create policy universal_notice_seen_read_own on public.universal_notice_seen
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy universal_notice_seen_insert_own_public_notice
  on public.universal_notice_seen
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.universal_announcements a
      where a.id = announcement_id
        and a.status = 'published'
        and a.published_at = universal_notice_seen.published_at
        and a.published_at <= now()
        and (a.expires_at is null or a.expires_at > now())
    )
  );

comment on table public.universal_notice_seen is
  'Owner-private public announcement popup acknowledgement; no patient or clinical details. Each re-publication has a new published_at key.';
