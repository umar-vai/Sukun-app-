begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000006001', 'bulk-admin@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000006002', 'bulk-patient@sukun.test', '{}'),
  ('00000000-0000-4000-8000-000000006003', 'bulk-other@sukun.test', '{}');
insert into public.user_roles (user_id, role) values
  ('00000000-0000-4000-8000-000000006001', 'super_admin'),
  ('00000000-0000-4000-8000-000000006002', 'patient'),
  ('00000000-0000-4000-8000-000000006003', 'patient');
insert into public.patients (id, user_id, patient_code, full_name, created_by) values
  ('10000000-0000-4000-8000-000000006002', '00000000-0000-4000-8000-000000006002',
   'TEST-BULK-1', 'Synthetic Bulk Patient', '00000000-0000-4000-8000-000000006001'),
  ('10000000-0000-4000-8000-000000006003', '00000000-0000-4000-8000-000000006003',
   'TEST-BULK-2', 'Synthetic Other Patient', '00000000-0000-4000-8000-000000006001');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000006001', true);
select public.create_draft_care_plan(
  '10000000-0000-4000-8000-000000006002', 'Synthetic Bulk Plan', current_date, current_date + 9
);
select set_config('test.bulk_plan_id', (select id::text from public.care_plans
  where patient_id = '10000000-0000-4000-8000-000000006002' and status = 'draft'), true);

select is(public.import_official_plan_actions(
  current_setting('test.bulk_plan_id')::uuid,
  '[{"id":"b01","title":"Synthetic bath","instruction":"Review {দিন}"},{"id":"a01","title":"Synthetic action","instruction":"Synthetic instruction"}]',
  '20000000-0000-4000-8000-000000006001'
), 2, 'one batch imports items in different categories');
select is(public.import_official_plan_actions(
  current_setting('test.bulk_plan_id')::uuid,
  '[{"id":"a01","title":"Synthetic action","instruction":"Synthetic instruction"}]',
  '20000000-0000-4000-8000-000000006002'
), 0, 'a new request cannot accidentally import an existing template');
select throws_ok($$select public.import_official_plan_actions(
  current_setting('test.bulk_plan_id')::uuid,
  (select jsonb_agg(jsonb_build_object('id','a01','title','Synthetic','instruction','Synthetic'))
    from generate_series(1, 101)),
  gen_random_uuid()
)$$, '22023', 'Choose between 1 and 100 templates.', 'oversized imports fail before mutation');
select throws_ok($$select public.import_official_plan_actions(
  current_setting('test.bulk_plan_id')::uuid,
  '[{"id":"a03","title":"Synthetic third action","instruction":"Synthetic instruction"},{"id":"invalid"}]',
  '20000000-0000-4000-8000-000000006003'
)$$, '22023', 'A template has invalid draft fields.', 'bad row rejects the entire import');
select is((select count(*)::integer from public.plan_actions
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid
    and review_status = 'needs_review' and not reminder_enabled),
  2, 'all imported actions remain private and unapproved');
select is((select count(*)::integer from public.task_instances
  where patient_id = '10000000-0000-4000-8000-000000006002'),
  0, 'import does not generate patient tasks or reminders');
select throws_ok($$select public.save_prescription_studio_action(
  jsonb_build_object(
    'p_care_plan_id', current_setting('test.bulk_plan_id'),
    'p_action_id', (select id from public.plan_actions
      where care_plan_id = current_setting('test.bulk_plan_id')::uuid and official_template_id = 'a01'),
    'p_type', 'amal', 'p_title', 'Synthetic replacement must roll back',
    'p_instruction', 'Synthetic edited instruction',
    'p_frequency_rule', '{"type":"daily","interval":1}'::jsonb,
    'p_start_date', current_date, 'p_review_status', 'needs_review',
    'p_reminder_enabled', false,
    'p_request_id', '20000000-0000-4000-8000-000000006006'
  ),
  array['90000000-0000-4000-8000-000000006006'::uuid],
  '[]', 'a01'
)$$, '22023', 'Only approved patient-accessible resources can be linked.',
  'a bad resource rejects the complete studio save');
select is((select title from public.plan_actions
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid and official_template_id = 'a01'),
  'Synthetic action', 'partial action edits are rolled back when a link fails');
select lives_ok($$select public.save_prescription_studio_action(
  jsonb_build_object(
    'p_care_plan_id', current_setting('test.bulk_plan_id'),
    'p_action_id', (select id from public.plan_actions
      where care_plan_id = current_setting('test.bulk_plan_id')::uuid and official_template_id = 'a01'),
    'p_type', 'amal', 'p_title', 'Synthetic reviewed action',
    'p_instruction', repeat('Synthetic reviewed instruction ', 1000),
    'p_frequency_rule', '{"type":"daily","interval":1}'::jsonb,
    'p_start_date', current_date, 'p_review_status', 'needs_review',
    'p_reminder_enabled', false,
    'p_request_id', '20000000-0000-4000-8000-000000006007'
  ), '{}'::uuid[], '[]', 'a01'
)$$, 'the same draft preserves a long legacy instruction with valid resource choices');
select lives_ok($$select public.update_prescription_draft_actions(
  current_setting('test.bulk_plan_id')::uuid,
  array(select id from public.plan_actions
    where care_plan_id = current_setting('test.bulk_plan_id')::uuid and official_template_id = 'a01'),
  '{"frequency":{"type":"weekly","weekdays":[1,4]},"exact_time":"08:30","reminder_enabled":true}',
  '20000000-0000-4000-8000-000000006004'
)$$, 'admin can apply structured scheduling to a subset');
select is((select count(*)::integer from public.plan_actions
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid and reminder_enabled),
  1, 'batch only changes selected rows');
select lives_ok($$select public.undo_prescription_draft_batch(
  current_setting('test.bulk_plan_id')::uuid,
  '20000000-0000-4000-8000-000000006004'
)$$, 'a batch can be undone in the draft');
select is((select count(*)::integer from public.plan_actions
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid and reminder_enabled),
  0, 'undo restores prior schedule values');
select is(cardinality(public.expand_prescription_action_schedule(
  current_setting('test.bulk_plan_id')::uuid,
  (select id from public.plan_actions where care_plan_id = current_setting('test.bulk_plan_id')::uuid
    and official_template_id = 'b01'),
  array[3,7], null, '20000000-0000-4000-8000-000000006005'
)), 2, 'the bath is split into two structured stages');
select ok((select array_agg(end_date - start_date + 1 order by start_date) = array[3,7]
    and max(start_date) = current_date + 3
  from public.plan_actions where care_plan_id = current_setting('test.bulk_plan_id')::uuid
    and official_template_id = 'b01'), 'stages are consecutive and preserve exact lengths');
select is(cardinality(public.expand_prescription_action_schedule(
  current_setting('test.bulk_plan_id')::uuid,
  (select id from public.plan_actions where care_plan_id = current_setting('test.bulk_plan_id')::uuid
    and official_template_id = 'b01' and start_date = current_date),
  array[3,7], null, '20000000-0000-4000-8000-000000006005'
)), 2, 'retrying schedule expansion returns the original action IDs');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000006002', true);
select is((select count(*)::integer from public.plan_actions
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid),
  0, 'owner cannot read their own unapproved batch');
select throws_ok($$select public.import_official_plan_actions(
  current_setting('test.bulk_plan_id')::uuid, '[]', gen_random_uuid()
)$$, '42501', 'Super Admin access is required.', 'patient cannot import');

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000006001', true);
update public.plan_actions set review_status = 'approved'
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid;
select throws_ok($$select public.publish_care_plan(current_setting('test.bulk_plan_id')::uuid)$$,
  '22023', 'Official template instructions and resources require review.',
  'an unresolved official placeholder blocks publication even if marked approved');
update public.plan_actions set instruction = 'Synthetic reviewed bath'
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid and official_template_id = 'b01';
update public.plan_actions set exact_time = '08:30', reminder_enabled = true
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid and official_template_id = 'a01';
select lives_ok($$select public.publish_care_plan(current_setting('test.bulk_plan_id')::uuid)$$,
  'reviewed plan can publish');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000006002', true);
select is((select count(*)::integer from public.plan_actions
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid),
  3, 'patient can read their approved rows');
select lives_ok($$select public.ensure_patient_tasks(current_date, 0)$$,
  'approved actions generate daily occurrences through the patient entry point');
select is((select count(*)::integer from public.task_instances
  where patient_id = '10000000-0000-4000-8000-000000006002'
    and occurrence_date = current_date), 2, 'only the current bath stage contributes to the daily denominator');
select lives_ok($$
  select public.ensure_patient_reminder_tasks(current_date, current_date + 14, 0);
  select public.ensure_patient_reminder_tasks(current_date, current_date + 14, 0);
$$, 'repeated reminder generation remains idempotent');
select is((select count(*)::integer from public.task_instances ti
  join public.plan_actions pa on pa.id = ti.plan_action_id
  where pa.care_plan_id = current_setting('test.bulk_plan_id')::uuid
    and pa.official_template_id = 'a01'), 10,
  'legacy actions with no end date remain bounded by the parent plan');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000006003', true);
select is((select count(*)::integer from public.plan_actions
  where care_plan_id = current_setting('test.bulk_plan_id')::uuid),
  0, 'another patient cannot read approved rows');
select ok(not has_function_privilege('anon', 'public.import_official_plan_actions(uuid,jsonb,uuid)', 'execute'),
  'anon cannot execute clinical import');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000006001', true);
select lives_ok($$select public.create_draft_care_plan(
  '10000000-0000-4000-8000-000000006002', 'Synthetic Version 2',
  current_date + 10, current_date + 19, null, current_setting('test.bulk_plan_id')::uuid
)$$, 'an approved version can be copied for fresh review');
select is((select count(*)::integer from public.plan_actions copy
  join public.plan_actions original on original.prescription_item_id = copy.prescription_item_id
  where original.care_plan_id = current_setting('test.bulk_plan_id')::uuid
    and copy.care_plan_id <> original.care_plan_id
    and copy.official_template_id = original.official_template_id
    and copy.start_date = original.start_date + 10
    and copy.review_status = 'needs_review'), 3, 'new draft retains lineage and relative schedules');
do $$
declare
  plan_id uuid;
begin
  plan_id := (public.create_draft_care_plan(
    '10000000-0000-4000-8000-000000006003', 'Synthetic Undo Conflict', current_date
  )).id;
  perform set_config('test.undo_plan', plan_id::text, true);
  perform public.import_official_plan_actions(plan_id,
    '[{"id":"a01","title":"Synthetic","instruction":"Synthetic"}]', gen_random_uuid());
  perform public.update_prescription_draft_actions(plan_id,
    array(select id from public.plan_actions where care_plan_id = plan_id),
    '{"remove":true}', '20000000-0000-4000-8000-000000006009');
  perform public.import_official_plan_actions(plan_id,
    '[{"id":"a01","title":"Synthetic","instruction":"Synthetic"}]', gen_random_uuid());
end;
$$;
select throws_ok($$select public.undo_prescription_draft_batch(
  current_setting('test.undo_plan')::uuid, '20000000-0000-4000-8000-000000006009'
)$$, '40001', 'The draft changed after this operation.',
  'undo cannot revive a removed template after another import');
select is((select count(*)::integer from public.plan_actions
  where care_plan_id = current_setting('test.undo_plan')::uuid and review_status <> 'rejected'),
  1, 'stale undo cannot accidentally duplicate a newly imported item');
select * from finish();
rollback;
