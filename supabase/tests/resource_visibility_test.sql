begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000101', 'resource-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000000111', 'resource-patient-one@sukun.test'),
  ('00000000-0000-4000-8000-000000000112', 'resource-patient-two@sukun.test');

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000101', 'super_admin', '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000111', 'patient', '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000112', 'patient', '00000000-0000-4000-8000-000000000101');

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values
  (
    '10000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000111',
    'RES-P001',
    'Resource Patient One',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '10000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000112',
    'RES-P002',
    'Resource Patient Two',
    '00000000-0000-4000-8000-000000000101'
  );

insert into public.care_plans (
  id, patient_id, version, name, start_date, status,
  published_at, published_by, created_by
) values (
  '30000000-0000-4000-8000-000000000101',
  '10000000-0000-4000-8000-000000000101',
  1,
  'Resource assignment plan',
  current_date,
  'draft',
  null,
  null,
  '00000000-0000-4000-8000-000000000101'
);
insert into public.plan_actions (
  id, care_plan_id, type, title, frequency_rule, start_date,
  review_status, created_by
) values (
  '40000000-0000-4000-8000-000000000101',
  '30000000-0000-4000-8000-000000000101',
  'audio',
  'Assigned audio',
  '{"type":"daily"}',
  current_date,
  'approved',
  '00000000-0000-4000-8000-000000000101'
);

insert into public.content_categories (
  id, name, slug, created_by, updated_by
) values
  (
    '70000000-0000-4000-8000-000000000101',
    'Public resources',
    'public-resources',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '70000000-0000-4000-8000-000000000102',
    'Staff resources',
    'staff-resources',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101'
  );

insert into public.content_items (
  id, type, category_id, title, slug, source_reference,
  verification_status, verified_by, verified_at,
  surah_number, ayah_number, visibility, status,
  created_by, updated_by, published_at
) values
  (
    '71000000-0000-4000-8000-000000000101',
    'article',
    '70000000-0000-4000-8000-000000000101',
    'Public article',
    'public-article',
    null,
    'not_required',
    null,
    null,
    null,
    null,
    'public',
    'published',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    now()
  ),
  (
    '71000000-0000-4000-8000-000000000102',
    'guide',
    '70000000-0000-4000-8000-000000000101',
    'Patient guide',
    'patient-guide',
    null,
    'not_required',
    null,
    null,
    null,
    null,
    'patient_only',
    'published',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    now()
  ),
  (
    '71000000-0000-4000-8000-000000000103',
    'audio',
    '70000000-0000-4000-8000-000000000101',
    'Assigned ruqyah audio',
    'assigned-ruqyah-audio',
    null,
    'not_required',
    null,
    null,
    null,
    null,
    'assigned_only',
    'published',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    now()
  ),
  (
    '71000000-0000-4000-8000-000000000104',
    'article',
    '70000000-0000-4000-8000-000000000102',
    'Staff reference',
    'staff-reference',
    null,
    'not_required',
    null,
    null,
    null,
    null,
    'staff_only',
    'published',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    now()
  ),
  (
    '71000000-0000-4000-8000-000000000105',
    'article',
    '70000000-0000-4000-8000-000000000101',
    'Unpublished article',
    'unpublished-article',
    null,
    'not_required',
    null,
    null,
    null,
    null,
    'public',
    'draft',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    null
  ),
  (
    '71000000-0000-4000-8000-000000000106',
    'quran',
    '70000000-0000-4000-8000-000000000101',
    'Verified Quran ayah',
    'verified-quran-ayah',
    'Quran 2:255 — approved test fixture',
    'verified',
    '00000000-0000-4000-8000-000000000101',
    now(),
    2,
    255,
    'public',
    'published',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    now()
  );

insert into public.plan_action_resources (
  plan_action_id, content_item_id, created_by
) values (
  '40000000-0000-4000-8000-000000000101',
  '71000000-0000-4000-8000-000000000103',
  '00000000-0000-4000-8000-000000000101'
);

update public.care_plans
set status = 'active',
    published_at = now(),
    published_by = '00000000-0000-4000-8000-000000000101'
where id = '30000000-0000-4000-8000-000000000101';

insert into public.content_tags (id, name, slug, created_by) values
  (
    '72000000-0000-4000-8000-000000000101',
    'Public tag',
    'public-tag',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '72000000-0000-4000-8000-000000000102',
    'Staff tag',
    'staff-tag',
    '00000000-0000-4000-8000-000000000101'
  );
insert into public.content_item_tags (content_item_id, content_tag_id) values
  (
    '71000000-0000-4000-8000-000000000101',
    '72000000-0000-4000-8000-000000000101'
  ),
  (
    '71000000-0000-4000-8000-000000000104',
    '72000000-0000-4000-8000-000000000102'
  );

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select results_eq(
  $$select count(*) from public.content_items$$,
  array[2::bigint],
  'guest sees only published public resources'
);
select results_eq(
  $$select count(*) from public.content_categories$$,
  array[1::bigint],
  'guest cannot discover staff-only categories'
);
select results_eq(
  $$select count(*) from public.content_tags$$,
  array[1::bigint],
  'guest cannot discover staff-only tags'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000111',
  true
);
select results_eq(
  $$select count(*) from public.content_items$$,
  array[4::bigint],
  'assigned patient sees public, patient-only, and their assigned resource'
);
select results_eq(
  $$select count(*) from public.content_items
    where id = '71000000-0000-4000-8000-000000000103'$$,
  array[1::bigint],
  'assigned patient can read the canonical assigned resource'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000112',
  true
);
select results_eq(
  $$select count(*) from public.content_items$$,
  array[3::bigint],
  'other patient cannot read a resource assigned to someone else'
);
select results_eq(
  $$select count(*) from public.content_items
    where visibility = 'staff_only'$$,
  array[0::bigint],
  'patient cannot read staff-only resources'
);
select throws_ok(
  $$insert into public.content_items (
      type, title, slug, visibility, status, created_by, updated_by
    ) values (
      'article', 'Unauthorized article', 'unauthorized-article',
      'public', 'draft',
      '00000000-0000-4000-8000-000000000112',
      '00000000-0000-4000-8000-000000000112'
    )$$,
  '42501',
  null,
  'patient cannot create or mutate content'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select results_eq(
  $$select count(*) from public.content_items$$,
  array[6::bigint],
  'database-verified super admin can manage all resource states'
);

reset role;
select throws_ok(
  $$insert into public.content_items (
      type, title, slug, arabic_text, source_type, source_reference,
      verification_status, surah_number, ayah_number, visibility, status,
      created_by, updated_by, published_at
    ) values (
      'quran', 'Unverified Quran fixture', 'unverified-quran-fixture', 'fixture',
      'generative_ai', null, 'pending', 1, 1, 'public', 'published',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101', now()
    )$$,
  '23514',
  null,
  'unverified or AI-sourced Quran content cannot be published'
);
select results_eq(
  $$select count(*) from public.content_items
    where type = 'quran' and status = 'published'$$,
  array[1::bigint],
  'verified sourced Quran fixture remains publishable'
);
select ok(
  not has_table_privilege('anon', 'public.content_items', 'INSERT'),
  'guest has no content mutation grant'
);

select * from finish();
rollback;
