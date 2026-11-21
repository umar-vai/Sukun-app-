-- Family accounts (owner decisions 4 to 8, CRM/ERP integration master prompt,
-- 2026-11-20).
--
-- PURPOSE
--   One authenticated account (one Supabase Auth user) may own several
--   independent patient profiles. Every profile keeps its own plans,
--   prescriptions, tasks, completions, reminders and progress. Family members
--   who share the login can read each other's PATIENT-VISIBLE data (approved
--   owner decision); they can never read another family or staff-only data.
--
-- DESIGN (additive, no destructive change)
--   * `family_accounts` : one row per family login (owner_user_id unique).
--   * `family_members`  : links patient profiles to a family. A patient is in
--     at most one ACTIVE family. Unlinking keeps every clinical record.
--   * `patients.user_id` is untouched. The owner's own profile keeps it; the
--     other profiles have `user_id` null (they have no login of their own).
--   * `private.accessible_patient_ids()` / `private.can_access_patient()` are
--     the single authorization primitives: the caller's own patient plus the
--     active members of the family the caller owns.
--   * Existing RLS policies and patient RPCs that compared against
--     `private.current_patient_id()` are patched IN PLACE from their live
--     definitions to use the primitives above. For a single-patient account
--     the result set is identical to before. The migration stops if a
--     pattern it expects is missing.
--   * Patient RPCs accept an optional trailing `p_patient_id` (default null =
--     previous behaviour). The id is NEVER trusted: it is validated against
--     the caller's accessible set on every call. The selected profile is
--     per device (sent by the client), never a global family setting.
--
-- ROLLBACK
--   Re-run the previous function/policy definitions (see
--   docs/integrations/TESTING_AND_ROLLOUT.md), then
--   `drop table public.family_members, public.family_accounts cascade;`
--   No patient, plan, task or completion row is changed by this migration.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.family_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users (id) on delete restrict,
  label text,
  crm_family_id text,
  status text not null default 'active',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint family_accounts_status check (status in ('active', 'inactive')),
  constraint family_accounts_label_length check (
    label is null or char_length(btrim(label)) between 1 and 160
  ),
  constraint family_accounts_crm_family_id_not_blank check (
    crm_family_id is null or btrim(crm_family_id) <> ''
  )
);

create unique index if not exists family_accounts_crm_family_id_key
  on public.family_accounts (crm_family_id) where crm_family_id is not null;

create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.family_accounts (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete restrict,
  relationship_label text,
  display_order integer not null default 0,
  linked_by uuid references auth.users (id) on delete set null,
  linked_at timestamptz not null default now(),
  unlinked_at timestamptz,
  unlinked_by uuid references auth.users (id) on delete set null,
  constraint family_members_relationship_length check (
    relationship_label is null
    or char_length(btrim(relationship_label)) between 1 and 60
  ),
  constraint family_members_order_nonnegative check (display_order >= 0),
  constraint family_members_unlink_consistency check (
    (unlinked_at is null and unlinked_by is null) or unlinked_at is not null
  )
);

-- A patient belongs to at most one active family; a family never lists the
-- same patient twice.
create unique index if not exists family_members_one_active_family_per_patient
  on public.family_members (patient_id) where unlinked_at is null;
create index if not exists family_members_family_idx
  on public.family_members (family_id) where unlinked_at is null;

alter table public.family_accounts enable row level security;
alter table public.family_members enable row level security;

-- Direct API writes are never allowed; only audited SECURITY DEFINER
-- functions change these tables.
revoke all on public.family_accounts from public, anon, authenticated;
revoke all on public.family_members from public, anon, authenticated;
grant select on public.family_accounts, public.family_members to authenticated;

drop policy if exists family_accounts_select_owner_or_staff on public.family_accounts;
create policy family_accounts_select_owner_or_staff
on public.family_accounts for select to authenticated
using (
  owner_user_id = (select auth.uid())
  or (select private.is_care_staff())
);

drop policy if exists family_members_select_owner_or_staff on public.family_members;
create policy family_members_select_owner_or_staff
on public.family_members for select to authenticated
using (
  (select private.is_care_staff())
  or exists (
    select 1 from public.family_accounts fa
    where fa.id = family_members.family_id
      and fa.owner_user_id = (select auth.uid())
  )
);

-- ---------------------------------------------------------------------------
-- 2. Authorization primitives
-- ---------------------------------------------------------------------------

create or replace function private.accessible_patient_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.patients p
  where (select auth.uid()) is not null
    and p.status = 'active'
    and (
      p.user_id = (select auth.uid())
      or exists (
        select 1
        from public.family_members fm
        join public.family_accounts fa on fa.id = fm.family_id
        where fm.patient_id = p.id
          and fm.unlinked_at is null
          and fa.status = 'active'
          and fa.owner_user_id = (select auth.uid())
      )
    );
$$;

create or replace function private.can_access_patient(target_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_patient_id is not null
    and exists (
      select 1 from private.accessible_patient_ids() a(id)
      where a.id = target_patient_id
    );
$$;

-- Resolves the profile a patient RPC acts for.
--   * explicit id  : must be in the caller's accessible set (never trusted)
--   * null         : legacy behaviour (the caller's own patient); a family
--                    with several profiles must name one explicitly.
create or replace function private.resolve_acting_patient(
  requested_patient_id uuid default null
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  own_patient_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  if requested_patient_id is not null then
    if not (select private.can_access_patient(requested_patient_id)) then
      raise exception 'An active patient account is required.'
        using errcode = '42501';
    end if;
    return requested_patient_id;
  end if;

  select p.id into own_patient_id
  from public.patients p
  join public.user_roles ur
    on ur.user_id = p.user_id and ur.role = 'patient'
  where p.user_id = (select auth.uid()) and p.status = 'active';

  if own_patient_id is null then
    raise exception 'An active patient account is required.'
      using errcode = '42501';
  end if;
  return own_patient_id;
end;
$$;

revoke all on function private.accessible_patient_ids() from public, anon;
revoke all on function private.can_access_patient(uuid) from public, anon;
revoke all on function private.resolve_acting_patient(uuid) from public, anon;
grant execute on function private.accessible_patient_ids() to authenticated;
grant execute on function private.can_access_patient(uuid) to authenticated;
grant execute on function private.resolve_acting_patient(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Patch RLS policies in place (7 patient-scoped policies + patients read)
-- ---------------------------------------------------------------------------

do $$
declare
  pol record;
  new_qual text;
  new_check text;
  patched integer := 0;
  ident constant text :=
    '\(\s*SELECT private\.current_patient_id\(\)( AS current_patient_id)?\s*\)';
begin
  for pol in
    select schemaname, tablename, policyname, cmd, permissive, roles, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (qual ilike '%current_patient_id%' or with_check ilike '%current_patient_id%')
  loop
    new_qual := regexp_replace(
      pol.qual, '((\w+)\.)?patient_id\s*=\s*' || ident,
      'private.can_access_patient(\1patient_id)', 'gi');
    new_check := regexp_replace(
      pol.with_check, '((\w+)\.)?patient_id\s*=\s*' || ident,
      'private.can_access_patient(\1patient_id)', 'gi');

    if new_qual ilike '%current_patient_id%'
      or new_check ilike '%current_patient_id%' then
      raise exception 'Unpatched current_patient_id() in policy %.%',
        pol.tablename, pol.policyname;
    end if;

    execute format('drop policy %I on %I.%I',
      pol.policyname, pol.schemaname, pol.tablename);
    execute format(
      'create policy %I on %I.%I as %s for %s to %s %s %s',
      pol.policyname, pol.schemaname, pol.tablename, pol.permissive, pol.cmd,
      array_to_string(pol.roles, ', '),
      case when new_qual is null then '' else 'using (' || new_qual || ')' end,
      case when new_check is null then '' else 'with check (' || new_check || ')' end);
    patched := patched + 1;
  end loop;

  if patched <> 7 then
    raise exception 'Expected to patch 7 policies, patched %', patched;
  end if;
end $$;

-- Family members read the patient rows of linked profiles (name and code
-- only; the table holds no clinical or staff-only text).
drop policy if exists patients_select_own_or_admin on public.patients;
create policy patients_select_own_or_admin
on public.patients for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_care_staff())
  or (select private.can_access_patient(id))
);

-- ---------------------------------------------------------------------------
-- 4. Patch helper functions and patient RPCs in place
-- ---------------------------------------------------------------------------

do $$
declare
  fn regprocedure;
  def text;
  new_def text;
  patched integer := 0;
begin
  -- 4a. Read helpers that compared the plan owner with current_patient_id().
  for fn in
    select p.oid::regprocedure
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname in (
        'can_read_care_plan', 'can_read_plan_action', 'can_read_content_item',
        'can_read_content_collection')
      and p.prosrc ilike '%current_patient_id%'
  loop
    def := pg_get_functiondef(fn);
    new_def := regexp_replace(
      def,
      '(\w+)\.patient_id\s*=\s*\(\s*select private\.current_patient_id\(\)( as current_patient_id)?\s*\)',
      'private.can_access_patient(\1.patient_id)', 'gi');
    new_def := regexp_replace(
      new_def,
      '\(\s*select private\.current_patient_id\(\)( as current_patient_id)?\s*\)\s+is not null',
      'exists (select 1 from private.accessible_patient_ids())', 'gi');
    if new_def ilike '%current_patient_id%' or new_def = def then
      raise exception 'Could not patch %', fn;
    end if;
    execute new_def;
    patched := patched + 1;
  end loop;
  if patched <> 4 then
    raise exception 'Expected to patch 4 read helpers, patched %', patched;
  end if;
end $$;

-- 4b. ensure_patient_tasks / ensure_patient_reminder_tasks /
--     register_notification_device: add trailing optional p_patient_id and
--     resolve the acting profile with the validated helper.
do $$
declare
  fn regprocedure;
  old_sig text;
  def text;
  new_def text;
  lookup constant text :=
    'select p\.id into caller_patient_id\s+from public\.patients p\s+'
    'join public\.user_roles ur\s+on ur\.user_id = p\.user_id and ur\.role = ''patient''\s+'
    'where p\.user_id = caller_user_id\s+and p\.status = ''active'';';
  lookup_compact constant text :=
    'select p\.id into caller_patient_id\s+from public\.patients p\s+'
    'join public\.user_roles ur\s+on ur\.user_id = p\.user_id and ur\.role = ''patient''\s+'
    'where p\.user_id = caller_user_id and p\.status = ''active'';';
  patched integer := 0;
begin
  for fn in
    select p.oid::regprocedure
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'ensure_patient_tasks', 'ensure_patient_reminder_tasks',
        'register_notification_device')
      and p.prosrc not ilike '%resolve_acting_patient%'
  loop
    old_sig := fn::text;
    def := pg_get_functiondef(fn);
    new_def := regexp_replace(
      def, '\)\s+RETURNS', ', p_patient_id uuid DEFAULT NULL::uuid) RETURNS');
    new_def := regexp_replace(new_def, lookup, 'caller_patient_id := private.resolve_acting_patient(p_patient_id);', 'i');
    new_def := regexp_replace(new_def, lookup_compact, 'caller_patient_id := private.resolve_acting_patient(p_patient_id);', 'i');
    if new_def not like '%resolve_acting_patient(p_patient_id)%'
      or new_def not like '%p_patient_id uuid DEFAULT%' then
      raise exception 'Could not patch %', old_sig;
    end if;
    execute format('drop function %s', old_sig);
    execute new_def;
    patched := patched + 1;
  end loop;
  if patched <> 3 then
    raise exception 'Expected to patch 3 RPCs, patched %', patched;
  end if;
end $$;

revoke all on function public.ensure_patient_tasks(date, integer, uuid)
  from public, anon;
revoke all on function public.ensure_patient_reminder_tasks(date, date, integer, uuid)
  from public, anon;
revoke all on function public.register_notification_device(
  text, public.device_platform, text, text, uuid) from public, anon;
grant execute on function public.ensure_patient_tasks(date, integer, uuid)
  to authenticated;
grant execute on function public.ensure_patient_reminder_tasks(date, date, integer, uuid)
  to authenticated;
grant execute on function public.register_notification_device(
  text, public.device_platform, text, text, uuid) to authenticated;

-- 4c. record_task_completion: the profile is the TASK's patient when the
--     caller may act for it. The signature is unchanged, so
--     a forged patient id is impossible (there is no id argument at all).
do $$
declare
  def text;
  new_def text;
  fn constant regprocedure :=
    'public.record_task_completion(uuid, public.task_status, uuid, timestamptz, timestamptz, text)'::regprocedure;
begin
  def := pg_get_functiondef(fn);
  new_def := regexp_replace(
    def,
    'select p\.id\s+into caller_patient_id\s+from public\.patients p\s+'
    'where p\.user_id = caller_user_id\s+and p\.status = ''active'';',
    'select ti.patient_id into caller_patient_id
  from public.task_instances ti
  where ti.id = p_task_id;
  if not (select private.can_access_patient(caller_patient_id)) then
    -- Not this caller''s task: behave as before (own profile, task not found).
    caller_patient_id := private.resolve_acting_patient(null);
  end if;', 'i');
  if new_def = def then
    raise exception 'Could not patch record_task_completion';
  end if;
  execute new_def;
end $$;

-- 4d. mark_patient_notification_opened: opens an event of any accessible
--     profile. Whitespace tolerant on purpose: the Production body matched
--     the repository text but differs in line endings or spacing, which broke an
--     exact text match in the first Production dry run (2026-11-20).
do $$
declare
  def text;
  new_def text;
  fn constant regprocedure :=
    'public.mark_patient_notification_opened(uuid)'::regprocedure;
begin
  def := pg_get_functiondef(fn);
  new_def := regexp_replace(
    def,
    'caller_patient_id\s*:=\s*\(\s*select\s+private\.current_patient_id\(\)\s*\)\s*;'
    '\s*if\s+caller_patient_id\s+is\s+null\s+or\s+p_notification_id\s+is\s+null\s+then'
    '\s*return\s+false\s*;\s*end\s+if\s*;',
    'if p_notification_id is null then return false; end if;',
    'i');
  new_def := regexp_replace(
    new_def,
    'and\s+ne\.patient_id\s*=\s*caller_patient_id',
    'and (select private.can_access_patient(ne.patient_id))',
    'i');
  if new_def = def or new_def ilike '%current_patient_id%'
     or new_def not ilike '%can_access_patient(ne.patient_id)%' then
    raise exception 'Could not patch mark_patient_notification_opened';
  end if;
  execute new_def;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Family management RPCs
-- ---------------------------------------------------------------------------

-- The caller's selectable profiles. A single-patient account returns exactly
-- one row, so older accounts need no migration. Only patient-visible fields.
create or replace function public.my_family_profiles()
returns table (
  patient_id uuid,
  full_name text,
  relationship_label text,
  display_order integer,
  is_primary boolean,
  family_id uuid,
  family_label text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.full_name,
    fm.relationship_label,
    coalesce(fm.display_order, 0),
    coalesce(p.user_id = (select auth.uid()), false),
    fa.id,
    fa.label
  from private.accessible_patient_ids() a(id)
  join public.patients p on p.id = a.id
  left join public.family_members fm
    on fm.patient_id = p.id and fm.unlinked_at is null
  left join public.family_accounts fa on fa.id = fm.family_id
  order by coalesce(p.user_id = (select auth.uid()), false) desc,
    coalesce(fm.display_order, 0), p.full_name, p.id;
$$;

revoke all on function public.my_family_profiles() from public, anon;
grant execute on function public.my_family_profiles() to authenticated;

-- Staff: turn an existing patient account (the owner's own profile) into a
-- family, or return the family it already owns. Idempotent.
create or replace function public.admin_create_family(
  p_owner_patient_id uuid,
  p_label text default null,
  p_crm_family_id text default null
)
returns public.family_accounts
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  owner_patient public.patients%rowtype;
  fam public.family_accounts%rowtype;
begin
  if not (select private.is_care_staff()) then
    raise exception 'Staff access is required.' using errcode = '42501';
  end if;

  select * into owner_patient from public.patients
  where id = p_owner_patient_id and status = 'active';
  if not found or owner_patient.user_id is null then
    raise exception 'The owner profile must be an active patient with a login.'
      using errcode = '22023';
  end if;

  select * into fam from public.family_accounts
  where owner_user_id = owner_patient.user_id;

  if not found then
    insert into public.family_accounts (owner_user_id, label, crm_family_id, created_by)
    values (owner_patient.user_id, nullif(btrim(p_label), ''),
      nullif(btrim(p_crm_family_id), ''), actor)
    returning * into fam;

    insert into public.family_members (family_id, patient_id, display_order, linked_by)
    values (fam.id, owner_patient.id, 0, actor);

    insert into public.admin_audit_logs
      (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
    values (actor, 'family.created', 'family_account', fam.id, owner_patient.id,
      jsonb_build_object('crm_family_id', fam.crm_family_id));
  end if;
  return fam;
end;
$$;

create or replace function public.admin_add_family_member(
  p_family_id uuid,
  p_patient_id uuid,
  p_relationship_label text default null,
  p_display_order integer default null
)
returns public.family_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  fam public.family_accounts%rowtype;
  member public.family_members%rowtype;
  other_family uuid;
begin
  if not (select private.is_care_staff()) then
    raise exception 'Staff access is required.' using errcode = '42501';
  end if;

  select * into fam from public.family_accounts
  where id = p_family_id and status = 'active';
  if not found then
    raise exception 'Family was not found.' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.patients where id = p_patient_id and status = 'active'
  ) then
    raise exception 'Patient profile was not found.' using errcode = 'P0002';
  end if;

  -- Never silently move a profile between families.
  select fm.family_id into other_family from public.family_members fm
  where fm.patient_id = p_patient_id and fm.unlinked_at is null;
  if other_family is not null and other_family <> p_family_id then
    raise exception 'This profile already belongs to another family.'
      using errcode = '23505';
  end if;
  -- A profile with its own login can only be the owner's profile.
  if exists (
    select 1 from public.patients
    where id = p_patient_id and user_id is not null
      and user_id <> fam.owner_user_id
  ) then
    raise exception 'This profile has its own login and cannot be linked.'
      using errcode = '23505';
  end if;

  select * into member from public.family_members
  where family_id = p_family_id and patient_id = p_patient_id
    and unlinked_at is null;
  if found then
    return member;
  end if;

  insert into public.family_members
    (family_id, patient_id, relationship_label, display_order, linked_by)
  values (
    p_family_id, p_patient_id, nullif(btrim(p_relationship_label), ''),
    coalesce(p_display_order, (
      select coalesce(max(display_order), 0) + 1
      from public.family_members where family_id = p_family_id
    )),
    actor)
  returning * into member;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (actor, 'family.member_linked', 'family_member', member.id, p_patient_id,
    jsonb_build_object('family_id', p_family_id));
  return member;
end;
$$;

create or replace function public.admin_remove_family_member(
  p_family_id uuid,
  p_patient_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  fam public.family_accounts%rowtype;
  rows_changed integer;
begin
  if not (select private.is_care_staff()) then
    raise exception 'Staff access is required.' using errcode = '42501';
  end if;
  select * into fam from public.family_accounts where id = p_family_id;
  if not found then
    raise exception 'Family was not found.' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from public.patients
    where id = p_patient_id and user_id = fam.owner_user_id
  ) then
    raise exception 'The owner profile cannot be unlinked.'
      using errcode = '22023';
  end if;

  update public.family_members
  set unlinked_at = now(), unlinked_by = actor
  where family_id = p_family_id and patient_id = p_patient_id
    and unlinked_at is null;
  get diagnostics rows_changed = row_count;

  if rows_changed > 0 then
    -- Devices that had this profile selected must stop receiving its
    -- reminders. No clinical record is touched.
    update public.notification_devices
    set patient_id = (
      select p.id from public.patients p where p.user_id = fam.owner_user_id
    )
    where user_id = fam.owner_user_id and patient_id = p_patient_id;

    insert into public.admin_audit_logs
      (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
    values (actor, 'family.member_unlinked', 'family_account', p_family_id,
      p_patient_id, '{}'::jsonb);
  end if;
  return rows_changed > 0;
end;
$$;

revoke all on function public.admin_create_family(uuid, text, text) from public, anon;
revoke all on function public.admin_add_family_member(uuid, uuid, text, integer)
  from public, anon;
revoke all on function public.admin_remove_family_member(uuid, uuid) from public, anon;
grant execute on function public.admin_create_family(uuid, text, text) to authenticated;
grant execute on function public.admin_add_family_member(uuid, uuid, text, integer)
  to authenticated;
grant execute on function public.admin_remove_family_member(uuid, uuid) to authenticated;

comment on table public.family_accounts is
  'One row per shared family login. Writes only through audited staff functions.';
comment on table public.family_members is
  'Patient profiles under a family login. Unlinking keeps all clinical records.';
