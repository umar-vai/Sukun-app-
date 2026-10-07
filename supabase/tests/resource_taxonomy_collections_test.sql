begin;

create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000301', 'taxonomy-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000000311', 'taxonomy-patient@sukun.test');

insert into public.user_roles (user_id, role, granted_by) values
  (
    '00000000-0000-4000-8000-000000000301',
    'super_admin',
    '00000000-0000-4000-8000-000000000301'
  ),
  (
    '00000000-0000-4000-8000-000000000311',
    'patient',
    '00000000-0000-4000-8000-000000000301'
  );

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values (
  '10000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000311',
  'TAX-P001',
  'Taxonomy Patient',
  '00000000-0000-4000-8000-000000000301'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000301',
  true
);

select lives_ok(
  $$select public.install_standard_resource_taxonomy(
    '93000000-0000-4000-8000-000000000001'
  )$$,
  'admin installs the approved Dua/Azkar and Ruqyah taxonomy'
);

select results_eq(
  $$select count(*) from public.content_categories
    where slug in ('dua-azkar', 'ruqyah')
       or slug like 'dua-azkar-%'
       or slug like 'ruqyah-%'$$,
  array[17::bigint],
  'taxonomy contains two roots and fifteen approved child categories'
);

select lives_ok(
  $$select public.install_standard_resource_taxonomy(
    '93000000-0000-4000-8000-000000000001'
  )$$,
  'taxonomy installation is idempotent for a retried request'
);

select results_eq(
  $$select count(*) from public.content_categories
    where slug in ('dua-azkar', 'ruqyah')
       or slug like 'dua-azkar-%'
       or slug like 'ruqyah-%'$$,
  array[17::bigint],
  'retry does not duplicate taxonomy rows'
);

insert into public.content_items (
  id, type, title, slug, arabic_text, source_type, source_reference,
  source_edition, verification_status, verified_by, verified_at,
  surah_number, surah_name, ayah_number, visibility, status,
  created_by, updated_by, published_at
) values
  (
    '71000000-0000-4000-8000-000000000301', 'quran',
    'Verified Ayah 1', 'taxonomy-verified-ayah-1', 'verified fixture 1',
    'licensed_publication', 'Quran 1:1 fixture', 'Approved fixture edition',
    'verified', '00000000-0000-4000-8000-000000000301', now(),
    1, 'Al-Fatihah', 1, 'public', 'published',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000301', now()
  ),
  (
    '71000000-0000-4000-8000-000000000302', 'quran',
    'Verified Ayah 2', 'taxonomy-verified-ayah-2', 'sourced fixture 2',
    'licensed_publication', 'Quran 1:2 fixture', 'Approved fixture edition',
    'verified', '00000000-0000-4000-8000-000000000301', now(),
    1, 'Al-Fatihah', 2, 'public', 'published',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000301', now()
  ),
  (
    '71000000-0000-4000-8000-000000000303', 'article',
    'Non Quran fixture', 'taxonomy-non-quran', null, null, null, null,
    'not_required', null, null, null, null, null, 'public', 'published',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000301', now()
  );

select throws_ok(
  $$select public.save_content_collection(
    p_type => 'selected_ayat',
    p_title => 'Invalid collection',
    p_slug => 'invalid-collection',
    p_content_item_ids => array[
      '71000000-0000-4000-8000-000000000303'::uuid
    ],
    p_request_id => '93000000-0000-4000-8000-000000000002'
  )$$,
  '22023',
  'Collections may only reference active canonical Qur''an Ayat.',
  'collection rejects non-Quran content'
);

select throws_ok(
  $$select public.save_content_collection(
    p_type => 'selected_ayat',
    p_title => 'Duplicate collection',
    p_slug => 'duplicate-collection',
    p_content_item_ids => array[
      '71000000-0000-4000-8000-000000000301'::uuid,
      '71000000-0000-4000-8000-000000000301'::uuid
    ],
    p_request_id => '93000000-0000-4000-8000-000000000003'
  )$$,
  '22023',
  'A collection cannot contain duplicate Ayat.',
  'collection rejects duplicate membership'
);

select lives_ok(
  $$select public.save_content_collection(
    p_type => 'selected_ayat',
    p_title => 'Selected Ayat fixture',
    p_slug => 'selected-ayat-fixture',
    p_content_item_ids => array[
      '71000000-0000-4000-8000-000000000301'::uuid,
      '71000000-0000-4000-8000-000000000302'::uuid
    ],
    p_request_id => '93000000-0000-4000-8000-000000000004'
  )$$,
  'admin creates a draft selected-Ayat collection'
);

select results_eq(
  $$select content_item_id from public.content_collection_items
    where collection_id = (
      select id from public.content_collections
      where slug = 'selected-ayat-fixture'
    ) order by sort_order$$,
  $$values
    ('71000000-0000-4000-8000-000000000301'::uuid),
    ('71000000-0000-4000-8000-000000000302'::uuid)$$,
  'collection retains canonical resource IDs in the selected order'
);

select lives_ok(
  $$select public.transition_content_collection(
    (select id from public.content_collections
      where slug = 'selected-ayat-fixture'),
    'publish',
    '93000000-0000-4000-8000-000000000005'
  )$$,
  'admin publishes a collection only after all Ayat are published'
);

select lives_ok(
  $$select public.save_content_collection(
    p_type => 'ruqyah_ayat',
    p_title => 'Patient Ruqyah fixture',
    p_slug => 'patient-ruqyah-fixture',
    p_visibility => 'patient_only',
    p_content_item_ids => array[
      '71000000-0000-4000-8000-000000000302'::uuid
    ],
    p_request_id => '93000000-0000-4000-8000-000000000006'
  )$$,
  'admin creates a patient-only Ruqyah-Ayat collection'
);

select lives_ok(
  $$select public.transition_content_collection(
    (select id from public.content_collections
      where slug = 'patient-ruqyah-fixture'),
    'publish',
    '93000000-0000-4000-8000-000000000007'
  )$$,
  'admin publishes the patient-only Ruqyah collection'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
  $$select slug from public.content_collections order by slug$$,
  array['selected-ayat-fixture'::text],
  'guest sees only a published public collection'
);

select results_eq(
  $$select count(*) from public.content_collection_items$$,
  array[2::bigint],
  'guest sees only memberships whose collection and Ayat are readable'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000311',
  true
);

select results_eq(
  $$select slug from public.content_collections order by slug$$,
  $$values ('patient-ruqyah-fixture'::text), ('selected-ayat-fixture'::text)$$,
  'patient sees public and patient-only published collections'
);

select throws_ok(
  $$select public.install_standard_resource_taxonomy(
    '93000000-0000-4000-8000-000000000008'
  )$$,
  '42501',
  'Super Admin access is required.',
  'patient cannot install or change the standard taxonomy'
);

select throws_ok(
  $$select public.save_content_collection(
    p_type => 'ruqyah_ayat',
    p_title => 'Unauthorized',
    p_slug => 'unauthorized-ruqyah',
    p_content_item_ids => array[
      '71000000-0000-4000-8000-000000000301'::uuid
    ],
    p_request_id => '93000000-0000-4000-8000-000000000009'
  )$$,
  '42501',
  'Super Admin access is required.',
  'patient cannot create collections'
);

select throws_ok(
  $$insert into public.content_collection_items (
    collection_id, content_item_id, created_by
  ) values (
    (select id from public.content_collections
      where slug = 'selected-ayat-fixture'),
    '71000000-0000-4000-8000-000000000303',
    '00000000-0000-4000-8000-000000000311'
  )$$,
  '42501',
  'new row violates row-level security policy for table "content_collection_items"',
  'patient cannot mutate collection membership directly'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000301',
  true
);

select lives_ok(
  $$select public.transition_content_collection(
    (select id from public.content_collections
      where slug = 'selected-ayat-fixture'),
    'unpublish',
    '93000000-0000-4000-8000-000000000010'
  )$$,
  'admin can unpublish a collection without deleting its membership'
);

select results_eq(
  $$select count(*) from public.admin_audit_logs
    where action in (
      'standard_resource_taxonomy_installed',
      'content_collection_saved',
      'content_collection_transitioned'
    )$$,
  array[6::bigint],
  'taxonomy and collection mutations are audited'
);

select * from finish();
rollback;
