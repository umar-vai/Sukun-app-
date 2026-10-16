-- Synthetic-only Web Push acceptance. All rows rolled back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id,email) values
 ('f0000000-0000-4000-8000-000000000901','web-push-admin@invalid.test'),
 ('f0000000-0000-4000-8000-000000000902','web-push-patient@invalid.test');
insert into public.user_roles (user_id,role,granted_by) values
 ('f0000000-0000-4000-8000-000000000901','super_admin','f0000000-0000-4000-8000-000000000901'),
 ('f0000000-0000-4000-8000-000000000902','patient','f0000000-0000-4000-8000-000000000901');
insert into public.patients (id,user_id,patient_code,full_name,created_by)
values ('f1000000-0000-4000-8000-000000000901',
 'f0000000-0000-4000-8000-000000000902','SYN-WEB-PUSH-901',
 'Synthetic Web Push Patient','f0000000-0000-4000-8000-000000000901');
insert into public.care_plans(id,patient_id,version,name,start_date,status,published_at,published_by,created_by)
values ('f2000000-0000-4000-8000-000000000901','f1000000-0000-4000-8000-000000000901',
1,'Synthetic approved plan',current_date,'active',now(),
'f0000000-0000-4000-8000-000000000901','f0000000-0000-4000-8000-000000000901');
insert into public.plan_actions(id,care_plan_id,type,title,frequency_rule,start_date,sort_order,review_status,reminder_enabled,exact_time,created_by)
values
 ('f3000000-0000-4000-8000-000000000901','f2000000-0000-4000-8000-000000000901','recitation','Synthetic approved action','{"type":"daily","interval":1}'::jsonb,current_date,0,'approved',true,'09:00','f0000000-0000-4000-8000-000000000901'),
 ('f3000000-0000-4000-8000-000000000902','f2000000-0000-4000-8000-000000000901','recitation','Synthetic unreviewed action','{"type":"daily","interval":1}'::jsonb,current_date,1,'needs_review',true,'09:30','f0000000-0000-4000-8000-000000000901');
insert into public.task_instances(id,plan_action_id,patient_id,scheduled_at,status,occurrence_date,timezone_offset_minutes)
values
 ('f4000000-0000-4000-8000-000000000901','f3000000-0000-4000-8000-000000000901','f1000000-0000-4000-8000-000000000901',now()-interval '2 minutes','pending',current_date,360),
 ('f4000000-0000-4000-8000-000000000902','f3000000-0000-4000-8000-000000000902','f1000000-0000-4000-8000-000000000901',now()-interval '2 minutes','pending',current_date,360);

select ok(
 exists(select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='device_platform' and e.enumlabel='web'),
 'Web device enum is installed'
);
select ok(
 not has_function_privilege('authenticated','public.claim_due_web_care_reminders(integer)','EXECUTE'),
 'Authenticated browser cannot call privileged dispatch'
);
set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000902',true);
select lives_ok(
 $$select public.register_notification_device('synthetic-web-install','web','synthetic-fcm-web-token','Asia/Dhaka')$$,
 'Signed-in patient may opt into Web Push'
);
select throws_ok(
 $$select count(*) from public.claim_due_web_care_reminders(10)$$,
 '42501', 'permission denied for function claim_due_web_care_reminders',
 'Patient cannot claim notification queue'
);
reset role;
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select results_eq(
 $$select count(*) from public.claim_due_web_care_reminders(10)$$,
 array[1::bigint],
 'Only the approved pending task receives one Web delivery claim'
);
select results_eq(
 $$select count(*) from public.claim_due_web_care_reminders(10)$$,
 array[0::bigint],
 'Immediate repeat dispatch is idempotent'
);
select results_eq(
 $$select count(*) from public.notification_events where notification_type='care_reminder' and attempt_count=1$$,
 array[1::bigint],
 'Claim records one auditable attempt'
);
select results_eq(
 $$select count(*) from public.notification_events where task_instance_id='f4000000-0000-4000-8000-000000000902'$$,
 array[0::bigint],
 'Unreviewed clinical action is never eligible'
);
update public.task_instances set status='completed' where id='f4000000-0000-4000-8000-000000000901';
select results_eq(
 $$select count(*) from public.claim_due_web_care_reminders(10)$$,
 array[0::bigint],
 'Completed task cannot be dispatched again'
);
select 1/(case when exists(select 1 from finish()) then 0 else 1 end) as all_nine_web_push_security_assertions_passed;
rollback;
