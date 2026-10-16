-- Web Push groundwork: opt-in FCM web installations, auditable delivery queue.
-- No production patient notifications are sent by applying this migration.
alter type public.device_platform add value if not exists 'web';

alter table public.notification_events
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz;
alter table public.notification_events
  add constraint notification_events_attempt_count_bounded
  check (attempt_count between 0 and 5);

-- A device/task pair must never receive two reminders for one occurrence,
-- even if the dispatch endpoint is retried.
create unique index if not exists notification_events_one_care_task_per_device
on public.notification_events(device_id, task_instance_id)
where notification_type = 'care_reminder'
  and device_id is not null and task_instance_id is not null;

-- Selection and claiming happen within ONE service-role transaction.
-- Dispatchers receive only device tokens and task UUIDs, never patient content.
create or replace function public.claim_due_web_care_reminders(
  p_batch_size integer default 50
)
returns table (
  event_id uuid,
  task_id uuid,
  push_token text
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Server role required.' using errcode = '42501';
  end if;
  if p_batch_size is null or p_batch_size < 1 or p_batch_size > 100 then
    raise exception 'Invalid batch size.' using errcode = '22023';
  end if;

  -- Only previously instantiated, actively approved tasks are eligible.
  -- Scheduled times come from the approved time + patient timezone, never AI
  -- or a server fallback time.
  with eligible as (
    select
      ti.id as task_id, ti.patient_id, pa.id as action_id,
      nd.id as device_id, ti.scheduled_at
    from public.task_instances ti
    join public.plan_actions pa on pa.id = ti.plan_action_id
    join public.care_plans cp on cp.id = pa.care_plan_id
    join public.notification_devices nd on nd.patient_id = ti.patient_id
    where nd.platform = 'web'
      and nd.is_active
      and ti.status in ('pending', 'snoozed')
      and cp.status = 'active'
      and cp.patient_id = ti.patient_id
      and pa.review_status = 'approved'
      and pa.reminder_enabled
      and pa.exact_time is not null
      and ti.scheduled_at is not null
      and ti.scheduled_at <= now()
      and ti.scheduled_at > now() - interval '10 minutes'
    order by ti.scheduled_at, ti.id
    limit 200
  )
  insert into public.notification_events (
    patient_id, device_id, plan_action_id, task_instance_id,
    scheduled_at, notification_type, status
  )
  select patient_id, device_id, action_id, task_id, scheduled_at,
         'care_reminder', 'scheduled'
  from eligible
  on conflict do nothing;

  -- A stuck send can be retried at most five times; cross-worker claims
  -- cannot race because SKIP LOCKED serializes the UPDATE.
  return query
  with claimable as (
    select ne.id
    from public.notification_events ne
    join public.notification_devices nd on nd.id = ne.device_id
    join public.task_instances ti on ti.id = ne.task_instance_id
    join public.plan_actions pa on pa.id = ti.plan_action_id
    join public.care_plans cp on cp.id = pa.care_plan_id
    where ne.notification_type = 'care_reminder'
      and ne.status in ('scheduled', 'failed')
      and ne.attempt_count < 5
      and nd.platform = 'web' and nd.is_active
      and ne.patient_id = ti.patient_id and nd.patient_id = ti.patient_id
      and cp.patient_id = ti.patient_id and cp.status = 'active'
      and pa.review_status = 'approved' and pa.reminder_enabled
      and ti.status in ('pending', 'snoozed')
      and ti.scheduled_at <= now()
      and ti.scheduled_at > now() - interval '10 minutes'
      and (ne.last_attempt_at is null or
           ne.last_attempt_at <= now() - interval '90 seconds')
    order by ne.scheduled_at, ne.id
    limit p_batch_size
    for update of ne skip locked
  ),
  claimed as (
    update public.notification_events ne
    set status = 'scheduled',
        attempt_count = ne.attempt_count + 1,
        last_attempt_at = now()
    from claimable c
    where ne.id = c.id
    returning ne.id, ne.task_instance_id, ne.device_id
  )
  select c.id, c.task_instance_id, nd.push_token
  from claimed c join public.notification_devices nd on nd.id = c.device_id;
end;
$function$;

revoke all on function public.claim_due_web_care_reminders(integer)
  from public, anon, authenticated;
grant execute on function public.claim_due_web_care_reminders(integer)
  to service_role;
comment on function public.claim_due_web_care_reminders(integer) is
  'Server-only claims due approved patient Web care tasks without exposing patient text.';
