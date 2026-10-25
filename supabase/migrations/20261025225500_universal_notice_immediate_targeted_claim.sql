-- Permit an authenticated Admin Publish event to dispatch only its own
-- newly queued public notice. Service-role only, never a client-side RPC.
-- Existing cron batch claim/complete functions remain unchanged.
create function public.claim_universal_announcement_rich_one(
  p_notice_id uuid
)
returns table(
  job_id uuid,
  notice_id uuid,
  notice_title text,
  notice_image_path text,
  countdown_ends_at timestamptz
)
language plpgsql security definer set search_path = ''
as $$
begin
  if p_notice_id is null then
    raise exception 'Notice ID is required.' using errcode = '22023';
  end if;
  return query
    with candidates as (
      select o.id
      from private.universal_announcement_outbox o
      join public.universal_announcements n on n.id = o.announcement_id
      where o.announcement_id = p_notice_id
        and o.status = 'pending'
        and n.status = 'published'
        and n.published_at = o.published_at
        and n.published_at <= now()
        and (n.expires_at is null or n.expires_at > now())
      order by o.created_at, o.id
      for update of o skip locked
      limit 1
    ), claimed as (
      update private.universal_announcement_outbox o
      set status = 'sending'
      from candidates c
      where o.id = c.id
      returning o.id, o.announcement_id
    )
    select c.id, n.id, n.title, n.image_path, n.countdown_ends_at
    from claimed c
    join public.universal_announcements n on n.id = c.announcement_id;
end;
$$;

revoke all on function public.claim_universal_announcement_rich_one(uuid)
from public, anon, authenticated;
grant execute on function public.claim_universal_announcement_rich_one(uuid)
to service_role;
comment on function public.claim_universal_announcement_rich_one(uuid) is
  'Server-only and idempotent claim of one approved public notice after Admin Publish.';
