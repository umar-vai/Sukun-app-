-- Every fixture rolls back. The structured resource library installs once,
-- reuses existing audio by link, is readable by guests, and only a Super
-- Admin can edit self-assessment tests or reorder resources.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000007701', 'library-admin@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000007702', 'library-member@sukun.test', '{}');
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000007701', 'super_admin',
   '00000000-0000-4000-8000-000000007701'),
  ('00000000-0000-4000-8000-000000007702', 'member',
   '00000000-0000-4000-8000-000000007701')
on conflict do nothing;

-- An audio record that already exists with the same link as a library item.
insert into public.content_items (
  type, title, slug, media_source_type, media_url, visibility, status,
  published_at, created_by, updated_by
) values (
  'audio', 'Existing evil eye audio', 'library-test-existing-audio',
  'direct_audio_url',
  'https://files.ruqyahbd.org/audio/Ruqyah-EvilEye-ruqyahbd.org.mp3',
  'public', 'published', now(),
  '00000000-0000-4000-8000-000000007701',
  '00000000-0000-4000-8000-000000007701'
);

select throws_ok(
  $$ select private.install_resource_library('00000000-0000-4000-8000-000000007702') $$,
  '42501',
  null,
  'only a Super Admin can install the library'
);

select is(
  (private.install_resource_library('00000000-0000-4000-8000-000000007701')
    ->> 'moved_items')::integer,
  1,
  'existing audio with the same link is reused, not duplicated'
);

select is(
  (select cc.slug from public.content_items ci
   join public.content_categories cc on cc.id = ci.category_id
   where ci.slug = 'library-test-existing-audio'),
  'ruqyah-lib-topic',
  'reused audio is moved into its library category'
);

select is(
  private.install_resource_library('00000000-0000-4000-8000-000000007701'),
  '{"added_items": 0, "moved_items": 0, "added_tests": 0}'::jsonb,
  'a second install adds and moves nothing'
);

select is(
  (select count(*)::integer from public.content_items
   where slug like 'dua-ma-%' and type = 'dua' and status = 'published'),
  90,
  'all 90 dua are published'
);

select is(
  (select count(distinct category_id)::integer from public.content_items
   where slug like 'dua-ma-%'),
  18,
  'dua are grouped into 18 categories'
);

select is(
  (select count(*)::integer from public.content_items
   where type = 'pdf' and media_source_type = 'external_pdf'
     and slug like 'pdf-ruqyah-%'),
  19,
  'PDFs are stored as external links'
);

select is(
  (select count(*)::integer from public.content_items
   where (slug like 'ruqyah-lib-%' or slug like 'dua-ma-%'
          or slug like 'pdf-ruqyah-%')
     and media_url is not null and media_url !~ '^https://'),
  0,
  'every library media link is HTTPS'
);

select is(
  (select count(*)::integer from public.self_assessment_tests),
  7,
  'seven self-assessment tests are installed'
);

select is(
  (select count(*)::integer from public.self_assessment_questions q
   join public.self_assessment_tests t on t.id = q.test_id
   where t.slug = 'general'),
  32,
  'the general test has its 32 questions'
);

set local role anon;
select is(
  (select count(*)::integer from public.self_assessment_tests),
  7,
  'guests can read published tests'
);
select throws_ok(
  $$ update public.self_assessment_tests set title_bn = 'x' where slug = 'jinn' $$,
  '42501',
  null,
  'guests cannot edit tests'
);
reset role;

update public.self_assessment_tests set is_published = false
where slug = 'kids-child';
set local role anon;
select is(
  (select count(*)::integer from public.self_assessment_questions q
   join public.self_assessment_tests t on t.id = q.test_id
   where t.slug = 'kids-child'),
  0,
  'questions of an unpublished test are hidden from guests'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000007702', true);
update public.self_assessment_result_bands set message_bn = 'member edit';
reset role;
select is(
  (select count(*)::integer from public.self_assessment_result_bands
   where message_bn = 'member edit'),
  0,
  'a member cannot edit result bands'
);
set local role authenticated;
select throws_ok(
  $$ select public.set_content_item_sort_order(
       (select id from public.content_items where slug = 'dua-ma-01-01'), 5) $$,
  '42501',
  null,
  'a member cannot reorder resources'
);

select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000007701', true);
select public.set_content_item_sort_order(
  (select id from public.content_items where slug = 'dua-ma-01-01'), 5);
reset role;
select is(
  (select sort_order from public.content_items where slug = 'dua-ma-01-01'),
  5,
  'a Super Admin can reorder resources'
);

select * from finish();
rollback;
