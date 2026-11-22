-- Every fixture rolls back. Superseded Ruqyah audio and Dua/Amal leave the
-- public lists: unlinked items are archived, linked items are hidden but stay
-- readable for the people whose plan or routine links them. Other content is
-- untouched.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000007801', 'retire-admin@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000007802', 'retire-member@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000007803', 'retire-other@sukun.test', '{}');
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000007801', 'super_admin',
   '00000000-0000-4000-8000-000000007801'),
  ('00000000-0000-4000-8000-000000007802', 'member',
   '00000000-0000-4000-8000-000000007801'),
  ('00000000-0000-4000-8000-000000007803', 'member',
   '00000000-0000-4000-8000-000000007801')
on conflict do nothing;

select private.install_resource_library('00000000-0000-4000-8000-000000007801');

insert into public.content_categories (
  name, name_bn, slug, sort_order, created_by, updated_by
) values (
  'Retire test ruqyah audio', 'পুরোনো অডিও', 'ruqyah-retire-test', 900,
  '00000000-0000-4000-8000-000000007801',
  '00000000-0000-4000-8000-000000007801'
) on conflict (slug) do nothing;

insert into public.content_items (
  id, type, title, slug, category_id, media_source_type, media_url,
  visibility, status, published_at, created_by, updated_by
) values
  ('00000000-0000-4000-8000-000000007811', 'dua', 'Old unlinked dua',
   'retire-test-old-dua', null, null, null, 'public', 'published', now(),
   '00000000-0000-4000-8000-000000007801',
   '00000000-0000-4000-8000-000000007801'),
  ('00000000-0000-4000-8000-000000007812', 'amal', 'Old routine amal',
   'retire-test-old-amal', null, null, null, 'public', 'published', now(),
   '00000000-0000-4000-8000-000000007801',
   '00000000-0000-4000-8000-000000007801'),
  ('00000000-0000-4000-8000-000000007813', 'audio', 'Old template audio',
   'retire-test-old-audio',
   (select id from public.content_categories where slug = 'ruqyah-retire-test'),
   'direct_audio_url', 'https://example.test/old-template.mp3', 'public',
   'published', now(),
   '00000000-0000-4000-8000-000000007801',
   '00000000-0000-4000-8000-000000007801'),
  ('00000000-0000-4000-8000-000000007814', 'audio', 'Quran recitation',
   'retire-test-quran-audio', null, 'direct_audio_url',
   'https://example.test/quran.mp3', 'public', 'published', now(),
   '00000000-0000-4000-8000-000000007801',
   '00000000-0000-4000-8000-000000007801'),
  ('00000000-0000-4000-8000-000000007815', 'guide', 'Self guide topic',
   'srg2024-c01-t999',
   (select id from public.content_categories where slug = 'self-diagnosis-guide'),
   null, null, 'public', 'published', now(),
   '00000000-0000-4000-8000-000000007801',
   '00000000-0000-4000-8000-000000007801');

insert into public.personal_routines (id, owner_user_id, title) values
  ('00000000-0000-4000-8000-000000007821',
   '00000000-0000-4000-8000-000000007802', 'My routine');
insert into public.personal_routine_actions (
  routine_id, owner_user_id, title, notification_title, resource_provider,
  content_item_id
) values (
  '00000000-0000-4000-8000-000000007821',
  '00000000-0000-4000-8000-000000007802', 'Amal', 'Amal', 'cms',
  '00000000-0000-4000-8000-000000007812'
);

insert into public.care_templates (
  id, category, title, instruction, action_type, resource_refs
) values (
  'z98', 'amal', 'Template', 'Listen', 'amal',
  array['retire-test-old-audio']
);

select is(
  private.retire_superseded_resources('00000000-0000-4000-8000-000000007801'),
  '{"hidden": 2, "archived": 1}'::jsonb,
  'one unlinked item archived, two linked items hidden'
);

select is(
  (select status::text from public.content_items
   where slug = 'retire-test-old-dua'),
  'archived',
  'an unlinked old dua is archived'
);
select is(
  (select status::text || '/' || visibility::text from public.content_items
   where slug = 'retire-test-old-amal'),
  'published/assigned_only',
  'an old amal used by a routine is hidden, not archived'
);
select is(
  (select visibility::text from public.content_items
   where slug = 'retire-test-old-audio'),
  'assigned_only',
  'an old ruqyah audio used by a care template is hidden'
);
select is(
  (select status::text || '/' || visibility::text from public.content_items
   where slug = 'retire-test-quran-audio'),
  'published/public',
  'non-ruqyah audio is untouched'
);
select is(
  (select status::text from public.content_items
   where slug = 'srg2024-c01-t999'),
  'published',
  'self-ruqyah guide topics are untouched'
);
select is(
  (select count(*)::integer from public.content_items
   where (slug like 'dua-ma-%' or slug like 'ruqyah-lib-%')
     and (status <> 'published' or visibility <> 'public')),
  0,
  'the new library stays published and public'
);
select is(
  (select count(*)::integer from public.admin_audit_logs
   where action in ('superseded_resource_hidden', 'superseded_resource_archived')
     and metadata ->> 'slug' like 'retire-test-%'),
  3,
  'every change is audited'
);

select is(
  private.retire_superseded_resources('00000000-0000-4000-8000-000000007801'),
  '{"hidden": 0, "archived": 0}'::jsonb,
  'running again changes nothing'
);

set local role anon;
select is(
  (select count(*)::integer from public.content_items
   where slug like 'retire-test-old-%'),
  0,
  'guests no longer see the superseded items'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000007802', true);
select is(
  (select count(*)::integer from public.content_items
   where slug = 'retire-test-old-amal'),
  1,
  'the routine owner can still open the amal their routine links'
);
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000007803', true);
select is(
  (select count(*)::integer from public.content_items
   where slug = 'retire-test-old-amal'),
  0,
  'another member cannot open it'
);
reset role;

select * from finish();
rollback;
