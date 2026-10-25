begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

select ok(
  not has_function_privilege('anon',
    'public.claim_universal_announcement_rich_one(uuid)', 'EXECUTE'),
  'Anonymous users cannot claim a public push'
);
select ok(
  not has_function_privilege('authenticated',
    'public.claim_universal_announcement_rich_one(uuid)', 'EXECUTE'),
  'Signed-in users cannot claim public push'
);
select ok(
  has_function_privilege('service_role',
    'public.claim_universal_announcement_rich_one(uuid)', 'EXECUTE'),
  'Only the protected sender service may claim a public push'
);

insert into auth.users (id,email)
values ('c0000000-0000-4000-8000-000000009821', 'targeted-test@sukun.test');
insert into public.universal_announcements (id,title,body,status,created_by)
values (
 'c0000000-0000-4000-8000-000000009822',
 'Public synthetic dispatch',
 'Not a patient instruction',
 'published',
 'c0000000-0000-4000-8000-000000009821'
);
select is(
 (select count(*) from private.universal_announcement_outbox
  where announcement_id='c0000000-0000-4000-8000-000000009822'),
 1::bigint,
 'One real publication queues one send'
);
select is(
 (select count(*) from
  public.claim_universal_announcement_rich_one(
    'c0000000-0000-4000-8000-000000009822')),
 1::bigint,
 'Exactly one claim for the addressed notice'
);
select is(
 (select count(*) from
  public.claim_universal_announcement_rich_one(
    'c0000000-0000-4000-8000-000000009822')),
 0::bigint,
 'Second claim cannot duplicate a send'
);
select is(
 (select count(*) from
  public.claim_universal_announcement_rich_one(
    'c0000000-0000-4000-8000-000000009823')),
 0::bigint,
 'Unrelated notice cannot claim pending sends'
);
select * from finish();
rollback;
