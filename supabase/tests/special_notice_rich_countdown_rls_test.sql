begin;
create extension if not exists pgtap with schema extensions;
select plan(7);
select ok(
 (select exists(select 1 from information_schema.columns
 where table_schema='public' and table_name='universal_announcements'
 and column_name='countdown_ends_at')),
 'public notices support countdown deadline'
);
select ok(
 (select relrowsecurity from pg_class where
 oid='public.universal_announcements'::regclass),
 'RLS still protects notice draft and public reads'
);
select ok(
 not has_function_privilege('anon',
 'public.claim_universal_announcement_rich_batch(integer)','EXECUTE'),
 'guests cannot claim rich notice broadcasts'
);
select ok(
 not has_function_privilege('authenticated',
 'public.claim_universal_announcement_rich_batch(integer)','EXECUTE'),
 'ordinary accounts cannot claim rich notice broadcasts'
);
select ok(
 has_function_privilege('service_role',
 'public.claim_universal_announcement_rich_batch(integer)','EXECUTE'),
 'backend service role alone can claim public topic queue'
);
insert into auth.users(id,email) values
('c0000000-0000-4000-8000-000000009701','rich-notice@sukun.test');
select throws_ok($$
  insert into public.universal_announcements(
    title,body,status,created_by,countdown_ends_at)
  values('Invalid countdown','Public-only test','published',
    'c0000000-0000-4000-8000-000000009701',
    now()-interval '1 minute')
$$, '23514', 'Countdown must end within the next 30 days.',
 'past deadline cannot be used for a new announcement');
insert into public.universal_announcements(
  title,body,status,created_by,countdown_ends_at)
values ('Public countdown','Safe public test','published',
  'c0000000-0000-4000-8000-000000009701',now()+interval '5 hours');
set local role anon;
select is(
  (select count(*) from public.universal_announcements
   where title='Public countdown'),
  1::bigint,
  'a published countdown remains publicly readable under RLS'
);
select * from finish();
rollback;
