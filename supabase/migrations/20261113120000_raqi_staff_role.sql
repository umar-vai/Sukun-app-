-- Raqi staff role (owner request 2026-11-12).
--
-- The main admin (Super Admin) adds raqis by Gmail or phone. When a matching
-- account signs in it gets the `raqi` role at once and opens the admin area.
-- A raqi works with patients only: sees every patient, imports the official
-- templates, builds and publishes plans, sets and switches reminders, and
-- manages admin routines for a person. A raqi can NOT change content, the
-- official templates, notices, routine templates, prescriptions, patient
-- accounts or staff. Everything is enforced here, not only in the app.
--
-- * Enum value `raqi` (added in 20261113115900_app_role_raqi.sql);
--   `private.is_care_staff()` = Super Admin or raqi.
-- * `staff_members` holds the main admin's list (RLS on, Super Admin read,
--   writes only through the audited RPCs below).
-- * Patient-care functions and policies are patched in place from their live
--   definitions: only `private.is_super_admin()` becomes
--   `private.is_care_staff()`. The migration stops if a target is missing.
-- * A phone entry matches an account whose sign-in phone, or linked patient
--   record phone, has the same last 11 digits. No SMS provider is added.

create or replace function private.is_care_staff()
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
        and ur.role::text in ('super_admin', 'raqi')
    );
$$;

revoke all on function private.is_care_staff() from public, anon;
grant execute on function private.is_care_staff() to authenticated;

create table if not exists public.staff_members (
  id uuid primary key default gen_random_uuid(),
  role text not null default 'raqi',
  display_name text,
  email text,
  phone_digits text,
  user_id uuid references auth.users (id) on delete set null,
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references auth.users (id) on delete set null,
  constraint staff_members_role check (role = 'raqi'),
  constraint staff_members_contact check (email is not null or phone_digits is not null),
  constraint staff_members_email_format check (
    email is null or (email = lower(btrim(email))
      and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and char_length(email) <= 254)
  ),
  constraint staff_members_phone_format check (
    phone_digits is null or phone_digits ~ '^[0-9]{11}$'
  ),
  constraint staff_members_name_length check (
    display_name is null or char_length(btrim(display_name)) between 1 and 120
  )
);

comment on table public.staff_members is
  'Raqis added by the main admin. Matching accounts get the raqi role.';

create unique index if not exists staff_members_active_email_idx
  on public.staff_members (email) where revoked_at is null and email is not null;
create unique index if not exists staff_members_active_phone_idx
  on public.staff_members (phone_digits)
  where revoked_at is null and phone_digits is not null;
create index if not exists staff_members_user_idx on public.staff_members (user_id);

alter table public.staff_members enable row level security;
drop policy if exists staff_members_select_super_admin on public.staff_members;
create policy staff_members_select_super_admin
  on public.staff_members for select to authenticated
  using ((select private.is_super_admin()));
revoke all on table public.staff_members from public, anon, authenticated;
grant select on table public.staff_members to authenticated;

-- Last 11 digits of a phone number, or null.
create or replace function private.phone_key(p_phone text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when char_length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) >= 11
    then right(regexp_replace(p_phone, '[^0-9]', '', 'g'), 11)
  end;
$$;

-- Grants the raqi role to one account when an active entry matches its
-- confirmed email or phone. Never touches Super Admins.
create or replace function private.apply_staff_membership(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_phone text;
  v_entry uuid;
begin
  if p_user_id is null then
    return;
  end if;
  select case when u.email_confirmed_at is not null then lower(u.email) end,
         private.phone_key(u.phone)
    into v_email, v_phone
  from auth.users u where u.id = p_user_id;
  if v_phone is null then
    select private.phone_key(p.phone) into v_phone
    from public.patients p
    where p.user_id = p_user_id and p.archived_at is null
    order by p.created_at desc limit 1;
  end if;

  select sm.id into v_entry
  from public.staff_members sm
  where sm.revoked_at is null
    and ((v_email is not null and sm.email = v_email)
      or (v_phone is not null and sm.phone_digits = v_phone))
  order by sm.created_at
  limit 1;
  if v_entry is null then
    return;
  end if;

  insert into public.user_roles (user_id, role, granted_by)
  select p_user_id, 'raqi', sm.invited_by
  from public.staff_members sm where sm.id = v_entry
  on conflict do nothing;

  update public.staff_members
  set user_id = p_user_id, claimed_at = coalesce(claimed_at, now())
  where id = v_entry and (user_id is distinct from p_user_id or claimed_at is null);
end;
$$;

revoke all on function private.apply_staff_membership(uuid)
  from public, anon, authenticated;

create or replace function private.auth_user_staff_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.apply_staff_membership(new.id);
  return new;
end;
$$;

drop trigger if exists auth_users_staff_membership on auth.users;
create trigger auth_users_staff_membership
after insert or update of email, phone, email_confirmed_at on auth.users
for each row execute function private.auth_user_staff_membership();

-- Called by the app right after sign-in, so an account that existed before
-- it was added becomes a raqi on its next sign-in without waiting.
create or replace function public.claim_staff_membership()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    return false;
  end if;
  perform private.apply_staff_membership(v_user);
  return exists (
    select 1 from public.user_roles ur
    where ur.user_id = v_user and ur.role::text = 'raqi'
  );
end;
$$;

revoke all on function public.claim_staff_membership() from public, anon;
grant execute on function public.claim_staff_membership() to authenticated;

-- Main admin adds a raqi by email and/or phone.
create or replace function public.admin_add_raqi(
  p_email text default null,
  p_phone text default null,
  p_display_name text default null
)
returns public.staff_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_email text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  v_phone text := private.phone_key(p_phone);
  v_row public.staff_members;
  v_user uuid;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required' using errcode = '42501';
  end if;
  if v_email is null and v_phone is null then
    raise exception 'Give an email or an 11-digit phone number' using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_phone, '')), '') is not null and v_phone is null then
    raise exception 'Phone number needs at least 11 digits' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.staff_members sm
    where sm.revoked_at is null
      and ((v_email is not null and sm.email = v_email)
        or (v_phone is not null and sm.phone_digits = v_phone))
  ) then
    raise exception 'This raqi is already added' using errcode = '23505';
  end if;

  insert into public.staff_members (email, phone_digits, display_name, invited_by)
  values (v_email, v_phone, nullif(btrim(coalesce(p_display_name, '')), ''), v_actor)
  returning * into v_row;

  -- Accounts that already exist get the role at once (never a Super Admin).
  for v_user in
    select u.id from auth.users u
    where ((v_email is not null and u.email_confirmed_at is not null
            and lower(u.email) = v_email)
        or (v_phone is not null and private.phone_key(u.phone) = v_phone)
        or (v_phone is not null and exists (
              select 1 from public.patients p
              where p.user_id = u.id and p.archived_at is null
                and private.phone_key(p.phone) = v_phone)))
      and not exists (
        select 1 from public.user_roles ur
        where ur.user_id = u.id and ur.role = 'super_admin')
  loop
    perform private.apply_staff_membership(v_user);
  end loop;

  insert into public.admin_audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_actor, 'staff.raqi_added', 'staff_member', v_row.id,
    jsonb_build_object('has_email', v_email is not null, 'has_phone', v_phone is not null));

  select * into v_row from public.staff_members where id = v_row.id;
  return v_row;
end;
$$;

revoke all on function public.admin_add_raqi(text, text, text) from public, anon;
grant execute on function public.admin_add_raqi(text, text, text) to authenticated;

-- Main admin removes a raqi: the entry is kept (history) and the role goes.
create or replace function public.admin_remove_raqi(p_staff_id uuid)
returns public.staff_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_row public.staff_members;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required' using errcode = '42501';
  end if;
  update public.staff_members
  set revoked_at = now(), revoked_by = v_actor
  where id = p_staff_id and revoked_at is null
  returning * into v_row;
  if v_row.id is null then
    raise exception 'Raqi not found' using errcode = 'P0002';
  end if;
  if v_row.user_id is not null and not exists (
    select 1 from public.staff_members sm
    where sm.user_id = v_row.user_id and sm.revoked_at is null
  ) then
    delete from public.user_roles
    where user_id = v_row.user_id and role::text = 'raqi';
  end if;
  insert into public.admin_audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_actor, 'staff.raqi_removed', 'staff_member', v_row.id, '{}'::jsonb);
  return v_row;
end;
$$;

revoke all on function public.admin_remove_raqi(uuid) from public, anon;
grant execute on function public.admin_remove_raqi(uuid) to authenticated;

-- Patient-care functions a raqi may use.
do $patch$
declare
  v_sig text;
  v_def text;
  v_new text;
begin
  foreach v_sig in array array[
    'private.can_read_care_plan(uuid)',
    'private.can_read_plan_action(uuid)',
    'public.admin_get_user_routine_overview(uuid)',
    'public.admin_get_user_routine_progress(uuid,integer)',
    'public.admin_import_user_routine_reminders(uuid,text,jsonb,text)',
    'public.admin_create_user_routine(uuid,text,jsonb)',
    'public.admin_list_care_recipients(text,integer,integer)',
    'public.admin_search_patients(text,integer,integer)',
    'public.admin_set_plan_action_reminder(uuid,boolean)',
    'public.admin_set_user_routine_action_reminder(uuid,boolean)',
    'public.create_draft_care_plan(uuid,text,date,date,uuid,uuid,uuid)',
    'public.save_plan_action(uuid,text,text,jsonb,date,uuid,text,integer,integer,text,time,date,public.action_review_status,boolean,uuid,text,uuid)',
    'public.publish_care_plan(uuid,uuid)',
    'public.reject_plan_action(uuid,uuid)',
    'public.reorder_plan_actions(uuid,uuid[],uuid)',
    'public.replace_draft_action_quran_surahs(uuid,jsonb,uuid)',
    'public.replace_draft_action_resources(uuid,uuid[],uuid)',
    'public.set_draft_action_notification_title(uuid,text)'
  ] loop
    v_def := pg_get_functiondef(v_sig::regprocedure);
    v_new := replace(v_def, 'private.is_super_admin()', 'private.is_care_staff()');
    if v_new = v_def then
      raise exception 'No Super Admin check found in %; patch aborted', v_sig;
    end if;
    execute v_new;
  end loop;
end;
$patch$;

-- Raqi accounts are staff, not people under care: keep them off the list.
do $patch$
declare
  v_def text;
  v_new text;
begin
  v_def := pg_get_functiondef(
    'public.admin_list_care_recipients(text,integer,integer)'::regprocedure);
  v_new := replace(v_def,
    $o$where ur.user_id = u.id and ur.role = 'super_admin'$o$,
    $n$where ur.user_id = u.id and ur.role::text in ('super_admin', 'raqi')$n$);
  if v_new = v_def then
    raise exception 'care recipients staff filter not found; patch aborted';
  end if;
  execute v_new;
end;
$patch$;

-- Patient-care policies a raqi needs (reads, draft plan writes, audit rows).
do $patch$
declare
  v_policy record;
  v_sql text;
begin
  for v_policy in
    select * from pg_policies
    where schemaname = 'public'
      and policyname in (
        'admin_audit_logs_insert_admin',
        'care_plans_insert_admin',
        'care_plans_update_admin',
        'care_templates_select_super_admin',
        'patients_select_own_or_admin',
        'plan_action_quran_surahs_delete_admin_draft',
        'plan_action_quran_surahs_insert_admin_draft',
        'plan_action_quran_surahs_select_permitted',
        'plan_action_resources_delete_admin_draft_plan',
        'plan_action_resources_insert_admin_draft_plan',
        'plan_action_resources_select_permitted',
        'plan_actions_insert_admin_draft_plan',
        'plan_actions_update_admin_draft_plan',
        'prescription_versions_select_permitted',
        'prescriptions_select_permitted',
        'profiles_select_own_or_admin',
        'task_completions_select_own_or_admin',
        'task_instances_select_own_or_admin'
      )
  loop
    v_sql := format('alter policy %I on %I.%I', v_policy.policyname,
      v_policy.schemaname, v_policy.tablename);
    if v_policy.qual is not null then
      v_sql := v_sql || ' using (' || replace(v_policy.qual,
        'private.is_super_admin()', 'private.is_care_staff()') || ')';
    end if;
    if v_policy.with_check is not null then
      v_sql := v_sql || ' with check (' || replace(v_policy.with_check,
        'private.is_super_admin()', 'private.is_care_staff()') || ')';
    end if;
    execute v_sql;
  end loop;
  if (select count(*) from pg_policies where schemaname = 'public'
      and (qual like '%is_care_staff()%' or with_check like '%is_care_staff()%')) < 18 then
    raise exception 'Not every patient-care policy was updated; patch aborted';
  end if;
end;
$patch$;
