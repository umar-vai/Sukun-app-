-- Ghusl calendar and detox days (owner request 2026-11-12).
--
-- Three baths (nazar b01, boroi patar b02, detox b03) are placed on a
-- calendar per person when an admin imports templates. On a detox day every
-- other task and reminder of that person pauses; only the detox bath and the
-- content linked to it run.
--
-- Care plans: plan_actions.frequency_rule gains a third shape
--   {"type":"dates","dates":["YYYY-MM-DD",...],"ghusl":"nazar|boroi|detox"}
-- validated by a trigger. save_plan_action is patched in place (its live
-- definition is read and only the allowed-types list changes; the migration
-- stops if that text is not found). ensure_patient_tasks and
-- ensure_patient_reminder_tasks generate "dates" occurrences and skip every
-- non-detox action on a detox day, including already generated rows.
--
-- Routines: personal_routine_actions gains active_dates (null = every day)
-- and ghusl_kind. admin_import_user_routine_reminders stores them when a
-- step sends active_dates / ghusl_kind (patched in place the same way). The
-- app applies the detox rule when it plans routine reminders.
--
-- No existing row changes: every existing action keeps daily/weekly and null.

-- 1. Care plan "dates" frequency -----------------------------------------

create or replace function private.validate_plan_action_frequency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_count integer;
  v_distinct integer;
  v_bad integer;
begin
  if new.frequency_rule ->> 'type' is distinct from 'dates' then
    return new;
  end if;
  if jsonb_typeof(new.frequency_rule -> 'dates') is distinct from 'array' then
    raise exception 'Calendar frequency requires dates.' using errcode = '22023';
  end if;
  select count(*), count(distinct value),
         count(*) filter (where value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
    into v_count, v_distinct, v_bad
  from jsonb_array_elements_text(new.frequency_rule -> 'dates');
  if v_count not between 1 and 120 or v_distinct <> v_count or v_bad > 0 then
    raise exception 'Calendar frequency needs 1 to 120 distinct YYYY-MM-DD dates.'
      using errcode = '22023';
  end if;
  -- Each value must be a real calendar date. Dates outside the action's
  -- start/end are allowed (a copied plan version keeps past dates) and
  -- simply never generate a task.
  perform d::date from jsonb_array_elements_text(new.frequency_rule -> 'dates') d;
  if new.frequency_rule ? 'ghusl'
     and coalesce(new.frequency_rule ->> 'ghusl', '') not in ('nazar', 'boroi', 'detox') then
    raise exception 'Unknown ghusl kind.' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists plan_actions_validate_frequency on public.plan_actions;
create trigger plan_actions_validate_frequency
before insert or update of frequency_rule
on public.plan_actions
for each row execute function private.validate_plan_action_frequency();

do $patch$
declare
  v_def text;
  v_new text;
begin
  v_def := pg_get_functiondef(
    'public.save_plan_action(uuid,text,text,jsonb,date,uuid,text,integer,integer,text,time,date,public.action_review_status,boolean,uuid,text,uuid)'::regprocedure
  );
  v_new := regexp_replace(
    v_def,
    'not in \(\s*''daily'',\s*''weekly''\s*\)',
    'not in (''daily'', ''weekly'', ''dates'')'
  );
  if v_new = v_def then
    raise exception 'save_plan_action frequency check not found; patch aborted';
  end if;
  v_new := replace(v_new, 'Frequency must be daily or weekly.',
    'Frequency must be daily, weekly or calendar dates.');
  execute v_new;
end;
$patch$;

-- True when p_day is a detox day of the patient and p_action_id is not a
-- detox action itself: that action is paused for the day.
create or replace function private.detox_day_blocks(
  p_patient_id uuid,
  p_action_id uuid,
  p_day date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.care_plans cp
    join public.plan_actions d on d.care_plan_id = cp.id
    where cp.patient_id = p_patient_id
      and cp.status = 'active'
      and d.review_status = 'approved'
      and d.frequency_rule ->> 'type' = 'dates'
      and d.frequency_rule ->> 'ghusl' = 'detox'
      and p_day::text in (
        select jsonb_array_elements_text(d.frequency_rule -> 'dates')
      )
  )
  and not exists (
    select 1 from public.plan_actions a
    where a.id = p_action_id
      and a.frequency_rule ->> 'ghusl' = 'detox'
  );
$$;

revoke all on function private.detox_day_blocks(uuid, uuid, date)
  from public, anon, authenticated;

-- Generators (from the deployed definitions, plus dates and detox).

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
      or (
        pa.frequency_rule ->> 'type' = 'dates'
        and (p_local_date)::text in (
          select jsonb_array_elements_text(pa.frequency_rule -> 'dates')
        )
      )
    )
    and not (select private.detox_day_blocks(caller_patient_id, pa.id, p_local_date))
  on conflict (plan_action_id, occurrence_date) do nothing;

  return query
  select ti.*
  from public.task_instances ti
  join public.plan_actions pa on pa.id = ti.plan_action_id
  join public.care_plans cp on cp.id = pa.care_plan_id
  where ti.patient_id = caller_patient_id
    and ti.occurrence_date = p_local_date
    and cp.status = 'active'
    and not (select private.detox_day_blocks(caller_patient_id, pa.id, ti.occurrence_date))
  order by coalesce(ti.scheduled_at, 'infinity'::timestamptz), pa.sort_order;
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
      or (
        pa.frequency_rule ->> 'type' = 'dates'
        and (day.local_date)::text in (
          select jsonb_array_elements_text(pa.frequency_rule -> 'dates')
        )
      )
    )
    and not (select private.detox_day_blocks(caller_patient_id, pa.id, day.local_date))
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
    and not (select private.detox_day_blocks(caller_patient_id, pa.id, ti.occurrence_date))
  order by ti.scheduled_at;
end;
$$;

-- 2. Routine calendar dates ------------------------------------------------

alter table public.personal_routine_actions
  add column if not exists active_dates date[],
  add column if not exists ghusl_kind text;

alter table public.personal_routine_actions
  drop constraint if exists personal_routine_actions_active_dates_check,
  add constraint personal_routine_actions_active_dates_check
    check (active_dates is null or cardinality(active_dates) between 1 and 120),
  drop constraint if exists personal_routine_actions_ghusl_kind_check,
  add constraint personal_routine_actions_ghusl_kind_check
    check (ghusl_kind is null or ghusl_kind in ('nazar', 'boroi', 'detox'));

comment on column public.personal_routine_actions.active_dates is
  'Local dates this step runs (ghusl calendar). Null means every day.';
comment on column public.personal_routine_actions.ghusl_kind is
  'nazar, boroi or detox for a ghusl calendar step. On a detox date the app pauses the owner''s other steps.';

do $patch$
declare
  v_def text;
  v_new text;
begin
  v_def := pg_get_functiondef(
    'public.admin_import_user_routine_reminders(uuid,text,jsonb,text)'::regprocedure
  );
  v_new := regexp_replace(
    v_def,
    'schedule_kind,local_time,timezone_name,is_active\s*\)\s*values\s*\(',
    $r$schedule_kind,local_time,timezone_name,is_active,active_dates,ghusl_kind
    ) values ($r$
  );
  if v_new = v_def then
    raise exception 'routine import column list not found; patch aborted';
  end if;
  v_def := v_new;
  v_new := regexp_replace(
    v_def,
    '''fixed'',v_step_time,v_timezone,true\s*\)\s*returning id into v_action;',
    $r$'fixed',v_step_time,v_timezone,true,
      case when jsonb_typeof(v_step->'active_dates') = 'array'
        then (select array_agg(distinct x::date order by x::date)
              from jsonb_array_elements_text(v_step->'active_dates') x)
      end,
      nullif(btrim(coalesce(v_step->>'ghusl_kind','')), '')
    ) returning id into v_action;$r$
  );
  if v_new = v_def then
    raise exception 'routine import values not found; patch aborted';
  end if;
  execute v_new;
end;
$patch$;
