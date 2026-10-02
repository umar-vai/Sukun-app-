begin;

create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000201', 'plan-admin@sukun.test', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000211', 'plan-patient@sukun.test', '{}'::jsonb);

insert into public.user_roles (user_id, role, granted_by) values
  (
    '00000000-0000-4000-8000-000000000201',
    'super_admin',
    '00000000-0000-4000-8000-000000000201'
  ),
  (
    '00000000-0000-4000-8000-000000000211',
    'patient',
    '00000000-0000-4000-8000-000000000201'
  );

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values (
  '10000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000211',
  'TEST-PLAN-1',
  'Plan Workflow Patient',
  '00000000-0000-4000-8000-000000000201'
);

insert into public.prescriptions (
  id, patient_id, raw_text, visibility, created_by
) values (
  '20000000-0000-4000-8000-000000000201',
  '10000000-0000-4000-8000-000000000201',
  'Read the explicitly prescribed text every morning.',
  'patient',
  '00000000-0000-4000-8000-000000000201'
);

insert into public.content_items (
  id, type, title, slug, visibility, status, created_by, updated_by,
  published_at
) values (
  '60000000-0000-4000-8000-000000000201',
  'audio',
  'Verified care resource',
  'verified-care-resource',
  'assigned_only',
  'published',
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000201',
  now()
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000211',
  true
);

select throws_ok(
  $$select public.create_draft_care_plan(
    '10000000-0000-4000-8000-000000000201',
    'Patient-created plan',
    current_date,
    null,
    null,
    null,
    '70000000-0000-4000-8000-000000000201'
  )$$,
  '42501',
  'Super Admin access is required.',
  'patient cannot create a care plan through the workflow function'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);

select lives_ok(
  $$select public.create_draft_care_plan(
    '10000000-0000-4000-8000-000000000201',
    'Morning care plan',
    current_date,
    null,
    '20000000-0000-4000-8000-000000000201',
    null,
    '70000000-0000-4000-8000-000000000202'
  )$$,
  'Super Admin can create a versioned draft plan'
);
select results_eq(
  $$select count(*) from public.care_plans
    where patient_id = '10000000-0000-4000-8000-000000000201'
      and status = 'draft'$$,
  array[1::bigint],
  'one draft is created for the patient'
);
select lives_ok(
  $$select public.create_draft_care_plan(
    '10000000-0000-4000-8000-000000000201',
    'Retry payload ignored',
    current_date,
    null,
    null,
    null,
    '70000000-0000-4000-8000-000000000202'
  )$$,
  'retrying draft creation is safe'
);
select results_eq(
  $$select count(*) from public.care_plans
    where patient_id = '10000000-0000-4000-8000-000000000201'$$,
  array[1::bigint],
  'idempotent retry does not duplicate a plan'
);

select lives_ok(
  $$select public.save_plan_action(
    p_care_plan_id := (
      select id from public.care_plans
      where patient_id = '10000000-0000-4000-8000-000000000201'
        and status = 'draft'
    ),
    p_type := 'recitation',
    p_title := 'Explicit morning action',
    p_frequency_rule := '{"type":"daily","interval":1}'::jsonb,
    p_start_date := current_date,
    p_review_status := 'needs_review',
    p_request_id := '70000000-0000-4000-8000-000000000203'
  )$$,
  'an ambiguous action can be preserved as needs review'
);
select throws_ok(
  $$select public.publish_care_plan(
    (select id from public.care_plans
      where patient_id = '10000000-0000-4000-8000-000000000201'),
    '70000000-0000-4000-8000-000000000204'
  )$$,
  '22023',
  'At least one approved action is required.',
  'an unresolved draft cannot be published'
);

select lives_ok(
  $$select public.save_plan_action(
    p_care_plan_id := (
      select id from public.care_plans
      where patient_id = '10000000-0000-4000-8000-000000000201'
    ),
    p_type := 'recitation',
    p_title := 'Explicit morning action',
    p_frequency_rule := '{"type":"daily","interval":1}'::jsonb,
    p_start_date := current_date,
    p_action_id := (
      select pa.id from public.plan_actions pa
      join public.care_plans cp on cp.id = pa.care_plan_id
      where cp.patient_id = '10000000-0000-4000-8000-000000000201'
    ),
    p_review_status := 'approved',
    p_content_item_id := '60000000-0000-4000-8000-000000000201',
    p_request_id := '70000000-0000-4000-8000-000000000205'
  )$$,
  'Super Admin can approve an action and link one canonical resource'
);
select results_eq(
  $$select count(*) from public.plan_action_resources$$,
  array[1::bigint],
  'the resource is linked by relation rather than duplicated'
);
select lives_ok(
  $$select public.publish_care_plan(
    (select id from public.care_plans
      where patient_id = '10000000-0000-4000-8000-000000000201'),
    '70000000-0000-4000-8000-000000000206'
  )$$,
  'a fully reviewed plan can be published'
);
select results_eq(
  $$select status::text from public.care_plans
    where patient_id = '10000000-0000-4000-8000-000000000201'$$,
  array['active'::text],
  'published plan becomes active'
);
select results_eq(
  $$select count(*) from public.admin_audit_logs
    where action = 'care_plan.published'
      and request_id = '70000000-0000-4000-8000-000000000206'$$,
  array[1::bigint],
  'publishing is recorded in the admin audit log'
);

reset role;
select throws_ok(
  $$update public.plan_actions
    set title = 'Rewritten after publication'
    where care_plan_id = (
      select id from public.care_plans
      where patient_id = '10000000-0000-4000-8000-000000000201'
    )$$,
  '55000',
  'Published care plan actions cannot be rewritten.',
  'published action history cannot be rewritten even outside RLS'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select lives_ok(
  $$select public.create_draft_care_plan(
    '10000000-0000-4000-8000-000000000201',
    'Morning care plan',
    current_date + 1,
    null,
    null,
    (select id from public.care_plans
      where patient_id = '10000000-0000-4000-8000-000000000201'
        and status = 'active'),
    '70000000-0000-4000-8000-000000000207'
  )$$,
  'a published plan can be copied into a new versioned draft'
);
select results_eq(
  $$select max(version) from public.care_plans
    where patient_id = '10000000-0000-4000-8000-000000000201'$$,
  array[2],
  'new draft increments plan version'
);
select results_eq(
  $$select review_status::text from public.plan_actions pa
    join public.care_plans cp on cp.id = pa.care_plan_id
    where cp.patient_id = '10000000-0000-4000-8000-000000000201'
      and cp.version = 2$$,
  array['needs_review'::text],
  'copied actions must be reviewed again'
);
select results_eq(
  $$select count(*) from public.plan_action_resources par
    join public.plan_actions pa on pa.id = par.plan_action_id
    join public.care_plans cp on cp.id = pa.care_plan_id
    where cp.version = 2$$,
  array[1::bigint],
  'new plan version reuses the canonical resource relation'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000211',
  true
);
select results_eq(
  $$select count(*) from public.care_plans
    where patient_id = '10000000-0000-4000-8000-000000000201'$$,
  array[1::bigint],
  'patient sees the active plan but not the new draft version'
);
select results_eq(
  $$select count(*) from public.plan_actions pa
    join public.care_plans cp on cp.id = pa.care_plan_id
    where cp.patient_id = '10000000-0000-4000-8000-000000000201'$$,
  array[1::bigint],
  'patient sees actions from the active version only'
);

select * from finish();
rollback;
