-- Server-only claim/complete API for public announcement FCM topic dispatch.
-- Neither anon nor authenticated users may invoke these RPCs. Topic messages
-- contain a public notice ID; never patient information or private URLs.
create or replace function public.claim_universal_announcement_batch(
  p_batch_size integer default 10
)
returns table(job_id uuid, notice_id uuid, notice_title text)
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
      from candidates c
     where o.id = c.id
    returning o.id, o.announcement_id
  )
  select c.id, n.id, n.title
    from claimed c
    join public.universal_announcements n on n.id = c.announcement_id;
end;
$$;

create or replace function public.complete_universal_announcement_broadcast(
  p_job_id uuid,
  p_delivered_to_provider boolean,
  p_provider_message_id text default null
)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  completed_id uuid;
begin
  if p_job_id is null or p_delivered_to_provider is null then
    raise exception 'Incomplete broadcast response.' using errcode = '22023';
  end if;
  update private.universal_announcement_outbox o
     set status = case when p_delivered_to_provider then 'sent' else 'failed' end,
         sent_at = case when p_delivered_to_provider then now() else null end,
         provider_message_id = case when p_delivered_to_provider
             then left(p_provider_message_id, 512) else null end,
         error_code = case when p_delivered_to_provider
             then null else 'fcm_provider_rejected' end
   where o.id = p_job_id and o.status = 'sending'
  returning o.id into completed_id;
  return completed_id is not null;
end;
$$;

revoke all on function public.claim_universal_announcement_batch(integer)
  from public, anon, authenticated;
revoke all on function public.complete_universal_announcement_broadcast(
  uuid, boolean, text
) from public, anon, authenticated;

grant execute on function public.claim_universal_announcement_batch(integer)
  to service_role;
grant execute on function public.complete_universal_announcement_broadcast(
  uuid, boolean, text
) to service_role;

comment on function public.complete_universal_announcement_broadcast(
  uuid, boolean, text
) is 'Records FCM provider acceptance, not delivery to every subscriber.';
