begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000006841','review-edit-admin@sukun.test'),
 ('00000000-0000-4000-8000-000000006842','review-edit-patient@sukun.test');
insert into public.user_roles(user_id,role,granted_by) values
 ('00000000-0000-4000-8000-000000006841','super_admin',
  '00000000-0000-4000-8000-000000006841'),
 ('00000000-0000-4000-8000-000000006842','patient',
  '00000000-0000-4000-8000-000000006841');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006841',true);
select lives_ok(
 $$select public.save_content_item(
    p_type=>'article',p_title=>'Needs ayat source',
    p_slug=>'srg2024-qur-edit-needed',
    p_status=>'draft',p_visibility=>'staff_only',
    p_request_id=>'00000000-0000-4000-8000-000000006843')$$,
 'admin saves unsourced editorial text'
);
select lives_ok(
 $$select public.save_content_item(
    p_type=>'quran',p_title=>'Quran needs sources',
    p_slug=>'quran-awaiting-review',
    p_status=>'draft',p_visibility=>'staff_only',
    p_surah_number=>2,p_ayah_number=>255,
    p_request_id=>'00000000-0000-4000-8000-000000006844')$$,
 'admin saves canonical Quran draft for source review'
);
select lives_ok(
 $$select public.save_content_item(
    p_type=>'article',p_title=>'QA TEST private',
    p_slug=>'qa-test-review-placeholder',
    p_status=>'draft',p_visibility=>'staff_only',
    p_request_id=>'00000000-0000-4000-8000-000000006845')$$,
 'QA fixture stays a protected item'
);
select lives_ok(
 $$select public.save_content_item(
    p_type=>'dua',p_title=>'Archive after review',
    p_slug=>'review-archive-eligible',
    p_status=>'draft',p_visibility=>'staff_only',
    p_request_id=>'00000000-0000-4000-8000-000000006846')$$,
 'admin saves a noncanonical archive candidate'
);

select lives_ok(
 $$select public.transition_content_item(
  (select id from public.content_items where slug='srg2024-qur-edit-needed'),
  'submit',null,'00000000-0000-4000-8000-000000006847')$$,
 'article enters review'
);
select lives_ok(
 $$select public.transition_content_item(
  (select id from public.content_items where slug='quran-awaiting-review'),
  'submit',null,'00000000-0000-4000-8000-000000006848')$$,
 'Quran item enters review'
);
select lives_ok(
 $$select public.transition_content_item(
  (select id from public.content_items where slug='qa-test-review-placeholder'),
  'submit',null,'00000000-0000-4000-8000-000000006849')$$,
 'QA item is included as an excluded review example'
);
select lives_ok(
 $$select public.transition_content_item(
  (select id from public.content_items where slug='review-archive-eligible'),
  'submit',null,'00000000-0000-4000-8000-000000006850')$$,
 'Dua enters review'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006842',true);
select throws_ok(
 $$select public.manage_selected_content_reviews(
   array[(select id from public.content_items
     where slug='srg2024-qur-edit-needed')],
   'return_to_draft','00000000-0000-4000-8000-000000006851')$$,
 '42501','Super Admin access is required.',
 'patient cannot return reviewed content to draft'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006841',true);
select results_eq(
 $$select (public.manage_selected_content_reviews(
   array(select id from public.content_items
     where slug in ('srg2024-qur-edit-needed',
                    'quran-awaiting-review','qa-test-review-placeholder')),
   'return_to_draft','00000000-0000-4000-8000-000000006852'
 )->>'changed')::int$$,
 array[2::int],
 'bulk review correction returns only 2 eligible records'
);
select results_eq(
 $$select count(*) from public.content_items
    where slug in ('srg2024-qur-edit-needed','quran-awaiting-review')
      and status='draft' and visibility='staff_only'
      and published_at is null$$,
 array[2::bigint],
 'returned items stay non-public and editable'
);
select results_eq(
 $$select verification_status::text
    from public.content_items where slug='quran-awaiting-review'$$,
 array['rejected'::text],
 'canonical Quran correction resets verification status'
);
select results_eq(
 $$select status::text from public.content_items
   where slug='qa-test-review-placeholder'$$,
 array['review'::text],
 'QA review fixture remains unchanged'
);
select results_eq(
 $$select count(*) from public.admin_audit_logs
   where action='content_item_return_to_draft'
     and entity_id=(select id from public.content_items
       where slug='srg2024-qur-edit-needed')$$,
 array[1::bigint],
 'editorial return-to-draft is audited'
);
select results_eq(
 $$select (public.manage_selected_content_reviews(
   array[(select id from public.content_items
      where slug='review-archive-eligible')],
   'archive','00000000-0000-4000-8000-000000006853'
 )->>'changed')::int$$,
 array[1::int],
 'bulk review archive is a permitted soft delete'
);
select results_eq(
 $$select count(*) from public.content_items
    where slug='review-archive-eligible'
      and status='archived' and archived_at is not null$$,
 array[1::bigint],
 'archived review item retains record and timestamp'
);
select ok(
 not has_function_privilege(
   'anon','public.manage_selected_content_reviews(uuid[],text,uuid)',
   'EXECUTE'),
 'guests cannot manage review queue'
);

select * from finish();
rollback;
