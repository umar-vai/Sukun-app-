-- Phase 7 notification delivery foundation. Device ownership is derived from
-- auth.uid(); reminder occurrences are generated only for approved actions
-- that explicitly contain an exact time and have reminders enabled.

alter table public.notification_devices
  add column installation_id text;

alter table public.notification_devices
  add constraint notification_devices_installation_not_blank check (
    installation_id is null or nullif(btrim(installation_id), '') is not null
  );

create unique index notification_devices_user_installation_key
  on public.notification_devices (user_id, installation_id)
  where installation_id is not null;

alter table public.notification_events
  add column request_id uuid;

create unique index notification_events_request_device_type_key
  on public.notification_events (request_id, device_id, notification_type)
  where request_id is not null and device_id is not null;

create or replace function public.register_notification_device(
  p_installation_id text,
  p_platform public.device_platform,
  p_push_token text,
  p_timezone text
)
returns public.notification_devices
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  caller_patient_id uuid;
  result public.notification_devices%rowtype;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if nullif(btrim(p_installation_id), '') is null
    or nullif(btrim(p_push_token), '') is null
    or nullif(btrim(p_timezone), '') is null then
    raise exception 'Device registration is incomplete.' using errcode = '22023';
  end if;

  select p.id into caller_patient_id
  from public.patients p
  join public.user_roles ur
    on ur.user_id = p.user_id and ur.role = 'patient'
  where p.user_id = caller_user_id and p.status = 'active';

  if caller_patient_id is null then
    raise exception 'An active patient account is required.' using errcode = '42501';
  end if;

  -- A single installation must not retain a stale token for the same account.
  delete from public.notification_devices nd
  where nd.user_id = caller_user_id
    and nd.installation_id = btrim(p_installation_id)
    and nd.push_token <> btrim(p_push_token);

  insert into public.notification_devices (
    user_id, patient_id, platform, push_token, timezone,
    installation_id, is_active, last_seen_at
  ) values (
    caller_user_id, caller_patient_id, p_platform, btrim(p_push_token),
    btrim(p_timezone), btrim(p_installation_id), true, now()
  )
  on conflict (push_token) do update set
    user_id = excluded.user_id,
    patient_id = excluded.patient_id,
    platform = excluded.platform,
    timezone = excluded.timezone,
    installation_id = excluded.installation_id,
    is_active = true,
    last_seen_at = now()
  where notification_devices.user_id = caller_user_id
  returning * into result;

  if result.id is null then
    raise exception 'This device token belongs to another account.'
      using errcode = '42501';
  end if;

  return result;
end;
$$;

create or replace function public.remove_notification_device(
  p_installation_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if nullif(btrim(p_installation_id), '') is null then
    raise exception 'An installation identifier is required.' using errcode = '22023';
  end if;

  delete from public.notification_devices nd
  where nd.user_id = (select auth.uid())
    and nd.installation_id = btrim(p_installation_id);
  get diagnostics deleted_count = row_count;
  return deleted_count > 0;
end;
$$;

create or replace function public.ensure_patient_reminder_tasks(
  p_start_date date,
  p_end_date date,
  p_timezone_offset_minutes integer
)
returns setof public.task_instances
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  caller_patient_id uuid;
  patient_today date;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select p.id into caller_patient_id
  from public.patients p
  join public.user_roles ur
    on ur.user_id = p.user_id and ur.role = 'patient'
  where p.user_id = caller_user_id and p.status = 'active';
  if caller_patient_id is null then
    raise exception 'An active patient account is required.' using errcode = '42501';
  end if;

  if p_timezone_offset_minutes is null
    or p_timezone_offset_minutes < -720
    or p_timezone_offset_minutes > 840 then
    raise exception 'A valid timezone offset is required.' using errcode = '22023';
  end if;
  patient_today := (
    now() + make_interval(mins => p_timezone_offset_minutes)
  )::date;
  if p_start_date is distinct from patient_today
    or p_end_date < p_start_date
    or p_end_date > p_start_date + 30 then
    raise exception 'Reminder tasks may only be generated for the next 31 days.'
      using errcode = '22023';
  end if;

  insert into public.task_instances (
    plan_action_id, patient_id, occurrence_date, scheduled_at,
    timezone_offset_minutes
  )
  select
    pa.id,
    caller_patient_id,
    day.local_date,
    (
      day.local_date + pa.exact_time
      - make_interval(mins => p_timezone_offset_minutes)
    ) at time zone 'UTC',
    p_timezone_offset_minutes
  from public.care_plans cp
  join public.plan_actions pa on pa.care_plan_id = cp.id
  cross join lateral generate_series(
    p_start_date,
    p_end_date,
    interval '1 day'
  ) generated_day
  cross join lateral (select generated_day::date as local_date) day
  where cp.patient_id = caller_patient_id
    and cp.status = 'active'
    and pa.review_status = 'approved'
    and pa.reminder_enabled
    and pa.exact_time is not null
    and day.local_date between pa.start_date and coalesce(pa.end_date, day.local_date)
    and (
      (
        pa.frequency_rule ->> 'type' = 'daily'
        and (day.local_date - pa.start_date)
          % ((pa.frequency_rule ->> 'interval')::integer) = 0
      )
      or (
        pa.frequency_rule ->> 'type' = 'weekly'
        and (extract(isodow from day.local_date)::integer)::text in (
          select jsonb_array_elements_text(pa.frequency_rule -> 'weekdays')
        )
      )
    )
  on conflict (plan_action_id, occurrence_date) do nothing;

  return query
  select ti.*
  from public.task_instances ti
  join public.plan_actions pa on pa.id = ti.plan_action_id
  join public.care_plans cp on cp.id = pa.care_plan_id
  where ti.patient_id = caller_patient_id
    and cp.status = 'active'
    and pa.review_status = 'approved'
    and pa.reminder_enabled
    and pa.exact_time is not null
    and ti.occurrence_date between p_start_date and p_end_date
    and ti.status in ('pending', 'snoozed')
  order by ti.scheduled_at;
end;
$$;

create or replace function private.cancel_inactive_plan_notifications()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.status = 'active' and new.status in ('inactive', 'archived') then
    update public.task_instances ti
    set status = 'cancelled', snoozed_until = null
    where ti.plan_action_id in (
      select pa.id from public.plan_actions pa where pa.care_plan_id = new.id
    )
      and ti.status in ('pending', 'snoozed')
      and ti.occurrence_date >= current_date;

    update public.notification_events ne
    set status = 'cancelled'
    where ne.plan_action_id in (
      select pa.id from public.plan_actions pa where pa.care_plan_id = new.id
    )
      and ne.status = 'scheduled';
  end if;
  return new;
end;
$$;

create trigger care_plans_cancel_inactive_notifications
after update of status on public.care_plans
for each row execute function private.cancel_inactive_plan_notifications();

revoke insert, update, delete on public.notification_devices from authenticated;
revoke execute on function public.register_notification_device(
  text, public.device_platform, text, text
) from public, anon, authenticated;
revoke execute on function public.remove_notification_device(text)
  from public, anon, authenticated;
revoke execute on function public.ensure_patient_reminder_tasks(date, date, integer)
  from public, anon, authenticated;

grant execute on function public.register_notification_device(
  text, public.device_platform, text, text
) to authenticated;
grant execute on function public.remove_notification_device(text)
  to authenticated;
grant execute on function public.ensure_patient_reminder_tasks(date, date, integer)
  to authenticated;

comment on function public.ensure_patient_reminder_tasks(date, date, integer) is
  'Generates a bounded reminder horizon only from approved, reminder-enabled actions with an explicit exact time.';
comment on function public.register_notification_device(
  text, public.device_platform, text, text
) is 'Registers the authenticated patient device without accepting a client-supplied patient identity.';
