begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users(id,email) values
  ('00000000-0000-4000-8000-000000008821','draft-archive-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000008822','draft-archive-patient@sukun.test');

insert into public.user_roles(user_id,role,granted_by) values
  ('00000000-0000-4000-8000-000000008821','super_admin','00000000-0000-4000-8000-000000008821'),
  ('00000000-0000-4000-8000-000000008822','patient','00000000-0000-4000-8000-000000008821');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000008821',true);

select lives_ok(
  $$select public.save_content_item(
    p_type => 'article',p_title => 'Draft A',
    p_slug => 'bulk-archive-draft-a',p_visibility => 'staff_only',p_status => 'draft',
    p_request_id => '00000000-0000-4000-8000-000000008823')$$,
  'admin saves first draft'
);
select lives_ok(
  $$select public.save_content_item(
    p_type => 'dua',p_title => 'Draft B',
    p_slug => 'bulk-archive-draft-b',p_visibility => 'public',p_status => 'draft',
    p_request_id => '00000000-0000-4000-8000-000000008824')$$,
  'admin saves second draft'
);
select lives_ok(
  $$select public.save_content_item(
    p_type => 'article',p_title => 'Review C',
    p_slug => 'bulk-archive-review-c',p_visibility => 'staff_only',p_status => 'draft',
    p_request_id => '00000000-0000-4000-8000-000000008825')$$,
  'admin saves a third item'
);
select lives_ok(
  $$select public.transition_content_item(
    (select id from public.content_items where slug = 'bulk-archive-review-c'),
    'submit',null,'00000000-0000-4000-8000-000000008826')$$,
  'third item is already under review'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000008822',true);
select throws_ok(
  $$select public.archive_selected_content_drafts(
    array[(select id from public.content_items where slug='bulk-archive-draft-a')],
    '00000000-0000-4000-8000-000000008827')$$,
  '42501','Super Admin access is required.',
  'patient cannot archive draft content'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000008821',true);

select results_eq(
  $$select (public.archive_selected_content_drafts(
    array(select id from public.content_items
      where slug in ('bulk-archive-draft-a','bulk-archive-draft-b','bulk-archive-review-c')),
    '00000000-0000-4000-8000-000000008828'
  )->>'archived')::int$$,
  array[2::int],
  'only current drafts were archived'
);
select results_eq(
  $$select count(*) from public.content_items
      where slug in ('bulk-archive-draft-a','bulk-archive-draft-b')
        and status='archived' and archived_at is not null$$,
  array[2::bigint],
  'soft deletion retains both database records and archive timestamp'
);
select results_eq(
  $$select status::text from public.content_items
    where slug='bulk-archive-review-c'$$,
  array['review'::text],
  'concurrently reviewed content was not archived'
);
select results_eq(
  $$select count(*) from public.content_reviews
    where decision='archived' and content_item_id in (
      select id from public.content_items
      where slug in ('bulk-archive-draft-a','bulk-archive-draft-b'))$$,
  array[2::bigint],
  'both archives recorded reviewer history'
);
select results_eq(
  $$select count(*) from public.admin_audit_logs
    where action='content_item_archive' and entity_id in (
      select id from public.content_items
      where slug in ('bulk-archive-draft-a','bulk-archive-draft-b'))$$,
  array[2::bigint],
  'both archives recorded authenticated admin audit entries'
);
select ok(
  not has_function_privilege('anon','public.archive_selected_content_drafts(uuid[],uuid)','EXECUTE'),
  'anonymous users cannot invoke draft bulk archive'
);

select * from finish();
rollback;
