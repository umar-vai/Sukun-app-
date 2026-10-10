-- Staging-tested Patient sign-in limiter; never bypass or disable throttling.
-- PostgREST now supplies the signed JWT role in request.jwt.claims; the
-- legacy request.jwt.claim.role GUC may be absent. The old check caused
-- "Server role required" (42501) for legitimate server-side sign-ins.
-- Keep BOTH the signed service_role claim check and RPC execute ACL.
create schema if not exists private;

create table if not exists private.patient_login_attempts (
  bucket_key text primary key check (length(bucket_key) = 64),
  window_start timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  updated_at timestamptz not null default now()
);
revoke all on private.patient_login_attempts from public, anon, authenticated;

create or replace function public.check_patient_login_rate_limit(
  p_ip_hash text, p_identity_hash text
) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  permitted boolean;
  current_key text;
  current_count integer;
  threshold integer;
begin
  -- Only an API-validated service_role JWT may invoke this RPC.
  -- auth.jwt() reads the signed request.jwt.claims representation, which is
  -- the current PostgREST context. Legacy claim fallback supports older
  -- PostgREST installations only when the JSON claim has no role.
  if coalesce(
      nullif(auth.jwt() ->> 'role', ''),
      nullif(current_setting('request.jwt.claim.role', true), ''),
      ''
    ) <> 'service_role' then
    raise exception 'Server role required' using errcode = '42501';
  end if;

  if p_ip_hash !~ '^[0-9a-f]{64}$'
    or p_identity_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid rate-limit key' using errcode = '22023';
  end if;

  permitted := true;
  for current_key, threshold in
    select 'i:' || p_ip_hash, 30
    union all select 'u:' || p_identity_hash, 8
    order by 1
  loop
    insert into private.patient_login_attempts as a
      (bucket_key, window_start, attempts, updated_at)
    values (substr(current_key, 3), now(), 1, now())
    on conflict (bucket_key) do update
      set attempts = case
        when a.window_start <= now() - interval '15 minutes' then 1
        else a.attempts + 1 end,
        window_start = case
        when a.window_start <= now() - interval '15 minutes' then now()
        else a.window_start end,
        updated_at = now()
    returning attempts into current_count;
    if current_count > threshold then permitted := false; end if;
  end loop;
  return permitted;
end;
$$;

revoke all on function public.check_patient_login_rate_limit(text,text)
  from public, anon, authenticated;
grant execute on function public.check_patient_login_rate_limit(text,text)
  to service_role;
