begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

select ok(
  has_table_privilege('authenticated','public.universal_notice_seen','SELECT'),
  'authenticated users can read RLS-scoped receipts'
);
select ok(
  not has_table_privilege('anon','public.universal_notice_seen','SELECT'),
  'guests cannot read another viewer receipt'
);
select ok(
  not has_table_privilege('authenticated','public.universal_notice_seen','DELETE'),
  'viewers cannot clear immutable cloud acknowledgement'
);

insert into auth.users (id,email,raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000001821','notice-viewer-a@sukun.test','{}'::jsonb),
  ('00000000-0000-4000-8000-000000001822','notice-viewer-b@sukun.test','{}'::jsonb);

insert into public.universal_announcements (
  id,title,body,status,created_by
) values
  ('00000000-0000-4000-8000-000000001823','Safe public test notice',
   'This is only a synthetic test.', 'published',
   '00000000-0000-4000-8000-000000001821'),
  ('00000000-0000-4000-8000-000000001824','Private draft',
   'Must never count as seen by guests.', 'draft',
   '00000000-0000-4000-8000-000000001821');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001821', true);

insert into public.universal_notice_seen (announcement_id,published_at)
select id,published_at
  from public.universal_announcements
 where id='00000000-0000-4000-8000-000000001823';

select is(
  (select count(*) from public.universal_notice_seen),
  1::bigint, 'viewer sees their own public notice receipt'
);

select throws_ok(
  $$insert into public.universal_notice_seen (user_id,announcement_id,published_at)
      select '00000000-0000-4000-8000-000000001822'::uuid,id,published_at
      from public.universal_announcements
      where id='00000000-0000-4000-8000-000000001823'$$,
  '42501',
  'new row violates row-level security policy for table "universal_notice_seen"',
  'one user cannot mark a notice seen for another user'
);

select throws_ok(
  $$insert into public.universal_notice_seen (announcement_id,published_at)
      values ('00000000-0000-4000-8000-000000001824', now())$$,
  '42501',
  'new row violates row-level security policy for table "universal_notice_seen"',
  'draft content can never create a viewer receipt'
);

select is(
  (select count(*) from public.universal_notice_seen
   where user_id='00000000-0000-4000-8000-000000001822'),
  0::bigint, 'cross-user receipts remain inaccessible'
);

reset role;
select ok(
  not has_table_privilege('authenticated','public.universal_notice_seen','UPDATE'),
  'viewers cannot rewrite a receipt once created'
);

select * from finish();
rollback;
