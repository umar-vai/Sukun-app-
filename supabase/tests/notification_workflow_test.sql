begin;

create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000701', 'notification-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000000711', 'notification-patient-1@sukun.test'),
  ('00000000-0000-4000-8000-000000000712', 'notification-patient-2@sukun.test');

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000701', 'super_admin', '00000000-0000-4000-8000-000000000701'),
  ('00000000-0000-4000-8000-000000000711', 'patient', '00000000-0000-4000-8000-000000000701'),
  ('00000000-0000-4000-8000-000000000712', 'patient', '00000000-0000-4000-8000-000000000701');

insert into public.patients (
  id, user_id, patient_code, full_name, created_by
) values
  (
    '10000000-0000-4000-8000-000000000711',
    '00000000-0000-4000-8000-000000000711',
    'TEST-NOTIFY-1', 'Notification Patient One',
    '00000000-0000-4000-8000-000000000701'
  ),
  (
    '10000000-0000-4000-8000-000000000712',
    '00000000-0000-4000-8000-000000000712',
    'TEST-NOTIFY-2', 'Notification Patient Two',
    '00000000-0000-4000-8000-000000000701'
  );

insert into public.care_plans (
  id, patient_id, version, name, start_date, status,
  published_at, published_by, created_by
) values (
  '30000000-0000-4000-8000-000000000711',
  '10000000-0000-4000-8000-000000000711',
  1, 'Notification plan', current_date, 'active', now(),
  '00000000-0000-4000-8000-000000000701',
  '00000000-0000-4000-8000-000000000701'
);

insert into public.plan_actions (
  id, care_plan_id, type, title, frequency_rule, exact_time,
  start_date, sort_order, review_status, reminder_enabled, created_by
) values
  (
    '40000000-0000-4000-8000-000000000711',
    '30000000-0000-4000-8000-000000000711',
    'amal', 'Approved exact reminder', '{"type":"daily","interval":1}',
    '09:00', current_date, 0, 'approved', true,
    '00000000-0000-4000-8000-000000000701'
  ),
  (
    '40000000-0000-4000-8000-000000000712',
    '30000000-0000-4000-8000-000000000711',
    'amal', 'No invented time', '{"type":"daily","interval":1}',
    null, current_date, 1, 'approved', true,
    '00000000-0000-4000-8000-000000000701'
  ),
  (
    '40000000-0000-4000-8000-000000000713',
    '30000000-0000-4000-8000-000000000711',
    'amal', 'Not approved', '{"type":"daily","interval":1}',
    '10:00', current_date, 2, 'needs_review', true,
    '00000000-0000-4000-8000-000000000701'
  ),
  (
    '40000000-0000-4000-8000-000000000714',
    '30000000-0000-4000-8000-000000000711',
    'amal', 'Reminder disabled', '{"type":"daily","interval":1}',
    '11:00', current_date, 3, 'approved', false,
    '00000000-0000-4000-8000-000000000701'
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000711', true);

select lives_ok(
  $$select * from public.ensure_patient_reminder_tasks(current_date, current_date + 2, 0)$$,
  'patient can generate a bounded notification horizon'
);
select results_eq(
  $$select count(*) from public.task_instances
    where patient_id = '10000000-0000-4000-8000-000000000711'$$,
  array[3::bigint],
  'only the approved exact-time reminder creates occurrences'
);
select results_eq(
  $$select count(*) from public.task_instances where scheduled_at is null$$,
  array[0::bigint],
  'reminder generation never invents a missing exact time'
);
select throws_ok(
  $$select * from public.ensure_patient_reminder_tasks(current_date, current_date + 31, 0)$$,
  '22023',
  'Reminder tasks may only be generated for the next 31 days.',
  'patient cannot generate an unbounded reminder horizon'
);

select lives_ok(
  $$select public.register_notification_device(
    'install-1', 'android', 'test-fcm-token-1', 'Asia/Dhaka'
  )$$,
  'patient can register the current installation'
);
select results_eq(
  $$select patient_id::text, platform::text, is_active::text
    from public.notification_devices$$,
  $$values (
    '10000000-0000-4000-8000-000000000711'::text,
    'android'::text,
    'true'::text
  )$$,
  'device ownership is derived from the authenticated patient'
);
select lives_ok(
  $$select public.register_notification_device(
    'install-1', 'android', 'test-fcm-token-2', 'Asia/Dhaka'
  )$$,
  'token refresh updates the same installation'
);
select results_eq(
  $$select count(*) from public.notification_devices$$,
  array[1::bigint],
  'token refresh does not create a duplicate installation'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000712', true);
select results_eq(
  $$select count(*) from public.notification_devices$$,
  array[0::bigint],
  'another patient cannot read the first patient device'
);
select results_eq(
  $$select count(*) from public.task_instances$$,
  array[0::bigint],
  'another patient cannot read the first patient reminder tasks'
);
select throws_ok(
  $$select public.register_notification_device(
    'stolen-install', 'ios', 'test-fcm-token-2', 'Asia/Dhaka'
  )$$,
  '42501',
  'This device token belongs to another account.',
  'another patient cannot take over an existing device token'
);
select results_eq(
  $$select count(*) from public.notification_devices$$,
  array[0::bigint],
  'failed token takeover does not expose or register a device'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000701', true);
select lives_ok(
  $$insert into public.notification_events (
    patient_id, plan_action_id, scheduled_at, notification_type, status
  ) values (
    '10000000-0000-4000-8000-000000000711',
    '40000000-0000-4000-8000-000000000711', now() + interval '1 day',
    'care_reminder', 'scheduled'
  )$$,
  'admin can create a server-side notification event'
);
select lives_ok(
  $$update public.care_plans
    set status = 'inactive'
    where id = '30000000-0000-4000-8000-000000000711'$$,
  'deactivating a plan cancels its future notification state'
);
select results_eq(
  $$select count(*) from public.task_instances where status <> 'cancelled'$$,
  array[0::bigint],
  'future task reminders from the inactive plan are cancelled'
);
select results_eq(
  $$select status::text from public.notification_events$$,
  array['cancelled'::text],
  'scheduled backend notification events from the inactive plan are cancelled'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000711', true);
select ok(
  public.remove_notification_device('install-1'),
  'patient can remove their own installation'
);
select results_eq(
  $$select count(*) from public.notification_devices$$,
  array[0::bigint],
  'removed device is no longer registered'
);

select * from finish();
rollback;
