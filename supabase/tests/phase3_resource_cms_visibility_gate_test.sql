begin;

-- Phase 3 content workflow / RLS: all texts are synthetic and original;
-- no Qur'an, Hadith, copyrighted audio, patient data, or third-party media.
-- These fixture rows are rolled back after the test.
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000d201', 'phase3-admin@invalid.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-00000000d211', 'phase3-patient@invalid.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-00000000d212', 'phase3-member@invalid.test',
   '{"role":"super_admin"}'::jsonb);
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-00000000d201', 'super_admin',
   '00000000-0000-4000-8000-00000000d201'),
  ('00000000-0000-4000-8000-00000000d211', 'patient',
   '00000000-0000-4000-8000-00000000d201');
select ok(
  exists (select 1 from public.user_roles
    where user_id='00000000-0000-4000-8000-00000000d212'
      and role='member'),
  'The Auth fixture has the canonical database-issued Member role'
);

insert into public.patients (user_id, patient_code, full_name, created_by)
values ('00000000-0000-4000-8000-00000000d211',
        'QA-PH3-PATIENT','Original QA Patient only',
        '00000000-0000-4000-8000-00000000d201');

set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d201', true);
select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Synthetic public QA article',
    p_slug => 'qa-phase3-public-article', p_visibility => 'public',
    p_status => 'draft', p_body => 'Original synthetic QA text. Not clinical advice.',
    p_rights_note => 'Original QA-only text; no third-party copyright.',
    p_request_id => '70000000-0000-4000-8000-00000000d201')$$,
  'Admin creates original public QA article as a draft');
select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Synthetic patient-only QA article',
    p_slug => 'qa-phase3-patient-article', p_visibility => 'patient_only',
    p_status => 'draft', p_body => 'Original synthetic text for role QA.',
    p_rights_note => 'Original QA-only text; no third-party copyright.',
    p_request_id => '70000000-0000-4000-8000-00000000d202')$$,
  'Admin creates patient-only original QA article as a draft');
select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Synthetic hidden draft',
    p_slug => 'qa-phase3-private-draft', p_visibility => 'staff_only',
    p_status => 'draft', p_body => 'Original synthetic hidden QA draft.',
    p_rights_note => 'Original QA-only text.',
    p_request_id => '70000000-0000-4000-8000-00000000d203')$$,
  'Admin creates staff-only draft separately');
select results_eq(
  $$select count(*) from public.content_items
    where slug like 'qa-phase3-%' and status='draft'$$,
  array[3::bigint], 'Three unpublished drafts exist only in Admin CMS');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d212', true);
select results_eq($$select count(*) from public.content_items
  where slug like 'qa-phase3-%'$$,
  array[0::bigint], 'Member cannot read unpublished resources');
select throws_ok(
  $$select public.transition_content_item(
    (select id from public.content_items
      where slug='qa-phase3-public-article'), 'publish', null,
    '70000000-0000-4000-8000-00000000d204')$$,
  '42501', 'Super Admin access is required.',
  'Fake admin metadata cannot publish CMS content');
select throws_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Forged member article',
    p_slug => 'forged-member-qa', p_visibility => 'public',
    p_status => 'draft',
    p_request_id => '70000000-0000-4000-8000-00000000d205')$$,
  '42501', 'Super Admin access is required.',
  'Member cannot create published or draft CMS content');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d211', true);
select results_eq($$select count(*) from public.content_items
  where slug like 'qa-phase3-%'$$,
  array[0::bigint], 'Patient cannot see unpublished resources');

reset role;
set local role anon;
select results_eq($$select count(*) from public.content_items
  where slug like 'qa-phase3-%'$$,
  array[0::bigint], 'Guest cannot see drafts');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d201', true);
select lives_ok(
  $$select public.transition_content_item(
    (select id from public.content_items
      where slug='qa-phase3-public-article'), 'submit', null,
    '70000000-0000-4000-8000-00000000d206')$$,
  'Admin submits public draft for review');
select lives_ok(
  $$select public.transition_content_item(
    (select id from public.content_items
      where slug='qa-phase3-public-article'), 'publish', null,
    '70000000-0000-4000-8000-00000000d207')$$,
  'Admin publishes reviewed original public content');
select lives_ok(
  $$select public.transition_content_item(
    (select id from public.content_items
      where slug='qa-phase3-patient-article'), 'submit', null,
    '70000000-0000-4000-8000-00000000d208')$$,
  'Admin submits patient-only draft for review');
select lives_ok(
  $$select public.transition_content_item(
    (select id from public.content_items
      where slug='qa-phase3-patient-article'), 'publish', null,
    '70000000-0000-4000-8000-00000000d209')$$,
  'Admin publishes reviewed patient-only article');
select results_eq(
  $$select count(*) from public.content_items
    where slug like 'qa-phase3-%' and status='published'$$,
  array[2::bigint], 'Only reviewed articles published; staff draft untouched');
select results_eq(
  $$select count(*) from public.content_reviews
    where content_item_id in
      (select id from public.content_items where slug like 'qa-phase3-%')$$,
  array[4::bigint], 'CMS review/publish audit history contains four transitions');
select results_eq(
  $$select count(*) from public.content_items
    where slug like 'qa-phase3-%' and rights_note is not null$$,
  array[3::bigint], 'All original QA resources document their rights');

reset role;
set local role anon;
-- An anonymous PostgREST request has no authenticated subject. SET ROLE in
-- a synthetic SQL test does NOT automatically clear prior JWT GUCs.
select set_config('request.jwt.claim.sub', '', true);
select results_eq($select slug from public.content_items
  where slug like 'qa-phase3-%' order by slug$$,
  $$values ('qa-phase3-public-article'::text)$$,
  'Guests see only public published article');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d212', true);
select results_eq($$select slug from public.content_items
  where slug like 'qa-phase3-%' order by slug$$,
  $$values ('qa-phase3-public-article'::text)$$,
  'General Members see public article but not patient-only resource');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
                  '00000000-0000-4000-8000-00000000d211', true);
select results_eq($$select slug from public.content_items
  where slug like 'qa-phase3-%' order by slug$$,
  $$values ('qa-phase3-patient-article'::text),
           ('qa-phase3-public-article'::text)$$,
  'Patients see public and patient-only items; hidden draft stays private');
select results_eq(
  $update public.content_items set title='Unauthorized patient edit'
    where slug='qa-phase3-public-article' returning id$,
  array[]::uuid[], 'Patient cannot directly modify published resources');

select * from finish();
rollback;
