begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

select is(
  (select c.relrowsecurity from pg_class c
    where c.oid='public.universal_announcements'::regclass),
  true, 'universal announcements have RLS'
);

select ok(
  has_table_privilege('anon','public.universal_announcements','SELECT'),
  'guests may read the RLS-filtered public feed'
);

select ok(
  not has_table_privilege('anon','public.universal_announcements','INSERT'),
  'guests cannot create or publish universal notices'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_universal_announcement_batch(integer)', 'EXECUTE'
  ), 'ordinary members cannot claim push dispatch jobs'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.complete_universal_announcement_broadcast(uuid,boolean,text)',
    'EXECUTE'
  ), 'ordinary members cannot forge FCM send acknowledgements'
);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000001801','notice-tester@sukun.test');

insert into public.universal_announcements (
  id, title, body, status, created_by
) values
  ('00000000-0000-4000-8000-000000001811', 'Hidden draft',
   'Unpublished and never public.', 'draft',
   '00000000-0000-4000-8000-000000001801'),
  ('00000000-0000-4000-8000-000000001812', 'Published notice',
   'This public test text is safe.', 'published',
   '00000000-0000-4000-8000-000000001801');

select is(
  (select count(*) from private.universal_announcement_outbox),
  1::bigint, 'publication queues exactly one server-only dispatch'
);

select is(
  (select status from private.universal_announcement_outbox limit 1),
  'pending'::text, 'queue entries do not claim FCM delivery'
);

set local role anon;
select is(
  (select count(*) from public.universal_announcements),
  1::bigint, 'guest sees published notice but cannot read draft'
);
reset role;

select throws_ok(
  $$insert into public.universal_announcements (
    title, body, link_url, created_by
  ) values ('Unsafe', 'Never allow http', 'http://unsafe.test',
    '00000000-0000-4000-8000-000000001801')$$,
  '23514', 'HTTPS-only constraint blocks insecure links'
);

select * from finish();
rollback;
