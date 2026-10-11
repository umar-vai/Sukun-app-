begin;

-- Phase 1 privileged RPC negative gate. Synthetic member; disposable CI only.
-- All operations roll back. This file deliberately exercises public RPC
-- authorization rather than hiding SECURITY DEFINER warnings with revoked
-- grants that would break existing patient/admin workflows.
create extension if not exists pgtap with schema extensions;
select plan(15);

select results_eq(
  $$select count(*) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'admin_search_patients', 'create_prescription',
        'create_prescription_attachment', 'ensure_patient_reminder_tasks',
        'ensure_patient_tasks', 'record_task_completion',
        'register_notification_device', 'remove_notification_device'
      )
      and p.prosecdef$$,
  array[8::bigint],
  'All eight reviewed privileged RPCs are explicitly inventoried'
);

select results_eq(
  $$select count(*) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'admin_search_patients', 'create_prescription',
        'create_prescription_attachment', 'ensure_patient_reminder_tasks',
        'ensure_patient_tasks', 'record_task_completion',
        'register_notification_device', 'remove_notification_device'
      )
      and has_function_privilege('anon', p.oid, 'EXECUTE')$$,
  array[0::bigint],
  'None of the privileged RPCs is directly executable as anon'
);

select results_eq(
  $$select count(*) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'admin_search_patients', 'create_prescription',
        'create_prescription_attachment', 'ensure_patient_reminder_tasks',
        'ensure_patient_tasks', 'record_task_completion',
        'register_notification_device', 'remove_notification_device'
      )
      and p.proconfig::text like '%search_path=%'$,
  array[8::bigint],
  'All eight SECURITY DEFINER RPCs use an empty trusted search_path'
);

-- This user has misleading self-editable metadata. Real authorization must
-- still use server-controlled public.user_roles, never raw_user_meta_data.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000f631',
   'phase1-rpc-member@example.com', '{"role":"super_admin"}'::jsonb);

select ok(
  exists (select 1 from public.user_roles
    where user_id = '00000000-0000-4000-8000-00000000f631'
      and role = 'member')
  and not exists (select 1 from public.user_roles
    where user_id = '00000000-0000-4000-8000-00000000f631'
      and role = 'super_admin'),
  'Forged Auth user_metadata cannot confer the super_admin role'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-00000000f631', true
);

select throws_ok(
  $$select * from public.admin_search_patients(null, 10, 0)$$,
  '42501', 'Super Admin access is required.',
  'Member cannot search private patient directory via SECURITY DEFINER'
);
select throws_ok(
  $$select public.create_prescription(
    '10000000-0000-4000-8000-00000000f631',
    'Synthetic unauthorized write', current_date, 'patient',
    '70000000-0000-4000-8000-00000000f631')$$,
  '42501', 'Super Admin access is required.',
  'Member cannot create a prescription through privileged RPC'
);
select throws_ok(
  $$select public.create_prescription_attachment(
    '10000000-0000-4000-8000-00000000f631',
    'synthetic.pdf', 'application/pdf', 1024, current_date, 'patient',
    '70000000-0000-4000-8000-00000000f632')$$,
  '42501', 'Super Admin access is required.',
  'Member cannot create a prescription attachment via privileged RPC'
);
select throws_ok(
  $$select * from public.ensure_patient_tasks(current_date, 0)$$,
  '42501', 'An active patient account is required.',
  'General Member cannot generate Patient daily tasks'
);
select throws_ok(
  $$select * from public.ensure_patient_reminder_tasks(
    current_date, current_date, 0)$$,
  '42501', 'An active patient account is required.',
  'General Member cannot generate Patient reminders'
);
select throws_ok(
  $$select public.record_task_completion(
    '50000000-0000-4000-8000-00000000f631',
    'completed', '70000000-0000-4000-8000-00000000f633')$$,
  '42501', 'An active patient account is required.',
  'General Member cannot complete another Patient task'
);
select throws_ok(
  $$select public.register_notification_device(
    'synthetic-member', 'android', 'synthetic-token', 'Asia/Dhaka')$$,
  '42501', 'An active patient account is required.',
  'General Member cannot register a patient push token'
);
select is(
  public.remove_notification_device('synthetic-nonexistent-installation'),
  false,
  'Device removal has no effects for an unlinked general Member'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$select * from public.admin_search_patients(null, 10, 0)$$,
  '28000', 'Authentication is required.',
  'Missing JWT identity cannot invoke admin privileged RPC'
);
select throws_ok(
  $$select public.remove_notification_device('synthetic-installation')$$,
  '28000', 'Authentication is required.',
  'Missing JWT identity cannot invoke patient device deletion'
);

reset role;
select results_eq(
  $$select count(*) from public.admin_audit_logs
    where actor_user_id='00000000-0000-4000-8000-00000000f631'$$,
  array[0::bigint],
  'Denied synthetic privileged RPCs create no admin audit side effects'
);

select * from finish();
rollback;
