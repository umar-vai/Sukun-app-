-- Synthetic rollback-only guard: published Admin templates and owner copies.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select ok((select relrowsecurity from pg_class
 where oid='public.routine_templates'::regclass),
 'published templates enforce RLS');
select ok((select relrowsecurity from pg_class
 where oid='public.routine_template_steps'::regclass),
 'template steps enforce RLS');
select ok(not has_table_privilege('anon','public.routine_templates','SELECT'),
 'guests cannot list private templates');
select ok(not has_table_privilege('anon','public.routine_template_steps','SELECT'),
 'guests cannot list template steps');

insert into auth.users(id,email,raw_user_meta_data)
values ('f0000000-0000-4000-8000-000000009911','template-member@sukun.test','{}'::jsonb);

insert into public.routine_templates(id,title,status,created_by)
values
('f1000000-0000-4000-8000-000000009901','Approved Published','published',
 'f0000000-0000-4000-8000-000000009911'),
('f1000000-0000-4000-8000-000000009902','Hidden Draft','draft',
 'f0000000-0000-4000-8000-000000009911');
insert into public.routine_template_steps(template_id,title,sort_order)
values ('f1000000-0000-4000-8000-000000009901','Morning Amal',1);

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000009911',true);
select is((select count(*) from public.routine_templates), 1::bigint,
 'non-admin sees only published templates');
select is((select count(*) from public.routine_template_steps), 1::bigint,
 'non-admin sees only steps of published templates');

select throws_ok($$
 insert into public.routine_templates(title,created_by)
 values('Illicit Member Template','f0000000-0000-4000-8000-000000009911')
$$,'42501','new row violates row-level security policy for table "routine_templates"',
 'member cannot create a published or draft template');

select lives_ok($$
 select public.adopt_published_routine_template(
   'f1000000-0000-4000-8000-000000009901')
$$,'member can adopt a published template into own routine');

select is((select count(*) from public.personal_routine_actions
 where title='Morning Amal'),1::bigint,
 'adoption copies the published action to owner-private actions');
select * from finish();
rollback;
