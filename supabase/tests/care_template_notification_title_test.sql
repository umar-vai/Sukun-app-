-- Every fixture rolls back. A template can carry a default reminder name;
-- blank clears it and an over-long name is refused.
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000003301', 'tpl-name-admin@sukun.test', '{}');
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000003301', 'super_admin',
   '00000000-0000-4000-8000-000000003301');

select has_column('public', 'care_templates', 'notification_title',
  'templates have a reminder name column');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000003301', true);

select is(
  (public.admin_save_care_template(jsonb_build_object(
    'id', 's01', 'category', 'supplement', 'title', 'রুকইয়াহ পানি',
    'instruction', 'দিনে {বার} বার পান করুন',
    'notification_title', '  রুকইয়াহ পানি পানের সময়  '
  ))).notification_title,
  'রুকইয়াহ পানি পানের সময়', 'admin sets a trimmed reminder name');

select is(
  (public.admin_save_care_template(jsonb_build_object(
    'id', 's01', 'category', 'supplement', 'title', 'রুকইয়াহ পানি',
    'instruction', 'দিনে {বার} বার পান করুন'
  ))).notification_title,
  null, 'leaving the name out clears it (template title is used)');

select is(
  (public.admin_save_care_template(jsonb_build_object(
    'id', 's01', 'category', 'supplement', 'title', 'রুকইয়াহ পানি',
    'instruction', 'দিনে {বার} বার পান করুন', 'notification_title', '   '
  ))).notification_title,
  null, 'a blank name is stored as null');

select throws_ok(format($$
  select public.admin_save_care_template(jsonb_build_object(
    'id', 's01', 'category', 'supplement', 'title', 'x',
    'instruction', 'y', 'notification_title', %L))
$$, repeat('ন', 121)), '22023', 'Reminder name is too long.',
  'a name over 120 letters is refused');

select * from finish();
rollback;
