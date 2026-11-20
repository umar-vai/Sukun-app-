-- CRM/ERP integration core: mapping, prescription events, outbox, progress.
begin;

create extension if not exists pgtap with schema extensions;
select plan(61);

insert into auth.users (id, phone, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000b01', '+8801700000b01', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000b02', '+8801700000b02', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000b03', '+8801700000b03', '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000b04', '+8801700000b04', '{}'::jsonb);
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000b01', 'super_admin', '00000000-0000-4000-8000-000000000b01'),
  ('00000000-0000-4000-8000-000000000b02', 'patient', '00000000-0000-4000-8000-000000000b01'),
  ('00000000-0000-4000-8000-000000000b03', 'patient', '00000000-0000-4000-8000-000000000b01'),
  ('00000000-0000-4000-8000-000000000b04', 'patient', '00000000-0000-4000-8000-000000000b01');
insert into public.patients (id, user_id, patient_code, full_name, created_by) values
  ('10000000-0000-4000-8000-0000000ba001', '00000000-0000-4000-8000-000000000b02', 'CRM-T1', 'Owner One', '00000000-0000-4000-8000-000000000b01'),
  ('10000000-0000-4000-8000-0000000ba002', null, 'CRM-T2', 'Child Two', '00000000-0000-4000-8000-000000000b01'),
  ('10000000-0000-4000-8000-0000000ba003', '00000000-0000-4000-8000-000000000b03', 'CRM-T3', 'No CRM Link', '00000000-0000-4000-8000-000000000b01'),
  ('10000000-0000-4000-8000-0000000ba004', '00000000-0000-4000-8000-000000000b04', 'CRM-T4', 'Late Mapped', '00000000-0000-4000-8000-000000000b01');

create function pg_temp.apply(e jsonb) returns jsonb language sql as $$
  select public.integration_apply_prescription_event('00000000-0000-4000-8000-000000000b01', e)
$$;

-- Helper: build a prescription event.
create function pg_temp.ev(
  eid text, etype text, ver int, items jsonb, crm_pat text default 'CRM-P-1',
  crm_fam text default null
) returns jsonb language sql as $$
  select jsonb_build_object(
    'schema_version', '1.0', 'event_id', eid, 'event_type', etype,
    'patient', jsonb_strip_nulls(jsonb_build_object('crm_patient_id', crm_pat, 'crm_family_id', crm_fam)),
    'prescription', jsonb_build_object('crm_prescription_id', 'RX-100', 'version', ver,
      'status', 'issued', 'start_date', current_date::text, 'timezone', 'Asia/Dhaka'),
    'items', items)
$$;
create function pg_temp.item(iid text, tpl text, extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('item_id', iid, 'template_id', tpl,
    'frequency', '{"type":"daily","interval":1}'::jsonb,
    'reminder_times', '["07:00","18:00"]'::jsonb) || extra
$$;

select lives_ok($$select public.integration_link_patient('00000000-0000-4000-8000-000000000b01', '10000000-0000-4000-8000-0000000ba001', 'CRM-P-1', 'CRM-C-1', 'CRM-F-1')$$, 'owner profile is linked to CRM ids and creates the CRM family');
select lives_ok($$select public.integration_link_patient('00000000-0000-4000-8000-000000000b01', '10000000-0000-4000-8000-0000000ba002', 'CRM-P-2', 'CRM-C-1', 'CRM-F-1', 'child')$$, 'second profile joins the same CRM family');
select results_eq($$select count(*) from public.family_members fm join public.family_accounts fa on fa.id = fm.family_id where fa.crm_family_id = 'CRM-F-1' and fm.unlinked_at is null$$, array[2::bigint], 'family now has two linked profiles');
select throws_ok($$select public.integration_link_patient('00000000-0000-4000-8000-000000000b01', '10000000-0000-4000-8000-0000000ba003', 'CRM-P-1')$$, '23505', null, 'a CRM patient id can never be linked to a second profile');
select throws_ok($$select public.integration_link_patient('00000000-0000-4000-8000-000000000b01', '10000000-0000-4000-8000-0000000ba001', 'CRM-P-OTHER')$$, '23505', null, 'a profile cannot be re-pointed to a different CRM patient');
select throws_ok($$select public.integration_link_patient('00000000-0000-4000-8000-000000000b01', '10000000-0000-4000-8000-0000000ba003', 'CRM-P-3', null, 'CRM-F-1')$$, '23505', null, 'a profile with its own login cannot join a family silently');

-- Issue v1.
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-1', 'prescription.issued', 1, jsonb_build_array(pg_temp.item('L1', 'a01'))))) ->> 'status'$$,
  array['applied'::text], 'a final prescription is applied');
select results_eq($$select count(*) from public.plan_actions pa join public.care_plans cp on cp.id = pa.care_plan_id where cp.patient_id = '10000000-0000-4000-8000-0000000ba001' and cp.status = 'active' and pa.review_status = 'approved' and pa.reminder_enabled$$, array[2::bigint], 'one action per reminder time, approved with reminders');
select results_eq($$select count(*) from public.prescriptions where source_external_id = 'RX-100' and source_type = 'imported'$$, array[1::bigint], 'one prescription row keyed by the CRM prescription id');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-1', 'prescription.issued', 1, jsonb_build_array(pg_temp.item('L1', 'a01'))))) ->> 'replayed'$$,
  array['true'::text], 'the same event is replayed safely');
select results_eq($$select count(*) from public.care_plans where patient_id = '10000000-0000-4000-8000-0000000ba001'$$, array[1::bigint], 'replay does not create a second plan');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-1', 'prescription.issued', 1, jsonb_build_array(pg_temp.item('L1', 'a02'))))) ->> 'code'$$,
  array['event_id_reuse_conflict'::text], 'an event id reused with different content is refused');

-- Unmapped patient, family mismatch.
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-unmapped', 'prescription.issued', 1, jsonb_build_array(pg_temp.item('L1', 'a01')), 'CRM-P-LATE'))) ->> 'code'$$,
  array['patient_not_mapped'::text], 'an unmapped CRM patient is rejected, never guessed');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-fam', 'prescription.issued', 5, jsonb_build_array(pg_temp.item('L1', 'a01')), 'CRM-P-1', 'CRM-F-OTHER'))) ->> 'code'$$,
  array['family_mismatch'::text], 'a conflicting CRM family id is rejected');

-- Revision v2 replaces the plan, history kept.
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-2', 'prescription.updated', 2, jsonb_build_array(pg_temp.item('L1', 'a01', '{"reminder_times":["06:00"]}'))))) ->> 'status'$$,
  array['applied'::text], 'a revision is applied');
select results_eq($$select count(*) from public.care_plans where patient_id = '10000000-0000-4000-8000-0000000ba001' and status = 'active'$$, array[1::bigint], 'exactly one active plan after revision');
select results_eq($$select count(*) from public.care_plans where patient_id = '10000000-0000-4000-8000-0000000ba001' and status = 'inactive'$$, array[1::bigint], 'the previous plan is kept as history');
select results_eq($$select count(*) from public.prescription_versions pv join public.prescriptions p on p.id = pv.prescription_id where p.source_external_id = 'RX-100'$$, array[2::bigint], 'both prescription versions are preserved');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-old', 'prescription.updated', 1, jsonb_build_array(pg_temp.item('L1', 'a02'))))) ->> 'status'$$,
  array['stale'::text], 'an older version arriving late never overwrites the newer one');
select results_eq($$select count(*) from public.care_plans where patient_id = '10000000-0000-4000-8000-0000000ba001'$$, array[2::bigint], 'stale event created no plan');

-- Clinical safety: never guess.
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-nocount', 'prescription.updated', 3, jsonb_build_array(
    pg_temp.item('L1', (select id from public.care_templates where instruction like '%{বার}%' order by id limit 1)))))) ->> 'code'$$,
  array['missing_parameter'::text], 'a template that needs a count is rejected when the count is missing');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-nofreq', 'prescription.updated', 3, jsonb_build_array(
    pg_temp.item('L1', 'a01') - 'frequency')))) ->> 'code'$$, array['missing_frequency'::text], 'a missing frequency is rejected');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-notimes', 'prescription.updated', 3, jsonb_build_array(
    pg_temp.item('L1', 'a01') - 'reminder_times')))) ->> 'code'$$, array['missing_reminder_times'::text], 'missing reminder times are rejected, not defaulted');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-badtpl', 'prescription.updated', 3, jsonb_build_array(pg_temp.item('L1', 'z99'))))) ->> 'code'$$,
  array['template_not_found'::text], 'an unknown template is rejected');
select results_eq($$select count(*) from public.care_plans where patient_id = '10000000-0000-4000-8000-0000000ba001'$$, array[2::bigint], 'rejected events leave no partial plan behind');
select results_eq($$select count(*) from public.integration_inbox where status = 'rejected'$$, array[6::bigint], 'every rejection is recorded for reconciliation');

-- A count supplied makes the same template valid, and renders the number.
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-count', 'prescription.updated', 3, jsonb_build_array(
    pg_temp.item('L1', (select id from public.care_templates where instruction like '%{বার}%' order by id limit 1), '{"count": 7}'))))) ->> 'status'$$,
  array['applied'::text], 'the same template applies when the count is explicit');
select results_eq($$select count(*) from public.plan_actions pa join public.care_plans cp on cp.id = pa.care_plan_id where cp.status = 'active' and cp.patient_id = '10000000-0000-4000-8000-0000000ba001' and pa.instruction like '%7%' and pa.instruction not like '%{%' and pa.count_target = 7$$, array[2::bigint], 'placeholders are replaced by the explicit count');

-- A rejected event is retried successfully after mapping.
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-late', 'prescription.issued', 1, jsonb_build_array(pg_temp.item('L1', 'a01')), 'CRM-P-LATE'))) ->> 'code'$$,
  array['patient_not_mapped'::text], 'late patient first rejected');
select lives_ok($$select public.integration_link_patient('00000000-0000-4000-8000-000000000b01', '10000000-0000-4000-8000-0000000ba004', 'CRM-P-LATE')$$, 'late patient gets mapped');
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-late', 'prescription.issued', 1, jsonb_build_array(pg_temp.item('L1', 'a01')), 'CRM-P-LATE'))) ->> 'status'$$,
  array['applied'::text], 'the same event applies after the mapping exists');

-- The service role (and only it) can run the integration functions.
set local role service_role;
select lives_ok($$select public.integration_export_template_catalog(null, null, 1)$$, 'service role can export the catalog');
select lives_ok($$select public.integration_patient_progress('CRM-P-1', current_date, current_date)$$, 'service role can read progress');
reset role;

-- Authorization of the service actor.
select throws_ok($$select public.integration_apply_prescription_event('00000000-0000-4000-8000-000000000b02', pg_temp.ev('evt-x', 'prescription.issued', 1, '[]'::jsonb))$$, '42501', null, 'a non-staff actor is refused');

-- Progress to outbox: only CRM-linked patients are exported.
reset role;
insert into public.care_plans (id, patient_id, version, name, start_date, status, published_at, published_by, created_by)
values ('30000000-0000-4000-8000-0000000bb003', '10000000-0000-4000-8000-0000000ba003', 1, 'Unlinked', current_date - 1, 'active', now(),
  '00000000-0000-4000-8000-000000000b01', '00000000-0000-4000-8000-000000000b01');
insert into public.plan_actions (id, care_plan_id, type, title, frequency_rule, start_date, review_status, created_by)
values ('40000000-0000-4000-8000-0000000bb003', '30000000-0000-4000-8000-0000000bb003', 'amal', 'Plain', '{"type":"daily","interval":1}', current_date - 1, 'approved', '00000000-0000-4000-8000-000000000b01');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000b02', true);
select lives_ok($$select * from public.ensure_patient_tasks(current_date, 0)$$, 'CRM-linked patient generates today tasks');
select lives_ok(format('select public.record_task_completion(%L, %L, %L)',
  (select id from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000ba001' order by id limit 1),
  'completed', '70000000-0000-4000-8000-0000000bd001'), 'patient completes a task');
select lives_ok(format('select public.record_task_completion(%L, %L, %L)',
  (select id from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000ba001' order by id limit 1),
  'completed', '70000000-0000-4000-8000-0000000bd001'), 'the same completion replayed');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000b03', true);
select lives_ok($$select * from public.ensure_patient_tasks(current_date, 0)$$, 'non-CRM patient generates tasks');
select lives_ok(format('select public.record_task_completion(%L, %L, %L)',
  (select id from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000ba003' limit 1),
  'completed', '70000000-0000-4000-8000-0000000bd002'), 'non-CRM patient completes a task');

-- App roles can never touch the integration surface.
select throws_ok($$select * from public.integration_inbox$$, '42501', null, 'authenticated users cannot read the inbox');
select throws_ok($$select * from public.integration_outbox$$, '42501', null, 'authenticated users cannot read the outbox');
select throws_ok($$select public.integration_export_template_catalog()$$, '42501', null, 'authenticated users cannot export the catalog');
select throws_ok($$select public.integration_apply_prescription_event('00000000-0000-4000-8000-000000000b01', '{}'::jsonb)$$, '42501', null, 'authenticated users cannot import prescriptions');
reset role;
set local role anon;
select throws_ok($$select public.integration_patient_progress('CRM-P-1', current_date, current_date)$$, '42501', null, 'anon cannot read progress');
reset role;

select results_eq($$select count(*) from public.integration_outbox$$, array[1::bigint], 'only the CRM-linked completion is queued, replay did not duplicate it');
select results_eq($$select event_type from public.integration_outbox$$, array['progress.task_completed'::text], 'the queued event describes the completion');
select results_eq($$select payload ->> 'crm_patient_id' from public.integration_outbox$$, array['CRM-P-1'::text], 'the event carries the CRM patient id');
select ok((select payload::text not like '%Owner One%' and payload::text not like '%+88017%' from public.integration_outbox), 'the event carries no name or phone');

select results_eq($$select count(*) from public.integration_claim_outbox(10, 60)$$, array[1::bigint], 'delivery worker claims the due event');
select results_eq($$select count(*) from public.integration_claim_outbox(10, 60)$$, array[0::bigint], 'a leased event is not claimed twice');
select results_eq($$select public.integration_ack_outbox(array(select id from public.integration_outbox))$$, array[1], 'acknowledgement marks it sent');
reset role;
insert into public.integration_outbox (event_type, patient_id, dedupe_key, payload, attempts)
values ('progress.task_skipped', null, 'test:fail:1', '{}', 1), ('progress.task_skipped', null, 'test:fail:2', '{}', 12);
select results_eq($$select public.integration_fail_outbox(id, 'timeout') from public.integration_outbox where dedupe_key = 'test:fail:1'$$, array['pending'::text], 'a failed delivery is retried later');
select results_eq($$select public.integration_fail_outbox(id, 'timeout') from public.integration_outbox where dedupe_key = 'test:fail:2'$$, array['dead'::text], 'after too many attempts the event is dead-lettered');

select results_eq($$select (public.integration_patient_progress('CRM-P-1', current_date, current_date)) -> 'totals' ->> 'adherence_percent'$$, array['50.0'::text], 'CRM progress uses the one authoritative adherence calculation');
select results_eq($$select (public.integration_patient_progress('CRM-P-1', current_date, current_date)) -> 'totals' ->> 'completed'$$, array['1'::text], 'completed count matches the app');
select throws_ok($$select public.integration_patient_progress('CRM-NOBODY', current_date, current_date)$$, 'P0002', null, 'progress for an unlinked id is refused');

-- Cancellation keeps history and stops future work.
select results_eq($$select (pg_temp.apply(pg_temp.ev('evt-cancel', 'prescription.cancelled', 4, '[]'::jsonb))) ->> 'status'$$, array['applied'::text], 'a cancellation is applied');
reset role;
select results_eq($$select count(*) from public.care_plans where patient_id = '10000000-0000-4000-8000-0000000ba001' and status = 'active'$$, array[0::bigint], 'no active plan remains after cancellation');
select results_eq($$select count(*) from public.task_instances where patient_id = '10000000-0000-4000-8000-0000000ba001' and status = 'cancelled'$$, array[1::bigint], 'the pending task was cancelled, the completed one kept');
select results_eq($$select count(*) from public.task_completions where patient_id = '10000000-0000-4000-8000-0000000ba001'$$, array[1::bigint], 'completion history survives cancellation');
select ok((select archived_at is not null from public.prescriptions where source_external_id = 'RX-100' and patient_id = '10000000-0000-4000-8000-0000000ba001'), 'the prescription is archived, not deleted');

select * from finish();
rollback;
