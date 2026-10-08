begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000801', 'inbox-admin@sukun.test'),
  ('00000000-0000-4000-8000-000000000811', 'inbox-patient-one@sukun.test'),
  ('00000000-0000-4000-8000-000000000812', 'inbox-patient-two@sukun.test');

insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000000801', 'super_admin', '00000000-0000-4000-8000-000000000801'),
  ('00000000-0000-4000-8000-000000000811', 'patient', '00000000-0000-4000-8000-000000000801'),
  ('00000000-0000-4000-8000-000000000812', 'patient', '00000000-0000-4000-8000-000000000801');

insert into public.patients (id, user_id, patient_code, full_name, created_by) values
  ('10000000-0000-4000-8000-000000000811',
   '00000000-0000-4000-8000-000000000811',
   'TEST-INBOX-1', 'Inbox Patient One',
   '00000000-0000-4000-8000-000000000801'),
  ('10000000-0000-4000-8000-000000000812',
   '00000000-0000-4000-8000-000000000812',
   'TEST-INBOX-2', 'Inbox Patient Two',
   '00000000-0000-4000-8000-000000000801');

insert into public.notification_events (
  id, patient_id, scheduled_at, notification_type, status
) values
  ('90000000-0000-4000-8000-000000000811',
   '10000000-0000-4000-8000-000000000811',
   now() - interval '1 hour', 'care_reminder', 'sent'),
  ('90000000-0000-4000-8000-000000000812',
   '10000000-0000-4000-8000-000000000812',
   now() - interval '1 hour', 'care_reminder', 'sent'),
  ('90000000-0000-4000-8000-000000000813',
   '10000000-0000-4000-8000-000000000811',
   now() + interval '1 day', 'care_reminder', 'scheduled'),
  ('90000000-0000-4000-8000-000000000814',
   '10000000-0000-4000-8000-000000000811',
   now() - interval '1 hour', 'care_reminder', 'failed');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000811', true);

select results_eq(
  $$select count(*) from public.notification_events$$,
  array[3::bigint],
  'patient 1 cannot read patient 2 notification events'
);
select results_eq(
  $$update public.notification_events set status = 'opened'
    where id = '90000000-0000-4000-8000-000000000811'
    returning id$$,
  array[]::uuid[],
  'direct patient UPDATE still blocked by RLS'
);
select ok(
  public.mark_patient_notification_opened('90000000-0000-4000-8000-000000000811'),
  'patient can mark own sent notification opened'
);
select results_eq(
  $$select status::text from public.notification_events
    where id = '90000000-0000-4000-8000-000000000811'$$,
  array['opened'::text],
  'own notification state updated'
);
select results_eq(
  $$select count(*) from public.notification_events
    where id = '90000000-0000-4000-8000-000000000811'
    and opened_at is not null$$,
  array[1::bigint],
  'reading event stamps opened_at consistently'
);
select ok(
  public.mark_patient_notification_opened('90000000-0000-4000-8000-000000000811'),
  'mark opened is idempotent'
);
select is(
  public.mark_patient_notification_opened('90000000-0000-4000-8000-000000000812'),
  false,
  'patient cannot mark another patient notification'
);
select is(
  public.mark_patient_notification_opened('90000000-0000-4000-8000-000000000813'),
  false,
  'future scheduled notifications cannot be opened'
);
select is(
  public.mark_patient_notification_opened('90000000-0000-4000-8000-000000000814'),
  false,
  'failed notifications cannot be opened'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000812', true);
select results_eq(
  $$select status::text from public.notification_events
    where id = '90000000-0000-4000-8000-000000000812'$$,
  array['sent'::text],
  'other patient event remains unread'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.mark_patient_notification_opened(
    '90000000-0000-4000-8000-000000000811')$$,
  '42501',
  null,
  'anon cannot call patient opened RPC'
);

select * from finish();
rollback;
