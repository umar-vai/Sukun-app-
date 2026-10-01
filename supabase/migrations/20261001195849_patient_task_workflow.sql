-- Patient task occurrence generation. An occurrence date is always known, but
-- scheduled_at remains null unless the approved action contains an explicit
-- exact time. This prevents the system from inventing clinical schedule times.

alter table public.task_instances
  add column occurrence_date date,
  add column timezone_offset_minutes integer;

update public.task_instances
set occurrence_date = scheduled_at::date,
    timezone_offset_minutes = 0
where occurrence_date is null;

alter table public.task_instances
  alter column occurrence_date set not null,
  alter column timezone_offset_minutes set not null,
  alter column scheduled_at drop not null,
  add constraint task_instances_timezone_offset_range check (
    timezone_offset_minutes between -720 and 840
  );

alter table public.task_instances
  drop constraint task_instances_plan_action_id_scheduled_at_key;

alter table public.task_instances
  add constraint task_instances_action_occurrence_key
  unique (plan_action_id, occurrence_date);

drop index task_instances_patient_schedule_idx;
create index task_instances_patient_occurrence_idx
  on public.task_instances (patient_id, occurrence_date, status);

drop index task_instances_pending_schedule_idx;
create index task_instances_pending_schedule_idx
  on public.task_instances (scheduled_at)
  where scheduled_at is not null and status in ('pending', 'snoozed');

create or replace function private.prevent_task_identity_rewrite()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.plan_action_id is distinct from old.plan_action_id
    or new.patient_id is distinct from old.patient_id
    or new.occurrence_date is distinct from old.occurrence_date
    or new.scheduled_at is distinct from old.scheduled_at
    or new.timezone_offset_minutes is distinct from old.timezone_offset_minutes then
    raise exception 'A generated task identity cannot be rewritten.'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

create or replace function public.ensure_patient_tasks(
  p_local_date date,
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
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select p.id into caller_patient_id
  from public.patients p
  join public.user_roles ur
    on ur.user_id = p.user_id and ur.role = 'patient'
  where p.user_id = caller_user_id
    and p.status = 'active';

  if caller_patient_id is null then
    raise exception 'An active patient account is required.' using errcode = '42501';
  end if;
  if p_timezone_offset_minutes is null
    or p_timezone_offset_minutes < -720
    or p_timezone_offset_minutes > 840 then
    raise exception 'A valid timezone offset is required.' using errcode = '22023';
  end if;
  if p_local_date is distinct from (
    now() + make_interval(mins => p_timezone_offset_minutes)
  )::date then
    raise exception 'Tasks can only be generated for the patient''s current day.'
      using errcode = '22023';
  end if;

  insert into public.task_instances (
    plan_action_id,
    patient_id,
    occurrence_date,
    scheduled_at,
    timezone_offset_minutes
  )
  select
    pa.id,
    caller_patient_id,
    p_local_date,
    case
      when pa.exact_time is null then null
      else (
        p_local_date + pa.exact_time
        - make_interval(mins => p_timezone_offset_minutes)
      ) at time zone 'UTC'
    end,
    p_timezone_offset_minutes
  from public.care_plans cp
  join public.plan_actions pa on pa.care_plan_id = cp.id
  where cp.patient_id = caller_patient_id
    and cp.status = 'active'
    and pa.review_status = 'approved'
    and p_local_date between pa.start_date and coalesce(pa.end_date, p_local_date)
    and (
      (
        pa.frequency_rule ->> 'type' = 'daily'
        and (p_local_date - pa.start_date)
          % ((pa.frequency_rule ->> 'interval')::integer) = 0
      )
      or (
        pa.frequency_rule ->> 'type' = 'weekly'
        and (extract(isodow from p_local_date)::integer)::text in (
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
    and ti.occurrence_date = p_local_date
    and cp.status = 'active'
  order by coalesce(ti.scheduled_at, 'infinity'::timestamptz), pa.sort_order;
end;
$$;

revoke execute on function public.ensure_patient_tasks(date, integer)
  from public, anon, authenticated;
grant execute on function public.ensure_patient_tasks(date, integer)
  to authenticated;

comment on function public.ensure_patient_tasks(date, integer) is
  'Idempotently creates today''s approved action occurrences for the authenticated patient without inventing missing clock times.';
comment on column public.task_instances.occurrence_date is
  'Patient-local calendar day represented by this task occurrence.';
comment on column public.task_instances.scheduled_at is
  'Exact instant only when the approved action explicitly specifies exact_time; otherwise null.';
