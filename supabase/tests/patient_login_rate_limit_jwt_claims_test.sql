begin;

-- Fully synthetic rollback-only regression in disposable local Supabase.
create extension if not exists pgtap with schema extensions;
select plan(8);

select ok(
  not has_function_privilege('anon',
    'public.check_patient_login_rate_limit(text,text)', 'EXECUTE'),
  'Anonymous clients cannot execute persistent login limiter'
);
select ok(
  not has_function_privilege('authenticated',
    'public.check_patient_login_rate_limit(text,text)', 'EXECUTE'),
  'Ordinary authenticated clients cannot execute server-only limiter'
);
select ok(
  has_function_privilege('service_role',
    'public.check_patient_login_rate_limit(text,text)', 'EXECUTE'),
  'Service-role client retains RPC execute permission'
);
select ok(
  not has_table_privilege('authenticated',
    'private.patient_login_attempts', 'SELECT'),
  'Persistent hashed attempt records remain private'
);

-- An authenticated JWT MUST take precedence over legacy settings; a
-- legacy service_role value cannot override the current signed claim.
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$select public.check_patient_login_rate_limit(repeat('a',64),repeat('b',64))$$,
  '42501',
  'Server role required',
  'Signed authenticated claim cannot impersonate server role'
);

-- Current PostgREST only sets request.jwt.claims. Correct, signed service
-- JWT grants server-only access without the legacy role setting.
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select lives_ok(
  $$select public.check_patient_login_rate_limit(repeat('a',64),repeat('b',64))$$,
  'Signed service role can use limiter when legacy role GUC is absent'
);
do $test$
begin
  for i in 1..7 loop
    perform public.check_patient_login_rate_limit(repeat('a',64),repeat('b',64));
  end loop;
end
$test$;
select is(
  public.check_patient_login_rate_limit(repeat('a',64),repeat('b',64)),
  false,
  'Ninth identity attempt is blocked by persistent limit'
);
select throws_ok(
  $$select public.check_patient_login_rate_limit('not-a-hash',repeat('f',64))$$,
  '22023',
  'Invalid rate-limit key',
  'Unhashed input is rejected by the server function'
);

select * from finish();
rollback;
