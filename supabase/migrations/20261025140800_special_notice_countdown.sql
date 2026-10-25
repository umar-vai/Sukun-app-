-- Optional public countdown for existing universal announcements. No patient
-- notification tables or private care-plan messages are changed.
alter table public.universal_announcements
  add column if not exists countdown_ends_at timestamptz;

alter table public.universal_announcements
  add constraint universal_notice_countdown_after_creation
  check (countdown_ends_at is null or countdown_ends_at > created_at);

-- A countdown does not schedule or re-send a notice. It is visible only
-- for publicly published notices already governed by their existing RLS.
create or replace function private.validate_universal_notice_countdown()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  if new.status = 'published' and new.countdown_ends_at is not null
     and (tg_op = 'INSERT' or old.status is distinct from 'published'
       or new.countdown_ends_at is distinct from old.countdown_ends_at) then
    if new.countdown_ends_at <= now()
       or new.countdown_ends_at > now() + interval '30 days' then
      raise exception 'Countdown must end within the next 30 days.'
      using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
create trigger validate_universal_notice_countdown_before_write
before insert or update on public.universal_announcements
for each row execute function private.validate_universal_notice_countdown();
revoke execute on function private.validate_universal_notice_countdown()
  from public, anon, authenticated;

-- New RPC preserves old claim() signature while adding only public artwork and
-- deadline fields. The cron-only sender moves to this after safe deployment.
create function public.claim_universal_announcement_rich_batch(
  p_batch_size integer default 10
)
returns table(
  job_id uuid, notice_id uuid, notice_title text,
  notice_image_path text, countdown_ends_at timestamptz
)
language plpgsql security definer set search_path = ''
as $$
begin
  if p_batch_size is null or p_batch_size < 1 or p_batch_size > 20 then
    raise exception 'Invalid broadcast batch size.' using errcode = '22023';
  end if;
  return query
  with candidates as (
    select o.id
    from private.universal_announcement_outbox o
    join public.universal_announcements n on n.id = o.announcement_id
    where o.status = 'pending'
      and n.status = 'published'
      and n.published_at = o.published_at
      and n.published_at <= now()
      and (n.expires_at is null or n.expires_at > now())
    order by o.created_at, o.id
    for update of o skip locked
    limit p_batch_size
  ), claimed as (
    update private.universal_announcement_outbox o
       set status = 'sending'
      from candidates c where o.id = c.id
    returning o.id, o.announcement_id
  )
  select c.id, n.id, n.title, n.image_path, n.countdown_ends_at
  from claimed c
  join public.universal_announcements n on n.id = c.announcement_id;
end;
$$;
revoke all on function public.claim_universal_announcement_rich_batch(integer)
 from public, anon, authenticated;
grant execute on function public.claim_universal_announcement_rich_batch(integer)
 to service_role;
comment on function public.claim_universal_announcement_rich_batch(integer) is
 'Server cron-only public notice claims including public image path and countdown deadline.';
