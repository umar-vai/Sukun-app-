-- Run ONLY against an isolated, disposable local Supabase test database,
-- after applying docs/security/patient_sign_in_rate_limit_staging.sql.
-- Uses synthetic keys, never patient identifiers or private information.
begin;

do $test$
declare
  trial integer;
  result boolean;
begin
  if has_function_privilege('anon', 'public.check_patient_login_rate_limit(text,text)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.check_patient_login_rate_limit(text,text)', 'EXECUTE') then
    raise exception 'SECURITY: non-service roles can invoke the rate limiter';
  end if;
  if not has_function_privilege('service_role', 'public.check_patient_login_rate_limit(text,text)', 'EXECUTE') then
    raise exception 'SECURITY: service role cannot invoke limiter';
  end if;

  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.check_patient_login_rate_limit(repeat('a', 64), repeat('b', 64));
    raise exception 'SECURITY: authenticated caller passed server role guard';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('request.jwt.claim.role', 'service_role', true);

  -- Eight attempts for the same identity; the ninth must be blocked.
  for trial in 1..8 loop
    select public.check_patient_login_rate_limit(
      repeat('a', 64), repeat('b', 64)
    ) into result;
    if result is distinct from true then
      raise exception 'Identity allowed attempt % was unexpectedly blocked', trial;
    end if;
  end loop;

  select public.check_patient_login_rate_limit(
    repeat('a', 64), repeat('b', 64)
  ) into result;
  if result is distinct from false then
    raise exception 'Identity ninth attempt was not blocked';
  end if;

  -- Unique identity per attempt tests the independent 30-request IP threshold.
  for trial in 1..30 loop
    select public.check_patient_login_rate_limit(
      repeat('c', 64), lpad(to_hex(trial), 64, '0')
    ) into result;
    if result is distinct from true then
      raise exception 'IP allowed attempt % was unexpectedly blocked', trial;
    end if;
  end loop;
  select public.check_patient_login_rate_limit(
    repeat('c', 64), repeat('d', 64)
  ) into result;
  if result is distinct from false then
    raise exception 'IP 31st attempt was not blocked';
  end if;

  -- Reject non-hex key material before any state change.
  begin
    perform public.check_patient_login_rate_limit('not-a-hash', repeat('f', 64));
    raise exception 'SECURITY: invalid digest was accepted';
  exception when invalid_parameter_value then
    null;
  end;
end
$test$;

rollback;
