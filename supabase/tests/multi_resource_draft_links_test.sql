-- Synthetic, rollback-only pgTAP acceptance for Smart Prescription multi-links.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);
insert into auth.users(id,email,raw_user_meta_data) values
 ('e0000000-0000-4000-8000-000000000611','qa-resource-admin@invalid.test','{}'::jsonb),
 ('e0000000-0000-4000-8000-000000000612','qa-resource-patient@invalid.test','{}'::jsonb);
insert into public.user_roles(user_id,role,granted_by) values
 ('e0000000-0000-4000-8000-000000000611','super_admin','e0000000-0000-4000-8000-000000000611'),
 ('e0000000-0000-4000-8000-000000000612','patient','e0000000-0000-4000-8000-000000000611');
insert into public.patients(id,user_id,patient_code,full_name,created_by) values
 ('e1000000-0000-4000-8000-000000000611','e0000000-0000-4000-8000-000000000612','QA-SYN-RESOURCE-611','Synthetic multi-resource patient','e0000000-0000-4000-8000-000000000611');
insert into public.care_plans(id,patient_id,version,name,start_date,status,created_by) values
 ('e2000000-0000-4000-8000-000000000611','e1000000-0000-4000-8000-000000000611',1,'Synthetic multi-resource plan',current_date,'draft','e0000000-0000-4000-8000-000000000611');
insert into public.plan_actions(id,care_plan_id,type,title,frequency_rule,time_window,start_date,sort_order,review_status,reminder_enabled,created_by) values
 ('e3000000-0000-4000-8000-000000000611','e2000000-0000-4000-8000-000000000611','dua','Synthetic approved dua','{"type":"daily","interval":1}'::jsonb,'morning',current_date,0,'draft',false,'e0000000-0000-4000-8000-000000000611');
insert into public.content_items(id,type,title,slug,status,published_at,visibility,created_by,updated_by) values
 ('e4000000-0000-4000-8000-000000000611','dua','Synthetic Dua A','qa-resource-a-611','published',now(),'public','e0000000-0000-4000-8000-000000000611','e0000000-0000-4000-8000-000000000611'),
 ('e4000000-0000-4000-8000-000000000612','amal','Synthetic Amal B','qa-resource-b-612','published',now(),'patient_only','e0000000-0000-4000-8000-000000000611','e0000000-0000-4000-8000-000000000611'),
 ('e4000000-0000-4000-8000-000000000613','dua','Private staff source','qa-resource-private-613','published',now(),'staff_only','e0000000-0000-4000-8000-000000000611','e0000000-0000-4000-8000-000000000611');
insert into public.plan_action_resources(plan_action_id,content_item_id,usage_note,created_by) values
 ('e3000000-0000-4000-8000-000000000611','e4000000-0000-4000-8000-000000000612','Read after the approved instruction','e0000000-0000-4000-8000-000000000611');
select ok(not has_function_privilege('anon','public.replace_draft_action_resources(uuid,uuid[],uuid)','EXECUTE'),'anon cannot invoke');
set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-4000-8000-000000000611',true);
select lives_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000611'::uuid,'e4000000-0000-4000-8000-000000000612'::uuid],'e5000000-0000-4000-8000-000000000611')$$,'admin links two resources');
select results_eq($$select count(*) from public.plan_action_resources where plan_action_id='e3000000-0000-4000-8000-000000000611'$$,array[2::bigint],'both links exist');
select results_eq($$select content_item_id::text from public.plan_action_resources where plan_action_id='e3000000-0000-4000-8000-000000000611' order by sort_order$$,array['e4000000-0000-4000-8000-000000000611','e4000000-0000-4000-8000-000000000612'],'requested order is saved');
select results_eq($$select usage_note from public.plan_action_resources where plan_action_id='e3000000-0000-4000-8000-000000000611' and content_item_id='e4000000-0000-4000-8000-000000000612'$$,array['Read after the approved instruction'],'edited usage note survives replacement');
select lives_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000612'::uuid,'e4000000-0000-4000-8000-000000000611'::uuid],'e5000000-0000-4000-8000-000000000611')$$,'same request and reordered list is idempotent');
select throws_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000611'::uuid],'e5000000-0000-4000-8000-000000000611')$$,'22023','A request ID cannot be reused with different resources.','replay with different resources rejected');
select throws_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000611'::uuid,'e4000000-0000-4000-8000-000000000611'::uuid],'e5000000-0000-4000-8000-000000000612')$$,'22023','Resource IDs must be unique and contain at most 16 items.','duplicate resources rejected');
select throws_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000613'::uuid],'e5000000-0000-4000-8000-000000000613')$$,'22023','Only approved patient-accessible resources can be linked.','staff-only content blocked');
select lives_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000612'::uuid,'e4000000-0000-4000-8000-000000000611'::uuid],'e5000000-0000-4000-8000-000000000616')$$,'new request may reorder draft resources');
select results_eq($$select content_item_id::text from public.plan_action_resources where plan_action_id='e3000000-0000-4000-8000-000000000611' order by sort_order$$,array['e4000000-0000-4000-8000-000000000612','e4000000-0000-4000-8000-000000000611'],'new order is saved');
select set_config('request.jwt.claim.sub','e0000000-0000-4000-8000-000000000612',true);
select throws_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000611'::uuid],'e5000000-0000-4000-8000-000000000614')$$,'42501','Super Admin access is required.','patient cannot mutate links');
reset role;
update public.care_plans set status='active',published_at=now(),published_by='e0000000-0000-4000-8000-000000000611' where id='e2000000-0000-4000-8000-000000000611';
set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-4000-8000-000000000611',true);
select throws_ok($$select public.replace_draft_action_resources('e3000000-0000-4000-8000-000000000611',array['e4000000-0000-4000-8000-000000000611'::uuid],'e5000000-0000-4000-8000-000000000615')$$,'P0002','An editable draft action was not found.','published action links immutable');
select 1/(case when exists(select 1 from finish()) then 0 else 1 end) as all_resource_assertions_passed;
rollback;
