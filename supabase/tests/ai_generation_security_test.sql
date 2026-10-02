begin;

create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.ai_generation_requests'::regclass),
  'AI request idempotency table has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.ai_provider_slot_health'::regclass),
  'AI slot health table has RLS enabled'
);
select ok(
  not has_table_privilege('anon', 'public.ai_generation_requests', 'select'),
  'anonymous users cannot inspect AI requests'
);
select ok(
  not has_table_privilege('authenticated', 'public.ai_generation_requests', 'select'),
  'authenticated clients cannot inspect AI requests directly'
);
select ok(
  not has_table_privilege('anon', 'public.ai_provider_slot_health', 'select'),
  'anonymous users cannot inspect provider health state'
);
select ok(
  not has_table_privilege('authenticated', 'public.ai_provider_slot_health', 'select'),
  'authenticated clients cannot inspect provider health state'
);

select * from finish();
rollback;
