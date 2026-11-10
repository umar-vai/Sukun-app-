-- Every fixture rolls back. Templates are Super Admin only, edits are
-- validated and audited, and new templates get the next category number.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000003201', 'tpl-admin@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000003211', 'tpl-member@sukun.test', '{}');
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000003201', 'super_admin',
   '00000000-0000-4000-8000-000000003201');

select is(
  (select count(*)::int from public.care_templates), 51,
  'the 51 official templates are seeded');
select ok(
  (select rowsecurity from pg_tables
   where schemaname = 'public' and tablename = 'care_templates'),
  'RLS is enabled on templates');
select ok(
  not has_function_privilege('anon',
    'public.admin_save_care_template(jsonb)', 'EXECUTE'),
  'guest cannot save templates');
select ok(
  not has_table_privilege('authenticated', 'public.care_templates', 'UPDATE'),
  'no direct table writes');

-- A signed-in member sees nothing and cannot save.
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000003211', true);
select is((select count(*)::int from public.care_templates), 0,
  'member cannot read templates');
select throws_ok($$
  select public.admin_save_care_template(
    '{"id":"a01","category":"amal","title":"x","instruction":"y"}')
$$, '42501', 'Super Admin access is required.', 'member cannot save');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000003201', true);
select is((select count(*)::int from public.care_templates), 51,
  'admin reads every template');

select is(
  (public.admin_save_care_template(jsonb_build_object(
    'id', 's01', 'category', 'supplement', 'title', 'রুকইয়াহ পানি',
    'instruction', 'নতুন নির্দেশনা {বার} বার',
    'default_times', jsonb_build_array('08:00', '07:30', '08:00'),
    'resource_refs', jsonb_build_array('quran:1', 'srg2024-sup-001', 'quran:1'),
    'requires_resource', false, 'is_active', true
  ))).title,
  'রুকইয়াহ পানি', 'admin edits a template');
select is(
  (select default_times from public.care_templates where id = 's01'),
  array['07:30'::time, '08:00'::time], 'times are de-duplicated and sorted');
select is(
  (select resource_refs from public.care_templates where id = 's01'),
  array['quran:1', 'srg2024-sup-001'], 'content links keep order, no repeats');
select is(
  (select count(*)::int from public.admin_audit_logs
   where action = 'care_template.updated'
     and metadata->>'template_id' = 's01'
     and metadata->'before'->>'title' = 'রুকইয়াহ পাঠ দিয়ে পানি প্রস্তুত'),
  1, 'the edit is audited with the old text');

select is(
  (public.admin_save_care_template(jsonb_build_object(
    'category', 'amal', 'title', 'নতুন আমল',
    'instruction', 'প্রতিদিন করবেন।', 'default_times', jsonb_build_array('09:00')
  ))).id,
  'a12', 'a new amal template gets the next number');
select is(
  (select action_type from public.care_templates where id = 'a12'), 'amal',
  'action type follows the category');

select throws_ok($$
  select public.admin_save_care_template(
    '{"category":"amal","title":"x","instruction":"y","default_times":["25:00"]}')
$$, '22023', 'Invalid reminder time.', 'bad time rejected');
select throws_ok($$
  select public.admin_save_care_template(
    '{"category":"amal","title":"x","instruction":"y","resource_refs":["quran:200"]}')
$$, '22023', 'Invalid content link.', 'bad surah rejected');
select throws_ok($$
  select public.admin_save_care_template(
    '{"id":"z99","category":"amal","title":"x","instruction":"y"}')
$$, 'P0002', 'Template was not found.', 'unknown id is not created silently');

select * from finish();
rollback;
