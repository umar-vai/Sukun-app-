begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users(id,email) values
  ('00000000-0000-4000-8000-000000009731','bulk-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000009732','bulk-patient@sukun.test');

insert into public.user_roles(user_id,role,granted_by) values
  ('00000000-0000-4000-8000-000000009731','super_admin',
   '00000000-0000-4000-8000-000000009731'),
  ('00000000-0000-4000-8000-000000009732','patient',
   '00000000-0000-4000-8000-000000009731');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000009731',true);

select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Reviewed Guide Fixture',
    p_slug => 'srg2024-guide-approved-reference',
    p_visibility => 'staff_only', p_status => 'draft',
    p_source_reference => 'Source guide fixture',
    p_rights_note => 'Sukun Life owner attested app-use rights on 2026-10-12. Attribution preserved.',
    p_request_id => '00000000-0000-4000-8000-000000009733'
  )$$,
  'the Super Admin saves an owner-authorized staff-only draft'
);

select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Unverified Ayat Fixture',
    p_slug => 'srg2024-qur-unverified-fixture',
    p_visibility => 'staff_only', p_status => 'draft',
    p_source_reference => 'Unverified page number',
    p_rights_note => 'Sukun Life owner attested app-use rights on 2026-10-12. Attribution preserved.',
    p_request_id => '00000000-0000-4000-8000-000000009734'
  )$$,
  'an incomplete Qur''an editorial fragment is retained as a draft'
);

select lives_ok(
  $$select public.save_content_item(
    p_type => 'audio', p_title => 'Untrusted Host Fixture',
    p_slug => 'sukun-ruqyahbd-external-host',
    p_visibility => 'staff_only', p_status => 'draft',
    p_source_reference => 'Audio fixture source',
    p_rights_note => 'Owner-attested Sukun Life audio authorization (2026-10-12). Synthetic fixture.',
    p_media_source_type => 'direct_audio_url',
    p_media_url => 'https://example.invalid/audio/not-authorized.mp3',
    p_request_id => '00000000-0000-4000-8000-000000009735'
  )$$,
  'a suspicious media host remains just a draft'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000009732',true);

select throws_ok(
  $$select public.publish_reviewed_resource_batch(
    array[(select id from public.content_items
      where slug='srg2024-guide-approved-reference')],
    '00000000-0000-4000-8000-000000009736'
  )$$,
  '42501', 'Super Admin access is required.',
  'a patient cannot invoke bulk publication'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000009731',true);

select results_eq(
  $$select (public.publish_reviewed_resource_batch(
      array(
        select id from public.content_items
        where slug in ('srg2024-guide-approved-reference',
                       'srg2024-qur-unverified-fixture',
                       'sukun-ruqyahbd-external-host')
      ),
      '00000000-0000-4000-8000-000000009737'
    )->>'published')::int$$,
  array[1::int],
  'only the eligible source-backed item is published'
);

select results_eq(
  $$select status::text, visibility::text
    from public.content_items where slug = 'srg2024-guide-approved-reference'$$,
  $$values ('published'::text, 'public'::text)$$,
  'atomic publication also changes guest visibility'
);

select results_eq(
  $$select count(*) from public.content_items
    where slug in ('srg2024-qur-unverified-fixture',
                   'sukun-ruqyahbd-external-host')
      and status='draft' and visibility='staff_only'$$,
  array[2::bigint],
  'incomplete Ayat and untrusted audio host remain private drafts'
);

select results_eq(
  $$select count(*) from public.admin_audit_logs
    where entity_id=(select id from public.content_items
      where slug='srg2024-guide-approved-reference')$$,
  array[4::bigint],
  'content save, visibility change, submit and publish are all audited'
);

select results_eq(
  $$select count(*) from public.content_reviews
    where content_item_id=(select id from public.content_items
      where slug='srg2024-guide-approved-reference')$$,
  array[2::bigint],
  'submission and publication decisions are retained'
);

select * from finish();
rollback;
