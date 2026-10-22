-- Strict, durable cost guard for authenticated public-audio download gateway.
-- No patient content, tokens, IP addresses or media bytes are stored here.
-- This private schema is NOT exposed through PostgREST.
create schema if not exists media_gateway_private;
revoke all on schema media_gateway_private from public, anon, authenticated;

create table if not exists media_gateway_private.daily_download_budget (
  utc_day date not null,
  subject text not null,
  requests integer not null default 0 check (requests >= 0),
  reserved_bytes bigint not null default 0 check (reserved_bytes >= 0),
  primary key (utc_day, subject)
);
revoke all on media_gateway_private.daily_download_budget
from public, anon, authenticated;

create or replace function public.reserve_approved_audio_download(p_user_id uuid, p_bytes bigint)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  member_id uuid := p_user_id;
  current_day date := (now() at time zone 'utc')::date;
  member_subject text;
  member_requests integer;
  member_bytes bigint;
  total_bytes bigint;
begin
  -- Only the trusted Edge Function service role may reserve quotas.
  -- A member JWT alone must never be allowed to burn the global budget.
  if member_id is null or p_bytes is null or
     p_bytes < 4 or p_bytes > 104857600 then
    return false;
  end if;

  member_subject := 'member:' || member_id::text;
  -- Single stable transaction lock makes member and global reservations atomic.
  perform pg_catalog.pg_advisory_xact_lock(727366414211::bigint);
  insert into media_gateway_private.daily_download_budget(utc_day, subject)
    values (current_day, member_subject), (current_day, '$global')
    on conflict do nothing;

  select requests, reserved_bytes
    into member_requests, member_bytes
    from media_gateway_private.daily_download_budget
    where utc_day = current_day and subject = member_subject
    for update;

  select reserved_bytes
    into total_bytes
    from media_gateway_private.daily_download_budget
    where utc_day = current_day and subject = '$global'
    for update;

  -- Initial maximum: 3 files / 200 MiB per member, 2 GiB globally, per UTC day.
  -- Fail closed, including concurrent requests. Charge reservation even if
  -- caller cancels the stream; this stops retry-abuse increasing egress.
  if member_requests >= 3 or
     member_bytes + p_bytes > 209715200 or
     total_bytes + p_bytes > 2147483648 then
    return false;
  end if;

  update media_gateway_private.daily_download_budget
    set requests = requests + 1, reserved_bytes = reserved_bytes + p_bytes
    where utc_day = current_day and subject = member_subject;
  update media_gateway_private.daily_download_budget
    set requests = requests + 1, reserved_bytes = reserved_bytes + p_bytes
    where utc_day = current_day and subject = '$global';
  return true;
end
$function$;

revoke all on function public.reserve_approved_audio_download(uuid, bigint)
  from public, anon, authenticated;
grant execute on function public.reserve_approved_audio_download(uuid, bigint)
  to service_role;
comment on function public.reserve_approved_audio_download(uuid, bigint) is
  'Authenticated owner-scoped approved audio reservation. Enforces per-member and global server-egress ceilings; no clinical data.';
