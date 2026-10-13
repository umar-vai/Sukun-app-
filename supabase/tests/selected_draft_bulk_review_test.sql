begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users(id,email) values
  ('00000000-0000-4000-8000-000000008931','review-batch-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000008932','review-batch-patient@sukun.test');

insert into public.user_roles(user_id,role,granted_by) values
  ('00000000-0000-4000-8000-000000008931','super_admin',
   '00000000-0000-4000-8000-000000008931'),
  ('00000000-0000-4000-8000-000000008932','patient',
   '00000000-0000-4000-8000-000000008931');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000008931',true);

select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Unverified source text',
    p_slug => 'srg2024-qur-awaiting-reference',
    p_visibility => 'staff_only', p_status => 'draft',
    p_request_id => '00000000-0000-4000-8000-000000008933'
  )$$,
  'missing-source editorial text can be saved as a staff-only draft'
);
select lives_ok(
  $$select public.save_content_item(
    p_type => 'dua', p_title => 'Dua waiting for review',
    p_slug => 'review-batch-dua',
    p_visibility => 'staff_only', p_status => 'draft',
    p_request_id => '00000000-0000-4000-8000-000000008934'
  )$$,
  'another category can enter the same review batch'
);
select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'QA TEST Only',
    p_slug => 'qa-test-internal',
    p_visibility => 'staff_only', p_status => 'draft',
    p_request_id => '00000000-0000-4000-8000-000000008935'
  )$$,
  'private QA fixture stays a draft'
);
select lives_ok(
  $$select public.save_content_item(
    p_type => 'article', p_title => 'Already submitted',
    p_slug => 'review-batch-already-reviewed',
    p_visibility => 'staff_only', p_status => 'draft',
    p_request_id => '00000000-0000-4000-8000-000000008936'
  )$$,
  'additional item is saved to test stale selection'
);
select lives_ok(
  $$select public.transition_content_item(
    (select id from public.content_items
      where slug='review-batch-already-reviewed'),
    'submit', null,'00000000-0000-4000-8000-000000008937')$$,
  'other admin could already have submitted the selected draft'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000008932',true);
select throws_ok(
  $$select public.submit_selected_content_drafts_for_review(
    array[(select id from public.content_items
      where slug='review-batch-dua')],
    '00000000-0000-4000-8000-000000008938')$$,
  '42501', 'Super Admin access is required.',
  'patient is denied bulk submit for review'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000008931',true);
select results_eq(
  $$select (public.submit_selected_content_drafts_for_review(
    array(select id from public.content_items
      where slug in ('srg2024-qur-awaiting-reference','review-batch-dua',
        'qa-test-internal','review-batch-already-reviewed')),
    '00000000-0000-4000-8000-000000008939'
  )->>'submitted')::int$$,
  array[2::int],
  'only the two currently valid drafts enter the review queue'
);
select results_eq(
  $$select count(*) from public.content_items
      where slug in ('srg2024-qur-awaiting-reference','review-batch-dua')
        and status='review' and visibility='staff_only'
        and published_at is null$$,
  array[2::bigint],
  'bulk submit preserves staff-only visibility and does not publish'
);
select results_eq(
  $$select count(*) from public.content_items
      where slug='qa-test-internal' and status='draft'$$,
  array[1::bigint],
  'the QA record is never bulk submitted'
);
select results_eq(
  $$select count(*) from public.content_items
      where slug='review-batch-already-reviewed' and status='review'$$,
  array[1::bigint],
  'already reviewed item remains in its current state'
);
select results_eq(
  $$select count(*) from public.admin_audit_logs
      where action='content_item_submit'
        and entity_id in (select id from public.content_items
          where slug in ('srg2024-qur-awaiting-reference','review-batch-dua'))$$,
  array[2::bigint],
  'both batch submissions have Super Admin audit entries'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.submit_selected_content_drafts_for_review(uuid[],uuid)',
    'EXECUTE'
  ),
  'unauthenticated guests cannot request bulk review'
);

select * from finish();
rollback;
