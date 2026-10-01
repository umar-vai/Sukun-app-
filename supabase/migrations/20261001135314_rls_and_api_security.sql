-- Explicit Data API grants + RLS. Authorization is based on database roles,
-- never on client-provided metadata or hidden UI controls.

create or replace function private.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.user_roles ur
      where ur.user_id = (select auth.uid())
        and ur.role = 'super_admin'
    );
$$;

create or replace function private.current_patient_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.patients p
  where (select auth.uid()) is not null
    and p.user_id = (select auth.uid())
    and p.status = 'active'
  limit 1;
$$;

create or replace function private.can_read_care_plan(target_plan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.care_plans cp
      where cp.id = target_plan_id
        and cp.patient_id = (select private.current_patient_id())
        and cp.status <> 'draft'
    );
$$;

create or replace function private.can_read_plan_action(target_action_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.plan_actions pa
      join public.care_plans cp on cp.id = pa.care_plan_id
      where pa.id = target_action_id
        and pa.review_status = 'approved'
        and cp.patient_id = (select private.current_patient_id())
        and cp.status <> 'draft'
    );
$$;

create or replace function private.can_read_content_item(target_content_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.content_items ci
      where ci.id = target_content_id
        and ci.status = 'published'
        and (
          ci.visibility = 'public'
          or (
            ci.visibility = 'patient_only'
            and (select private.current_patient_id()) is not null
          )
          or (
            ci.visibility = 'assigned_only'
            and exists (
              select 1
              from public.plan_action_resources par
              join public.plan_actions pa on pa.id = par.plan_action_id
              join public.care_plans cp on cp.id = pa.care_plan_id
              where par.content_item_id = ci.id
                and pa.review_status = 'approved'
                and cp.status <> 'draft'
                and cp.patient_id = (select private.current_patient_id())
            )
          )
        )
    );
$$;

create or replace function private.can_read_content_category(target_category_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.content_items ci
      where ci.category_id = target_category_id
        and (select private.can_read_content_item(ci.id))
    );
$$;

create or replace function private.can_read_content_tag(target_tag_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.content_item_tags cit
      where cit.content_tag_id = target_tag_id
        and (select private.can_read_content_item(cit.content_item_id))
    );
$$;

create or replace function public.record_task_completion(
  p_task_id uuid,
  p_new_status public.task_status,
  p_client_event_id uuid,
  p_occurred_at timestamptz default now(),
  p_snoozed_until timestamptz default null,
  p_skip_reason text default null
)
returns public.task_instances
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  caller_patient_id uuid;
  task_row public.task_instances%rowtype;
  existing_event public.task_completions%rowtype;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select p.id
    into caller_patient_id
  from public.patients p
  where p.user_id = caller_user_id
    and p.status = 'active';

  if caller_patient_id is null then
    raise exception 'An active patient account is required.' using errcode = '42501';
  end if;

  if p_new_status not in ('completed', 'snoozed', 'skipped') then
    raise exception 'Unsupported patient task status.' using errcode = '22023';
  end if;

  if p_new_status = 'snoozed' and (
    p_snoozed_until is null or p_snoozed_until <= p_occurred_at
  ) then
    raise exception 'Snooze time must be later than the event time.'
      using errcode = '22023';
  end if;

  if p_new_status <> 'snoozed' and p_snoozed_until is not null then
    raise exception 'Snooze time is only valid for a snoozed task.'
      using errcode = '22023';
  end if;

  if p_new_status <> 'skipped' and p_skip_reason is not null then
    raise exception 'Skip reason is only valid for a skipped task.'
      using errcode = '22023';
  end if;

  select tc.*
    into existing_event
  from public.task_completions tc
  where tc.client_event_id = p_client_event_id;

  if found then
    if existing_event.patient_id <> caller_patient_id
      or existing_event.task_instance_id <> p_task_id
      or existing_event.status <> p_new_status then
      raise exception 'The completion request identifier is already in use.'
        using errcode = '23505';
    end if;

    select ti.* into task_row
    from public.task_instances ti
    where ti.id = p_task_id and ti.patient_id = caller_patient_id;
    return task_row;
  end if;

  select ti.*
    into task_row
  from public.task_instances ti
  where ti.id = p_task_id
    and ti.patient_id = caller_patient_id
  for update;

  if not found then
    raise exception 'Task was not found.' using errcode = 'P0002';
  end if;

  if task_row.status in ('completed', 'skipped', 'missed', 'cancelled') then
    raise exception 'This task can no longer be changed.' using errcode = '22023';
  end if;

  insert into public.task_completions (
    task_instance_id,
    patient_id,
    status,
    occurred_at,
    snoozed_until,
    skip_reason,
    client_event_id,
    created_by
  ) values (
    p_task_id,
    caller_patient_id,
    p_new_status,
    p_occurred_at,
    p_snoozed_until,
    p_skip_reason,
    p_client_event_id,
    caller_user_id
  );

  update public.task_instances
  set status = p_new_status,
      completed_at = case when p_new_status = 'completed' then p_occurred_at else null end,
      snoozed_until = case when p_new_status = 'snoozed' then p_snoozed_until else null end,
      skip_reason = case when p_new_status = 'skipped' then p_skip_reason else null end
  where id = p_task_id
  returning * into task_row;

  return task_row;
end;
$$;

-- Functions are not public APIs unless explicitly granted below.
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to anon, authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function private.is_super_admin() from public, anon, authenticated;
revoke execute on function private.current_patient_id() from public, anon, authenticated;
revoke execute on function private.can_read_care_plan(uuid) from public, anon, authenticated;
revoke execute on function private.can_read_plan_action(uuid) from public, anon, authenticated;
revoke execute on function private.can_read_content_item(uuid) from public, anon, authenticated;
revoke execute on function private.can_read_content_category(uuid) from public, anon, authenticated;
revoke execute on function private.can_read_content_tag(uuid) from public, anon, authenticated;
revoke execute on function public.record_task_completion(
  uuid, public.task_status, uuid, timestamptz, timestamptz, text
) from public, anon, authenticated;

grant execute on function private.is_super_admin() to authenticated;
grant execute on function private.current_patient_id() to authenticated;
grant execute on function private.can_read_care_plan(uuid) to authenticated;
grant execute on function private.can_read_plan_action(uuid) to authenticated;
grant execute on function private.can_read_content_item(uuid) to anon, authenticated;
grant execute on function private.can_read_content_category(uuid) to anon, authenticated;
grant execute on function private.can_read_content_tag(uuid) to anon, authenticated;
grant execute on function public.record_task_completion(
  uuid, public.task_status, uuid, timestamptz, timestamptz, text
) to authenticated;

-- New public objects remain private until a migration grants access explicitly.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated;

revoke all on all tables in schema public from anon, authenticated;

grant select on public.content_categories,
  public.content_items,
  public.content_tags,
  public.content_item_tags,
  public.app_settings
to anon;

grant select on public.profiles,
  public.user_roles,
  public.patients,
  public.patient_external_refs,
  public.prescriptions,
  public.prescription_versions,
  public.care_plans,
  public.plan_actions,
  public.task_instances,
  public.task_completions,
  public.content_categories,
  public.content_items,
  public.content_tags,
  public.content_item_tags,
  public.plan_action_resources,
  public.notification_devices,
  public.notification_events,
  public.admin_audit_logs,
  public.app_settings
to authenticated;

grant update (display_name, locale) on public.profiles to authenticated;
grant insert, delete on public.user_roles to authenticated;
grant insert, update on public.patients to authenticated;
grant insert, update, delete on public.patient_external_refs to authenticated;
grant insert on public.prescriptions to authenticated;
grant update (archived_at) on public.prescriptions to authenticated;
grant insert on public.prescription_versions to authenticated;
grant insert, update on public.care_plans to authenticated;
grant insert, update on public.plan_actions to authenticated;
grant insert, update on public.task_instances to authenticated;
grant insert, update on public.content_categories to authenticated;
grant insert, update on public.content_items to authenticated;
grant insert, update on public.content_tags to authenticated;
grant insert, delete on public.content_item_tags to authenticated;
grant insert, delete on public.plan_action_resources to authenticated;
grant insert, update, delete on public.notification_devices to authenticated;
grant insert, update on public.notification_events to authenticated;
grant insert on public.admin_audit_logs to authenticated;
grant usage, select on sequence public.admin_audit_logs_id_seq to authenticated;
grant insert, update, delete on public.app_settings to authenticated;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.patients enable row level security;
alter table public.patient_external_refs enable row level security;
alter table public.prescriptions enable row level security;
alter table public.prescription_versions enable row level security;
alter table public.care_plans enable row level security;
alter table public.plan_actions enable row level security;
alter table public.task_instances enable row level security;
alter table public.task_completions enable row level security;
alter table public.content_categories enable row level security;
alter table public.content_items enable row level security;
alter table public.content_tags enable row level security;
alter table public.content_item_tags enable row level security;
alter table public.plan_action_resources enable row level security;
alter table public.notification_devices enable row level security;
alter table public.notification_events enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.app_settings enable row level security;

create policy profiles_select_own_or_admin
on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or (select private.is_super_admin())
);
create policy profiles_update_own_or_admin
on public.profiles for update to authenticated
using (
  id = (select auth.uid())
  or (select private.is_super_admin())
)
with check (
  id = (select auth.uid())
  or (select private.is_super_admin())
);

create policy user_roles_select_own_or_admin
on public.user_roles for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_super_admin())
);
create policy user_roles_insert_admin
on public.user_roles for insert to authenticated
with check ((select private.is_super_admin()));
create policy user_roles_delete_admin
on public.user_roles for delete to authenticated
using ((select private.is_super_admin()));

create policy patients_select_own_or_admin
on public.patients for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_super_admin())
);
create policy patients_insert_admin
on public.patients for insert to authenticated
with check ((select private.is_super_admin()));
create policy patients_update_admin
on public.patients for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy patient_external_refs_select_admin
on public.patient_external_refs for select to authenticated
using ((select private.is_super_admin()));
create policy patient_external_refs_insert_admin
on public.patient_external_refs for insert to authenticated
with check ((select private.is_super_admin()));
create policy patient_external_refs_update_admin
on public.patient_external_refs for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));
create policy patient_external_refs_delete_admin
on public.patient_external_refs for delete to authenticated
using ((select private.is_super_admin()));

create policy prescriptions_select_permitted
on public.prescriptions for select to authenticated
using (
  (select private.is_super_admin())
  or (
    patient_id = (select private.current_patient_id())
    and visibility = 'patient'
  )
);
create policy prescriptions_insert_admin
on public.prescriptions for insert to authenticated
with check ((select private.is_super_admin()));
create policy prescriptions_archive_admin
on public.prescriptions for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy prescription_versions_select_permitted
on public.prescription_versions for select to authenticated
using (
  (select private.is_super_admin())
  or (
    visibility = 'patient'
    and exists (
      select 1 from public.prescriptions p
      where p.id = prescription_id
        and p.patient_id = (select private.current_patient_id())
    )
  )
);
create policy prescription_versions_insert_admin
on public.prescription_versions for insert to authenticated
with check ((select private.is_super_admin()));

create policy care_plans_select_permitted
on public.care_plans for select to authenticated
using ((select private.can_read_care_plan(id)));
create policy care_plans_insert_admin
on public.care_plans for insert to authenticated
with check ((select private.is_super_admin()));
create policy care_plans_update_admin
on public.care_plans for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy plan_actions_select_permitted
on public.plan_actions for select to authenticated
using ((select private.can_read_plan_action(id)));
create policy plan_actions_insert_admin_draft_plan
on public.plan_actions for insert to authenticated
with check (
  (select private.is_super_admin())
  and exists (
    select 1 from public.care_plans cp
    where cp.id = care_plan_id and cp.status = 'draft'
  )
);
create policy plan_actions_update_admin_draft_plan
on public.plan_actions for update to authenticated
using (
  (select private.is_super_admin())
  and exists (
    select 1 from public.care_plans cp
    where cp.id = care_plan_id and cp.status = 'draft'
  )
)
with check (
  (select private.is_super_admin())
  and exists (
    select 1 from public.care_plans cp
    where cp.id = care_plan_id and cp.status = 'draft'
  )
);

create policy task_instances_select_own_or_admin
on public.task_instances for select to authenticated
using (
  patient_id = (select private.current_patient_id())
  or (select private.is_super_admin())
);
create policy task_instances_insert_admin
on public.task_instances for insert to authenticated
with check ((select private.is_super_admin()));
create policy task_instances_update_admin
on public.task_instances for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy task_completions_select_own_or_admin
on public.task_completions for select to authenticated
using (
  patient_id = (select private.current_patient_id())
  or (select private.is_super_admin())
);

create policy content_categories_select_anon
on public.content_categories for select to anon
using ((select private.can_read_content_category(id)));
create policy content_categories_select_authenticated
on public.content_categories for select to authenticated
using ((select private.can_read_content_category(id)));
create policy content_categories_insert_admin
on public.content_categories for insert to authenticated
with check ((select private.is_super_admin()));
create policy content_categories_update_admin
on public.content_categories for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy content_items_select_anon
on public.content_items for select to anon
using ((select private.can_read_content_item(id)));
create policy content_items_select_authenticated
on public.content_items for select to authenticated
using ((select private.can_read_content_item(id)));
create policy content_items_insert_admin
on public.content_items for insert to authenticated
with check ((select private.is_super_admin()));
create policy content_items_update_admin
on public.content_items for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy content_tags_select_anon
on public.content_tags for select to anon
using ((select private.can_read_content_tag(id)));
create policy content_tags_select_authenticated
on public.content_tags for select to authenticated
using ((select private.can_read_content_tag(id)));
create policy content_tags_insert_admin
on public.content_tags for insert to authenticated
with check ((select private.is_super_admin()));
create policy content_tags_update_admin
on public.content_tags for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy content_item_tags_select_anon
on public.content_item_tags for select to anon
using ((select private.can_read_content_item(content_item_id)));
create policy content_item_tags_select_authenticated
on public.content_item_tags for select to authenticated
using ((select private.can_read_content_item(content_item_id)));
create policy content_item_tags_insert_admin
on public.content_item_tags for insert to authenticated
with check ((select private.is_super_admin()));
create policy content_item_tags_delete_admin
on public.content_item_tags for delete to authenticated
using ((select private.is_super_admin()));

create policy plan_action_resources_select_permitted
on public.plan_action_resources for select to authenticated
using (
  (select private.is_super_admin())
  or (
    (select private.can_read_plan_action(plan_action_id))
    and (select private.can_read_content_item(content_item_id))
  )
);
create policy plan_action_resources_insert_admin_draft_plan
on public.plan_action_resources for insert to authenticated
with check (
  (select private.is_super_admin())
  and exists (
    select 1
    from public.plan_actions pa
    join public.care_plans cp on cp.id = pa.care_plan_id
    where pa.id = plan_action_id and cp.status = 'draft'
  )
);
create policy plan_action_resources_delete_admin_draft_plan
on public.plan_action_resources for delete to authenticated
using (
  (select private.is_super_admin())
  and exists (
    select 1
    from public.plan_actions pa
    join public.care_plans cp on cp.id = pa.care_plan_id
    where pa.id = plan_action_id and cp.status = 'draft'
  )
);

create policy notification_devices_select_own
on public.notification_devices for select to authenticated
using (user_id = (select auth.uid()));
create policy notification_devices_insert_own
on public.notification_devices for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (
    patient_id is null
    or patient_id = (select private.current_patient_id())
  )
);
create policy notification_devices_update_own
on public.notification_devices for update to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and (
    patient_id is null
    or patient_id = (select private.current_patient_id())
  )
);
create policy notification_devices_delete_own
on public.notification_devices for delete to authenticated
using (user_id = (select auth.uid()));

create policy notification_events_select_own_or_admin
on public.notification_events for select to authenticated
using (
  patient_id = (select private.current_patient_id())
  or (select private.is_super_admin())
);
create policy notification_events_insert_admin
on public.notification_events for insert to authenticated
with check ((select private.is_super_admin()));
create policy notification_events_update_admin
on public.notification_events for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy admin_audit_logs_select_admin
on public.admin_audit_logs for select to authenticated
using ((select private.is_super_admin()));
create policy admin_audit_logs_insert_admin
on public.admin_audit_logs for insert to authenticated
with check (
  (select private.is_super_admin())
  and actor_user_id = (select auth.uid())
);

create policy app_settings_select_anon_public
on public.app_settings for select to anon
using (is_public);
create policy app_settings_select_authenticated
on public.app_settings for select to authenticated
using (is_public or (select private.is_super_admin()));
create policy app_settings_insert_admin
on public.app_settings for insert to authenticated
with check ((select private.is_super_admin()));
create policy app_settings_update_admin
on public.app_settings for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));
create policy app_settings_delete_admin
on public.app_settings for delete to authenticated
using ((select private.is_super_admin()));
