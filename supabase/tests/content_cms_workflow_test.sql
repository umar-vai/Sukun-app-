begin;

create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000201', 'cms-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000000211', 'cms-patient@sukun.test');

insert into public.user_roles (user_id, role, granted_by) values
  (
    '00000000-0000-4000-8000-000000000201',
    'super_admin',
    '00000000-0000-4000-8000-000000000201'
  ),
  (
    '00000000-0000-4000-8000-000000000211',
    'patient',
    '00000000-0000-4000-8000-000000000201'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000211',
  true
);

select throws_ok(
  $$select public.save_content_category(
    p_name => 'Dua',
    p_slug => 'dua',
    p_request_id => '92000000-0000-4000-8000-000000000001'
  )$$,
  '42501',
  'Super Admin access is required.',
  'patient cannot create CMS categories'
);

select throws_ok(
  $$select public.save_content_item(
    p_type => 'article',
    p_title => 'Unauthorized',
    p_slug => 'unauthorized',
    p_visibility => 'public',
    p_status => 'draft',
    p_request_id => '92000000-0000-4000-8000-000000000002'
  )$$,
  '42501',
  'Super Admin access is required.',
  'patient cannot create CMS content'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);

select lives_ok(
  $$select public.save_content_category(
    p_name => 'Qur''an',
    p_name_bn => 'কুরআন',
    p_slug => 'quran',
    p_request_id => '92000000-0000-4000-8000-000000000003'
  )$$,
  'admin creates a canonical resource category'
);

select results_eq(
  $$select count(*) from public.content_categories where slug = 'quran'$$,
  array[1::bigint],
  'category is stored once'
);

select lives_ok(
  $$select public.save_content_item(
    p_type => 'quran',
    p_title => 'Ayatul Kursi',
    p_title_bn => 'আয়াতুল কুরসি',
    p_slug => 'ayatul-kursi',
    p_visibility => 'public',
    p_status => 'review',
    p_category_id => (select id from public.content_categories where slug = 'quran'),
    p_arabic_text => 'verified fixture text',
    p_bangla_text => 'approved fixture translation',
    p_source_type => 'licensed_publication',
    p_source_reference => 'Qur''an 2:255',
    p_source_edition => 'Approved fixture edition',
    p_translation_source => 'Approved Bangla fixture source',
    p_surah_number => 2,
    p_surah_name => 'Al-Baqarah',
    p_ayah_number => 255,
    p_request_id => '92000000-0000-4000-8000-000000000004'
  )$$,
  'admin saves sourced Qur''an content into review'
);

select results_eq(
  $$select status::text from public.content_items where slug = 'ayatul-kursi'$$,
  array['review'::text],
  'canonical resource is not auto-published'
);

select results_eq(
  $$select verification_status::text from public.content_items where slug = 'ayatul-kursi'$$,
  array['pending'::text],
  'canonical resource starts with pending verification'
);

select throws_ok(
  $$select public.save_content_item(
    p_type => 'quran',
    p_title => 'AI text',
    p_slug => 'ai-quran-text',
    p_visibility => 'public',
    p_status => 'draft',
    p_arabic_text => 'not canonical',
    p_source_type => 'generative_ai',
    p_surah_number => 1,
    p_ayah_number => 1,
    p_request_id => '92000000-0000-4000-8000-000000000005'
  )$$,
  '22023',
  'Canonical Qur''an and Hadith content cannot use a generative AI source.',
  'AI-generated canonical content is rejected even as a draft'
);

select throws_ok(
  $$select public.transition_content_item(
    p_content_item_id => (select id from public.content_items where slug = 'ayatul-kursi'),
    p_transition => 'publish',
    p_request_id => '92000000-0000-4000-8000-000000000006'
  )$$,
  '55000',
  'Qur''an and Hadith must be verified before publication.',
  'canonical content cannot publish before verification'
);

select lives_ok(
  $$select public.transition_content_item(
    p_content_item_id => (select id from public.content_items where slug = 'ayatul-kursi'),
    p_transition => 'verify',
    p_notes => 'Compared with approved fixture source.',
    p_request_id => '92000000-0000-4000-8000-000000000007'
  )$$,
  'reviewer verifies canonical source metadata'
);

select results_eq(
  $$select status::text, verification_status::text
    from public.content_items where slug = 'ayatul-kursi'$$,
  $$values ('verified'::text, 'verified'::text)$$,
  'verification records both lifecycle and verification state'
);

select lives_ok(
  $$select public.transition_content_item(
    p_content_item_id => (select id from public.content_items where slug = 'ayatul-kursi'),
    p_transition => 'publish',
    p_request_id => '92000000-0000-4000-8000-000000000008'
  )$$,
  'verified canonical content can be published'
);

select results_eq(
  $$select count(*) from public.content_reviews
    where content_item_id = (select id from public.content_items where slug = 'ayatul-kursi')$$,
  array[3::bigint],
  'submission, verification, and publication are retained in review history'
);

select results_eq(
  $$select count(*) from public.admin_audit_logs
    where entity_id = (select id from public.content_items where slug = 'ayatul-kursi')$$,
  array[3::bigint],
  'content save, verification, and publication are audited'
);

select throws_ok(
  $$select public.save_content_item(
    p_content_item_id => (select id from public.content_items where slug = 'ayatul-kursi'),
    p_type => 'quran',
    p_title => 'Changed published content',
    p_slug => 'ayatul-kursi',
    p_visibility => 'public',
    p_status => 'review',
    p_surah_number => 2,
    p_ayah_number => 255,
    p_request_id => '92000000-0000-4000-8000-000000000009'
  )$$,
  '55000',
  'Published or archived content cannot be edited.',
  'published content is immutable until explicitly unpublished'
);

select lives_ok(
  $$select public.transition_content_item(
    p_content_item_id => (select id from public.content_items where slug = 'ayatul-kursi'),
    p_transition => 'unpublish',
    p_request_id => '92000000-0000-4000-8000-000000000010'
  )$$,
  'published content can be returned to review'
);

select lives_ok(
  $$select public.transition_content_item(
    p_content_item_id => (select id from public.content_items where slug = 'ayatul-kursi'),
    p_transition => 'archive',
    p_request_id => '92000000-0000-4000-8000-000000000011'
  )$$,
  'content can be archived without deleting history'
);

select results_eq(
  $$select status::text, (archived_at is not null)::text
    from public.content_items where slug = 'ayatul-kursi'$$,
  $$values ('archived'::text, 'true'::text)$$,
  'archive state retains the row and records its timestamp'
);

select lives_ok(
  $$select public.save_content_item(
    p_type => 'hadith',
    p_title => 'Incomplete Hadith fixture',
    p_slug => 'incomplete-hadith-fixture',
    p_visibility => 'staff_only',
    p_status => 'review',
    p_source_type => 'licensed_publication',
    p_source_reference => 'Fixture reference',
    p_source_edition => 'Fixture edition',
    p_request_id => '92000000-0000-4000-8000-000000000012'
  )$$,
  'incomplete Hadith may be preserved safely for review'
);

select throws_ok(
  $$select public.transition_content_item(
    p_content_item_id => (select id from public.content_items where slug = 'incomplete-hadith-fixture'),
    p_transition => 'verify',
    p_request_id => '92000000-0000-4000-8000-000000000013'
  )$$,
  '22023',
  'Verified Hadith requires collection, book, and Hadith number.',
  'Hadith cannot verify without collection, book, and number'
);

select throws_ok(
  $$insert into public.content_items (
    type, title, slug, media_source_type, media_url, visibility, status,
    created_by, updated_by, published_at
  ) values (
    'audio', 'Unlicensed fixture', 'unlicensed-media-fixture',
    'direct_audio_url', 'https://cdn.example.test/audio.mp3', 'public',
    'published',
    '00000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000201', now()
  )$$,
  '23514',
  'new row for relation "content_items" violates check constraint "content_items_published_media_rights"',
  'published external media requires a rights or licensing note'
);

select lives_ok(
  $$insert into public.content_items (
    type, title, slug, media_source_type, media_url, rights_note,
    visibility, status, created_by, updated_by, published_at
  ) values (
    'audio', 'Licensed fixture', 'licensed-media-fixture',
    'direct_audio_url', 'https://cdn.example.test/audio.mp3',
    'Licensed test fixture; not production content.', 'public', 'published',
    '00000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000201', now()
  )$$,
  'published external media accepts documented rights metadata'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000211',
  true
);

select results_eq(
  $$select count(*) from public.content_reviews$$,
  array[0::bigint],
  'patient cannot read admin-only review notes'
);

select ok(
  not has_table_privilege('anon', 'public.content_reviews', 'SELECT'),
  'guest has no review-log table grant'
);

select * from finish();
rollback;
