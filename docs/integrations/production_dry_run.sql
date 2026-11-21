-- DRY RUN: everything below is rolled back at the end.
begin;
-- Fail fast instead of queueing behind live traffic.
set local lock_timeout = '3s';
set local statement_timeout = '60s';

-- Pre-flight: the objects these migrations rewrite must look as expected.
do $$
begin
  if to_regclass('public.care_templates') is null
     or to_regclass('public.staff_members') is null
     or to_regclass('public.personal_routines') is null then
    raise exception 'PRE-FLIGHT FAILED: the database is missing earlier migrations.';
  end if;
  if to_regclass('public.family_accounts') is not null then
    raise exception 'PRE-FLIGHT FAILED: family_accounts already exists (already applied?).';
  end if;
end $$;
-- ==== 20261120090000_family_accounts
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
-- ==== 20261120100000_integration_template_catalog
-- CRM/ERP integration: versioned export of the official Sukun care templates.
--
-- PURPOSE
--   The SukunLife catalog (`public.care_templates`) stays the single master.
--   This read-only function returns a deterministic, versioned JSON document
--   that the CRM mirrors. It is callable ONLY by the service role (the
--   `integration-templates` Edge Function, after verifying the CRM request);
--   `anon` and `authenticated` cannot execute it.
--
-- SAFETY
--   * No table, policy or data change. Pure read function.
--   * Exposes template content only: no patient data, no staff notes, no
--     timestamps inside the revision hash (so a revision changes only when
--     content changes).
--   * Hidden templates are returned with `active: false` (never silently
--     dropped) so the CRM can mirror deactivation without deleting history.
--
-- ROLLBACK
--   drop function public.integration_export_template_catalog(timestamptz, text, integer);

create or replace function public.integration_export_template_catalog(
  p_updated_since timestamptz default null,
  p_after_id text default null,
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  page_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
  catalog_hash text;
  total_count integer;
  last_updated timestamptz;
  items jsonb;
  returned_count integer;
  next_cursor text;
begin
  -- Content hash over every template (active or hidden) in a fixed order.
  select
    encode(sha256(convert_to(coalesce(string_agg(
      jsonb_build_array(
        t.id, t.category, t.action_type, t.title, t.instruction,
        t.notification_title, t.default_times::text[], t.resource_refs,
        t.requires_resource, t.sort_order, t.is_active
      )::text, '|' order by t.id), ''), 'UTF8')), 'hex'),
    count(*)::integer,
    max(t.updated_at)
  into catalog_hash, total_count, last_updated
  from public.care_templates t;

  select coalesce(jsonb_agg(x.obj order by x.id), '[]'::jsonb), count(*)::integer
  into items, returned_count
  from (
    select
      t.id,
      jsonb_build_object(
        'template_id', t.id,
        'template_revision', 'sha256:' || encode(sha256(convert_to(
          jsonb_build_array(
            t.id, t.category, t.action_type, t.title, t.instruction,
            t.notification_title, t.default_times::text[], t.resource_refs,
            t.requires_resource, t.sort_order, t.is_active
          )::text, 'UTF8')), 'hex'),
        'category', t.category,
        'action_type', t.action_type,
        'title', t.title,
        'instruction', t.instruction,
        'notification_title', t.notification_title,
        'parameters', (
          -- Placeholders are read mechanically from the instruction text.
          select coalesce(jsonb_agg(jsonb_build_object(
            'name', ph.name,
            'placeholder', ph.token,
            'type', 'integer',
            'required', true
          ) order by ph.ord), '[]'::jsonb)
          from (values
            (1, 'count',   '{বার}'),
            (2, 'days',    '{দিন}'),
            (3, 'minutes', '{মিনিট}')
          ) ph(ord, name, token)
          where position(ph.token in t.instruction) > 0
        ),
        'default_schedule', jsonb_build_object(
          'reminder_times', (
            select coalesce(jsonb_agg(to_char(dt, 'HH24:MI') order by ord), '[]'::jsonb)
            from unnest(t.default_times) with ordinality d(dt, ord)
          ),
          'time_basis', 'patient_local'
        ),
        'resource_refs', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'ref', r.ref,
            'kind', case when r.ref ~ '^quran:[0-9]+$' then 'quran_surah' else 'content_slug' end
          ) order by r.ord), '[]'::jsonb)
          from unnest(t.resource_refs) with ordinality r(ref, ord)
        ),
        'requires_resource', t.requires_resource,
        'sort_order', t.sort_order,
        'active', t.is_active,
        'updated_at', to_char(t.updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
      ) as obj
    from public.care_templates t
    where (p_updated_since is null or t.updated_at > p_updated_since)
      and (p_after_id is null or t.id > p_after_id)
    order by t.id
    limit page_limit
  ) x;

  if returned_count = page_limit then
    next_cursor := items -> (returned_count - 1) ->> 'template_id';
  end if;

  return jsonb_build_object(
    'schema_version', '1.0',
    'catalog_version', 'sha256:' || catalog_hash,
    'catalog_last_updated_at',
      to_char(last_updated at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'generated_at',
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'total_templates', total_count,
    'sync_mode', case when p_updated_since is null then 'full' else 'incremental' end,
    'next_cursor', next_cursor,
    'templates', items
  );
end;
$$;

revoke all on function public.integration_export_template_catalog(timestamptz, text, integer)
  from public, anon, authenticated;
grant execute on function public.integration_export_template_catalog(timestamptz, text, integer)
  to service_role;

comment on function public.integration_export_template_catalog(timestamptz, text, integer) is
  'Service-role only. Deterministic versioned export of the official care templates for the CRM/ERP mirror.';
-- ==== 20261120110000_crm_integration_core
-- CRM/ERP integration core (SukunLife side). Service role only.
--
-- PURPOSE
--   * integration_inbox  : idempotency + audit of CRM events (prescriptions).
--   * integration_outbox : reliable, retried delivery of app progress events
--                          to the CRM (the app never calls the CRM directly).
--   * integration_link_patient : explicit CRM id mapping + family linking.
--   * integration_apply_prescription_event : applies a FINAL CRM prescription
--       (issued / updated / cancelled) as a new versioned care plan.
--   * integration_patient_progress : the single authoritative adherence
--       calculation the CRM reads.
--
-- SAFETY
--   * Every function is SECURITY DEFINER and executable by `service_role`
--     only. They are reached through Edge Functions that first verify the
--     CRM signature (see supabase/functions/_shared/crm_auth.ts). The
--     `p_actor_user_id` is a dedicated staff service user configured on the
--     server, never client supplied.
--   * Tables have RLS enabled and NO policies: no app role can read them.
--   * Nothing is deleted. A revision creates a new care plan version; the old
--     plan becomes `inactive`, which (existing trigger) cancels its future
--     pending tasks and scheduled reminders. Completion history is kept.
--   * AI is never involved. Missing counts, schedules or frequencies are
--     REJECTED, never guessed. Staff-only notes are not accepted at all.
--
-- ROLLBACK
--   drop function public.integration_* ; drop table public.integration_outbox,
--   public.integration_inbox; drop trigger/function task_completion_enqueue.
--   No existing table is altered.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.integration_inbox (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'crm',
  event_id text not null,
  event_type text not null,
  payload_hash text not null,
  status text not null,
  result jsonb not null default '{}'::jsonb,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint integration_inbox_status check (status in ('applied', 'rejected', 'stale')),
  constraint integration_inbox_event_not_blank check (btrim(event_id) <> ''),
  unique (source, event_id)
);

create table if not exists public.integration_outbox (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  patient_id uuid references public.patients (id) on delete cascade,
  dedupe_key text not null unique,
  payload jsonb not null,
  status text not null default 'pending',
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  acked_at timestamptz,
  constraint integration_outbox_status check (status in ('pending', 'sent', 'dead'))
);

create index if not exists integration_outbox_due_idx
  on public.integration_outbox (next_attempt_at) where status = 'pending';

alter table public.integration_inbox enable row level security;
alter table public.integration_outbox enable row level security;
revoke all on public.integration_inbox from public, anon, authenticated;
revoke all on public.integration_outbox from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Patient mapping and family linking
-- ---------------------------------------------------------------------------

create or replace function public.integration_link_patient(
  p_actor_user_id uuid,
  p_patient_id uuid,
  p_crm_patient_id text,
  p_crm_customer_id text default null,
  p_crm_family_id text default null,
  p_relationship_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_patient uuid;
  fam public.family_accounts%rowtype;
  patient_row public.patients%rowtype;
begin
  if nullif(btrim(p_crm_patient_id), '') is null then
    raise exception 'crm_patient_id is required.' using errcode = '22023';
  end if;
  select * into patient_row from public.patients
  where id = p_patient_id and status = 'active';
  if not found then
    raise exception 'Patient profile was not found.' using errcode = 'P0002';
  end if;

  -- Never silently merge two patients: an external id points to one patient.
  select patient_id into existing_patient from public.patient_external_refs
  where source_system = 'crm_patient' and external_id = btrim(p_crm_patient_id);
  if existing_patient is not null and existing_patient <> p_patient_id then
    raise exception 'This CRM patient id is already linked to another profile.'
      using errcode = '23505';
  end if;
  if exists (
    select 1 from public.patient_external_refs
    where patient_id = p_patient_id and source_system = 'crm_patient'
      and external_id <> btrim(p_crm_patient_id)
  ) then
    raise exception 'This profile is already linked to a different CRM patient.'
      using errcode = '23505';
  end if;

  insert into public.patient_external_refs (patient_id, source_system, external_id)
  values (p_patient_id, 'crm_patient', btrim(p_crm_patient_id))
  on conflict (source_system, external_id) do nothing;

  if nullif(btrim(p_crm_customer_id), '') is not null then
    select patient_id into existing_patient from public.patient_external_refs
    where source_system = 'crm_customer' and external_id = btrim(p_crm_customer_id);
    -- A customer may own several family profiles; only block a profile that
    -- already carries a different customer id.
    if exists (
      select 1 from public.patient_external_refs
      where patient_id = p_patient_id and source_system = 'crm_customer'
        and external_id <> btrim(p_crm_customer_id)
    ) then
      raise exception 'This profile is already linked to a different CRM customer.'
        using errcode = '23505';
    end if;
    insert into public.patient_external_refs (patient_id, source_system, external_id)
    values (p_patient_id, 'crm_customer', btrim(p_crm_customer_id))
    on conflict (source_system, external_id) do nothing;
  end if;

  if nullif(btrim(p_crm_family_id), '') is not null then
    select * into fam from public.family_accounts
    where crm_family_id = btrim(p_crm_family_id);
    if not found then
      -- The family login is created from the owner profile (it must have a
      -- login). A login-less profile cannot start a family.
      if patient_row.user_id is null then
        raise exception 'The CRM family is not linked yet; link its owner profile first.'
          using errcode = '22023';
      end if;
      select * into fam from public.family_accounts
      where owner_user_id = patient_row.user_id;
      if found then
        if fam.crm_family_id is not null then
          raise exception 'This login already belongs to a different CRM family.'
            using errcode = '23505';
        end if;
        update public.family_accounts set crm_family_id = btrim(p_crm_family_id),
          updated_at = now() where id = fam.id returning * into fam;
      else
        insert into public.family_accounts (owner_user_id, crm_family_id, created_by)
        values (patient_row.user_id, btrim(p_crm_family_id), p_actor_user_id)
        returning * into fam;
        insert into public.family_members (family_id, patient_id, display_order, linked_by)
        values (fam.id, p_patient_id, 0, p_actor_user_id);
      end if;
    end if;

    if not exists (
      select 1 from public.family_members
      where family_id = fam.id and patient_id = p_patient_id and unlinked_at is null
    ) then
      if exists (
        select 1 from public.family_members
        where patient_id = p_patient_id and unlinked_at is null
      ) then
        raise exception 'This profile already belongs to another family.'
          using errcode = '23505';
      end if;
      if patient_row.user_id is not null and patient_row.user_id <> fam.owner_user_id then
        raise exception 'This profile has its own login and cannot join the family.'
          using errcode = '23505';
      end if;
      insert into public.family_members
        (family_id, patient_id, relationship_label, display_order, linked_by)
      values (fam.id, p_patient_id, nullif(btrim(p_relationship_label), ''),
        (select coalesce(max(display_order), 0) + 1 from public.family_members
          where family_id = fam.id), p_actor_user_id);
    end if;
  end if;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (p_actor_user_id, 'integration.patient_linked', 'patient', p_patient_id,
    p_patient_id, jsonb_build_object('crm_patient_id', btrim(p_crm_patient_id),
      'crm_family_id', nullif(btrim(p_crm_family_id), '')));

  return jsonb_build_object('patient_id', p_patient_id,
    'family_id', fam.id, 'crm_patient_id', btrim(p_crm_patient_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Prescription events
-- ---------------------------------------------------------------------------

create or replace function private.integration_reject(
  p_event_id text, p_event_type text, p_hash text, p_event jsonb,
  p_code text, p_detail jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb := jsonb_build_object('status', 'rejected', 'code', p_code,
    'detail', p_detail);
begin
  insert into public.integration_inbox
    (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
  values ('crm', p_event_id, p_event_type, p_hash, 'rejected', result, p_event, now())
  on conflict (source, event_id) do update
    set payload_hash = excluded.payload_hash, status = 'rejected',
        result = excluded.result, payload = excluded.payload,
        event_type = excluded.event_type, processed_at = now()
    where public.integration_inbox.status = 'rejected';
  return result;
end;
$$;

create or replace function public.integration_apply_prescription_event(
  p_actor_user_id uuid,
  p_event jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ev_id text := p_event ->> 'event_id';
  ev_type text := p_event ->> 'event_type';
  rx jsonb := p_event -> 'prescription';
  pt jsonb := p_event -> 'patient';
  ph text;
  inbox public.integration_inbox%rowtype;
  v_patient uuid;
  v_family_crm text;
  v_actual_family_crm text;
  v_rx_id text := rx ->> 'crm_prescription_id';
  v_version integer;
  v_prescription public.prescriptions%rowtype;
  v_latest integer;
  v_start date;
  v_end date;
  v_plan public.care_plans%rowtype;
  v_old_plan uuid;
  v_next_plan_version integer;
  item jsonb;
  tpl public.care_templates%rowtype;
  tpl_revision text;
  v_times text[];
  t text;
  v_text text;
  v_title text;
  v_count integer;
  v_minutes integer;
  v_days integer;
  v_freq jsonb;
  v_item_start date;
  v_item_end date;
  v_action_id uuid;
  v_sort integer := 0;
  seen_items text[] := '{}';
  ref text;
  v_content uuid;
  v_ref_sort integer;
  warnings jsonb := '[]'::jsonb;
  action_count integer := 0;
  raw_lines text[] := '{}';
  result jsonb;
  surah_no integer;
begin
  if p_actor_user_id is null or not exists (
    select 1 from public.user_roles
    where user_id = p_actor_user_id and role::text in ('super_admin', 'raqi')
  ) then
    raise exception 'A staff service actor is required.' using errcode = '42501';
  end if;
  if ev_id is null or btrim(ev_id) = '' or ev_type is null then
    raise exception 'event_id and event_type are required.' using errcode = '22023';
  end if;

  ph := encode(sha256(convert_to(p_event::text, 'UTF8')), 'hex');
  perform pg_advisory_xact_lock(hashtextextended('crm-event:' || ev_id, 0));

  select * into inbox from public.integration_inbox
  where source = 'crm' and event_id = ev_id;
  if found then
    if inbox.payload_hash <> ph then
      return jsonb_build_object('status', 'rejected', 'code', 'event_id_reuse_conflict');
    end if;
    if inbox.status in ('applied', 'stale') then
      return inbox.result || jsonb_build_object('replayed', true);
    end if;
    -- A previously rejected event is re-evaluated (e.g. after mapping).
  end if;

  if ev_type not in ('prescription.issued', 'prescription.updated', 'prescription.cancelled')
     or p_event ->> 'schema_version' is distinct from '1.0'
     or rx is null or pt is null or v_rx_id is null or btrim(v_rx_id) = ''
     or (rx ->> 'version') is null or (rx ->> 'version') !~ '^[0-9]{1,6}$'
     or (pt ->> 'crm_patient_id') is null then
    return private.integration_reject(ev_id, coalesce(ev_type, 'unknown'), ph, p_event, 'invalid_event');
  end if;
  v_version := (rx ->> 'version')::integer;
  if v_version < 1 then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'invalid_event');
  end if;

  -- Identity: explicit mapping only. Never matched by phone or name.
  select patient_id into v_patient from public.patient_external_refs
  where source_system = 'crm_patient' and external_id = btrim(pt ->> 'crm_patient_id');
  if v_patient is null or not exists (
    select 1 from public.patients where id = v_patient and status = 'active'
  ) then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'patient_not_mapped',
      jsonb_build_object('crm_patient_id', pt ->> 'crm_patient_id'));
  end if;

  v_family_crm := nullif(btrim(pt ->> 'crm_family_id'), '');
  if v_family_crm is not null then
    select fa.crm_family_id into v_actual_family_crm
    from public.family_members fm
    join public.family_accounts fa on fa.id = fm.family_id
    where fm.patient_id = v_patient and fm.unlinked_at is null;
    if v_actual_family_crm is distinct from v_family_crm then
      return private.integration_reject(ev_id, ev_type, ph, p_event, 'family_mismatch',
        jsonb_build_object('crm_family_id', v_family_crm));
    end if;
  end if;

  select * into v_prescription from public.prescriptions
  where patient_id = v_patient and source_type = 'imported'
    and source_external_id = btrim(v_rx_id)
  for update;

  if found then
    select coalesce(max(version), 0) into v_latest
    from public.prescription_versions where prescription_id = v_prescription.id;
    if v_version <= v_latest then
      -- Out of order or already superseded: never overwrite a newer version.
      result := jsonb_build_object('status', 'stale', 'current_version', v_latest,
        'received_version', v_version);
      insert into public.integration_inbox
        (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
      values ('crm', ev_id, ev_type, ph, 'stale', result, p_event, now())
      on conflict (source, event_id) do update
        set payload_hash = excluded.payload_hash, status = 'stale',
            result = excluded.result, payload = excluded.payload, processed_at = now();
      return result;
    end if;
  end if;

  -- ---------------- cancellation ----------------
  if ev_type = 'prescription.cancelled' then
    if v_prescription.id is null then
      return private.integration_reject(ev_id, ev_type, ph, p_event, 'prescription_not_found');
    end if;
    update public.care_plans set status = 'inactive'
    where patient_id = v_patient and prescription_id = v_prescription.id
      and status = 'active';
    insert into public.prescription_versions
      (prescription_id, version, raw_text, visibility, change_note, created_by)
    values (v_prescription.id, v_version, 'Cancelled by clinic', 'patient',
      'cancelled', p_actor_user_id);
    update public.prescriptions set archived_at = now() where id = v_prescription.id;

    insert into public.admin_audit_logs
      (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
    values (p_actor_user_id, 'integration.prescription_cancelled', 'prescription',
      v_prescription.id, v_patient, jsonb_build_object('event_id', ev_id,
        'crm_prescription_id', v_rx_id, 'version', v_version));
    result := jsonb_build_object('status', 'applied', 'patient_id', v_patient,
      'prescription_id', v_prescription.id, 'version', v_version, 'care_plan_id', null);
    insert into public.integration_inbox
      (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
    values ('crm', ev_id, ev_type, ph, 'applied', result, p_event, now())
    on conflict (source, event_id) do update
      set payload_hash = excluded.payload_hash, status = 'applied',
          result = excluded.result, payload = excluded.payload, processed_at = now();
    return result;
  end if;

  -- ---------------- issue / revise ----------------
  if coalesce(rx ->> 'status', 'issued') <> 'issued' then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'prescription_not_final');
  end if;
  if (rx ->> 'start_date') is null or (rx ->> 'start_date') !~ '^\d{4}-\d{2}-\d{2}$' then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'missing_start_date');
  end if;
  v_start := (rx ->> 'start_date')::date;
  v_end := nullif(rx ->> 'end_date', '')::date;
  if v_end is not null and v_end < v_start then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'invalid_date_range');
  end if;
  if jsonb_typeof(p_event -> 'items') is distinct from 'array'
     or jsonb_array_length(p_event -> 'items') = 0 then
    return private.integration_reject(ev_id, ev_type, ph, p_event, 'no_items');
  end if;

  -- New draft plan version; flipped to active after its actions are in place.
  select coalesce(max(version), 0) + 1 into v_next_plan_version
  from public.care_plans where patient_id = v_patient;

  if v_prescription.id is null then
    insert into public.prescriptions
      (patient_id, source_type, source_external_id, raw_text, session_date,
       visibility, created_by)
    values (v_patient, 'imported', btrim(v_rx_id), 'pending',
      nullif(rx ->> 'issued_at', '')::timestamptz::date, 'patient', p_actor_user_id)
    returning * into v_prescription;
  end if;

  insert into public.care_plans
    (patient_id, prescription_id, version, name, start_date, end_date, status, created_by)
  values (v_patient, v_prescription.id, v_next_plan_version,
    'Rx ' || btrim(v_rx_id) || ' v' || v_version, v_start, v_end, 'draft', p_actor_user_id)
  returning * into v_plan;

  for item in select * from jsonb_array_elements(p_event -> 'items') loop
    if (item ->> 'item_id') is null or (item ->> 'item_id') = ANY (seen_items)
       or (item ->> 'template_id') is null then
      raise exception 'REJECT:invalid_item' using errcode = 'P0001';
    end if;
    seen_items := seen_items || (item ->> 'item_id');

    select * into tpl from public.care_templates where id = item ->> 'template_id';
    if not found then
      raise exception 'REJECT:template_not_found:%', item ->> 'template_id' using errcode = 'P0001';
    end if;
    if not tpl.is_active then
      raise exception 'REJECT:template_inactive:%', tpl.id using errcode = 'P0001';
    end if;
    tpl_revision := 'sha256:' || encode(sha256(convert_to(jsonb_build_array(
      tpl.id, tpl.category, tpl.action_type, tpl.title, tpl.instruction,
      tpl.notification_title, tpl.default_times::text[], tpl.resource_refs,
      tpl.requires_resource, tpl.sort_order, tpl.is_active)::text, 'UTF8')), 'hex');
    if (item ->> 'template_revision') is not null
       and item ->> 'template_revision' <> tpl_revision then
      warnings := warnings || jsonb_build_object('code', 'template_revision_mismatch',
        'item_id', item ->> 'item_id', 'template_id', tpl.id);
    end if;

    v_count := nullif(item ->> 'count', '')::integer;
    v_minutes := nullif(item ->> 'minutes', '')::integer;
    v_days := nullif(item ->> 'days', '')::integer;
    if coalesce(v_count, 1) < 1 or coalesce(v_minutes, 1) < 1 or coalesce(v_days, 1) < 1 then
      raise exception 'REJECT:invalid_parameter:%', item ->> 'item_id' using errcode = 'P0001';
    end if;

    v_text := coalesce(nullif(btrim(item ->> 'patient_instruction'), ''), tpl.instruction);
    v_title := coalesce(nullif(btrim(item ->> 'title'), ''), tpl.title);

    if position('{বার}' in v_text) > 0 then
      if v_count is null then
        raise exception 'REJECT:missing_parameter:%:count', item ->> 'item_id' using errcode = 'P0001';
      end if;
      v_text := replace(v_text, '{বার}', v_count::text);
    end if;
    if position('{মিনিট}' in v_text) > 0 then
      if v_minutes is null then
        raise exception 'REJECT:missing_parameter:%:minutes', item ->> 'item_id' using errcode = 'P0001';
      end if;
      v_text := replace(v_text, '{মিনিট}', v_minutes::text);
    end if;
    if position('{দিন}' in v_text) > 0 then
      if v_days is null then
        raise exception 'REJECT:missing_parameter:%:days', item ->> 'item_id' using errcode = 'P0001';
      end if;
      v_text := replace(v_text, '{দিন}', v_days::text);
    end if;

    v_freq := item -> 'frequency';
    if jsonb_typeof(v_freq) is distinct from 'object'
       or (v_freq ->> 'type') not in ('daily', 'weekly', 'dates') then
      raise exception 'REJECT:missing_frequency:%', item ->> 'item_id' using errcode = 'P0001';
    end if;

    v_item_start := coalesce(nullif(item ->> 'start_date', '')::date, v_start);
    v_item_end := case
      when (item ->> 'duration_days') is not null
        then v_item_start + ((item ->> 'duration_days')::integer - 1)
      else coalesce(nullif(item ->> 'end_date', '')::date, v_end) end;

    if jsonb_typeof(item -> 'reminder_times') is distinct from 'array' then
      raise exception 'REJECT:missing_reminder_times:%', item ->> 'item_id' using errcode = 'P0001';
    end if;
    select coalesce(array_agg(x order by x), '{}') into v_times
    from jsonb_array_elements_text(item -> 'reminder_times') x;
    if exists (select 1 from unnest(v_times) y where y !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') then
      raise exception 'REJECT:invalid_reminder_time:%', item ->> 'item_id' using errcode = 'P0001';
    end if;
    if cardinality(v_times) = 0 then
      v_times := array[null::text];
    end if;

    raw_lines := raw_lines || (v_title || ' - ' || v_text);

    foreach t in array v_times loop
      insert into public.plan_actions
        (care_plan_id, type, title, instruction, count_target, duration_minutes,
         frequency_rule, exact_time, start_date, end_date, sort_order,
         review_status, reminder_enabled, notification_title, created_by)
      values (v_plan.id, tpl.action_type, v_title, v_text, v_count, v_minutes,
        v_freq, t::time, v_item_start, v_item_end, v_sort, 'approved',
        t is not null, tpl.notification_title, p_actor_user_id)
      returning id into v_action_id;
      v_sort := v_sort + 1;
      action_count := action_count + 1;

      -- Resource links: only published, patient-accessible content; anything
      -- else is skipped and reported, never invented.
      v_ref_sort := 0;
      for ref in
        select r from unnest(
          case when jsonb_typeof(item -> 'resource_refs') = 'array'
            then array(select jsonb_array_elements_text(item -> 'resource_refs'))
            else tpl.resource_refs end) r
      loop
        exit when v_ref_sort >= 15;
        if ref ~ '^quran:[0-9]+$' then
          surah_no := substring(ref from 7)::integer;
          if surah_no between 1 and 114 then
            insert into public.plan_action_quran_surahs
              (plan_action_id, surah_number, title, sort_order, created_by)
            values (v_action_id, surah_no, 'Surah ' || surah_no, v_ref_sort, p_actor_user_id)
            on conflict do nothing;
            v_ref_sort := v_ref_sort + 1;
          end if;
        else
          select ci.id into v_content from public.content_items ci
          where ci.slug = ref and ci.status = 'published'
            and ci.visibility in ('public', 'patient_only', 'assigned_only');
          if v_content is null then
            warnings := warnings || jsonb_build_object('code', 'resource_skipped',
              'ref', ref, 'item_id', item ->> 'item_id');
          else
            insert into public.plan_action_resources
              (plan_action_id, content_item_id, created_by, sort_order)
            values (v_action_id, v_content, p_actor_user_id, v_ref_sort)
            on conflict do nothing;
            v_ref_sort := v_ref_sort + 1;
          end if;
        end if;
      end loop;
    end loop;
  end loop;

  update public.prescriptions
  set raw_text = coalesce(nullif(btrim(rx ->> 'patient_visible_note'), ''),
        array_to_string(raw_lines, E'\n'))
  where id = v_prescription.id;
  insert into public.prescription_versions
    (prescription_id, version, raw_text, visibility, change_note, created_by)
  values (v_prescription.id, v_version,
    coalesce(nullif(btrim(rx ->> 'patient_visible_note'), ''), array_to_string(raw_lines, E'\n')),
    'patient', ev_type, p_actor_user_id);

  -- Publish: previous active plan becomes inactive (existing trigger cancels
  -- its future pending tasks and scheduled reminders).
  select id into v_old_plan from public.care_plans
  where patient_id = v_patient and status = 'active';
  update public.care_plans set status = 'inactive'
  where patient_id = v_patient and status = 'active';
  update public.care_plans
  set status = 'active', published_at = now(), published_by = p_actor_user_id
  where id = v_plan.id;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (p_actor_user_id, 'integration.prescription_applied', 'care_plan',
    v_plan.id, v_patient, jsonb_build_object('event_id', ev_id,
      'crm_prescription_id', v_rx_id, 'version', v_version,
      'plan_version', v_next_plan_version, 'actions', action_count,
      'replaced_plan_id', v_old_plan));

  result := jsonb_build_object('status', 'applied', 'patient_id', v_patient,
    'prescription_id', v_prescription.id, 'version', v_version,
    'care_plan_id', v_plan.id, 'care_plan_version', v_next_plan_version,
    'actions_created', action_count, 'warnings', warnings);
  insert into public.integration_inbox
    (source, event_id, event_type, payload_hash, status, result, payload, processed_at)
  values ('crm', ev_id, ev_type, ph, 'applied', result, p_event, now())
  on conflict (source, event_id) do update
    set payload_hash = excluded.payload_hash, status = 'applied',
        result = excluded.result, payload = excluded.payload, processed_at = now();
  return result;

exception
  when sqlstate 'P0001' then
    -- Business rejection raised from inside the item loop: everything done
    -- for this event is rolled back (implicit subtransaction), then recorded.
    if sqlerrm like 'REJECT:%' then
      return private.integration_reject(ev_id, ev_type, ph, p_event,
        split_part(substring(sqlerrm from 8), ':', 1),
        jsonb_build_object('info', substring(sqlerrm from 8)));
    end if;
    raise;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Progress: outbox enqueue + delivery RPCs + authoritative summary
-- ---------------------------------------------------------------------------

create or replace function private.enqueue_task_completion_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  crm_patient text;
  info record;
begin
  select external_id into crm_patient from public.patient_external_refs
  where patient_id = new.patient_id and source_system = 'crm_patient'
  order by created_at limit 1;
  if crm_patient is null then
    return new;   -- Patients without a CRM link are never exported.
  end if;

  select ti.occurrence_date, pa.id as plan_action_id, cp.id as care_plan_id,
         cp.version as care_plan_version, rx.source_external_id as crm_prescription_id
  into info
  from public.task_instances ti
  join public.plan_actions pa on pa.id = ti.plan_action_id
  join public.care_plans cp on cp.id = pa.care_plan_id
  left join public.prescriptions rx on rx.id = cp.prescription_id
  where ti.id = new.task_instance_id;

  insert into public.integration_outbox (event_type, patient_id, dedupe_key, payload)
  values (
    'progress.task_' || new.status::text,
    new.patient_id,
    'task_completion:' || new.id::text,
    jsonb_build_object(
      'schema_version', '1.0',
      'event_id', new.id,
      'event_type', 'progress.task_' || new.status::text,
      'occurred_at', to_char(new.occurred_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'crm_patient_id', crm_patient,
      'sukun_patient_id', new.patient_id,
      'crm_prescription_id', info.crm_prescription_id,
      'care_plan_id', info.care_plan_id,
      'care_plan_version', info.care_plan_version,
      'plan_action_id', info.plan_action_id,
      'task_instance_id', new.task_instance_id,
      'occurrence_date', info.occurrence_date,
      'status', new.status
    ))
  on conflict (dedupe_key) do nothing;
  return new;
end;
$$;

drop trigger if exists task_completions_enqueue_integration on public.task_completions;
create trigger task_completions_enqueue_integration
after insert on public.task_completions
for each row execute function private.enqueue_task_completion_event();

create or replace function public.integration_claim_outbox(
  p_limit integer default 50,
  p_lease_seconds integer default 300
)
returns setof public.integration_outbox
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with due as (
    select o.id from public.integration_outbox o
    where o.status = 'pending' and o.next_attempt_at <= now()
    order by o.next_attempt_at, o.created_at
    limit least(greatest(coalesce(p_limit, 50), 1), 200)
    for update skip locked
  )
  update public.integration_outbox o
  set attempts = o.attempts + 1,
      next_attempt_at = now() + make_interval(secs => greatest(coalesce(p_lease_seconds, 300), 30))
  from due where o.id = due.id
  returning o.*;
end;
$$;

create or replace function public.integration_ack_outbox(p_ids uuid[])
returns integer
language sql
security definer
set search_path = ''
as $$
  with done as (
    update public.integration_outbox
    set status = 'sent', acked_at = now(), last_error = null
    where id = any (p_ids) and status = 'pending'
    returning 1
  ) select count(*)::integer from done;
$$;

create or replace function public.integration_fail_outbox(
  p_id uuid, p_error text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.integration_outbox%rowtype;
  new_status text;
begin
  select * into o from public.integration_outbox where id = p_id for update;
  if not found or o.status <> 'pending' then return 'ignored'; end if;
  -- Exponential backoff (1,2,4,... minutes, capped at 6 hours); dead letter
  -- after 12 attempts for manual reconciliation. The error text is truncated
  -- and must never contain patient data.
  new_status := case when o.attempts >= 12 then 'dead' else 'pending' end;
  update public.integration_outbox
  set status = new_status,
      last_error = left(coalesce(p_error, 'delivery_failed'), 300),
      next_attempt_at = now() + make_interval(
        mins => least(power(2, greatest(o.attempts - 1, 0))::integer, 360))
  where id = p_id;
  return new_status;
end;
$$;

create or replace function public.integration_patient_progress(
  p_crm_patient_id text,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_patient uuid;
  totals jsonb;
  daily jsonb;
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    raise exception 'A date range of at most 93 days is required.' using errcode = '22023';
  end if;
  select patient_id into v_patient from public.patient_external_refs
  where source_system = 'crm_patient' and external_id = btrim(p_crm_patient_id);
  if v_patient is null then
    raise exception 'Patient is not linked.' using errcode = 'P0002';
  end if;

  select jsonb_build_object(
    'total', count(*) filter (where ti.status <> 'cancelled'),
    'completed', count(*) filter (where ti.status = 'completed'),
    'pending', count(*) filter (where ti.status = 'pending'),
    'snoozed', count(*) filter (where ti.status = 'snoozed'),
    'skipped', count(*) filter (where ti.status = 'skipped'),
    'missed', count(*) filter (where ti.status = 'missed'),
    'adherence_percent', case when count(*) filter (where ti.status <> 'cancelled') = 0 then null
      else round(100.0 * count(*) filter (where ti.status = 'completed')
        / count(*) filter (where ti.status <> 'cancelled'), 1) end)
  into totals
  from public.task_instances ti
  where ti.patient_id = v_patient and ti.occurrence_date between p_from and p_to;

  select coalesce(jsonb_agg(d order by d ->> 'date'), '[]'::jsonb) into daily
  from (
    select jsonb_build_object('date', ti.occurrence_date,
      'total', count(*) filter (where ti.status <> 'cancelled'),
      'completed', count(*) filter (where ti.status = 'completed'),
      'skipped', count(*) filter (where ti.status = 'skipped'),
      'pending', count(*) filter (where ti.status in ('pending', 'snoozed'))) as d
    from public.task_instances ti
    where ti.patient_id = v_patient and ti.occurrence_date between p_from and p_to
    group by ti.occurrence_date
  ) x;

  return jsonb_build_object('schema_version', '1.0',
    'crm_patient_id', btrim(p_crm_patient_id), 'from', p_from, 'to', p_to,
    'totals', totals, 'daily', daily);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Grants: service role only
-- ---------------------------------------------------------------------------

revoke all on function public.integration_link_patient(uuid, uuid, text, text, text, text)
  from public, anon, authenticated;
revoke all on function public.integration_apply_prescription_event(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.integration_claim_outbox(integer, integer)
  from public, anon, authenticated;
revoke all on function public.integration_ack_outbox(uuid[]) from public, anon, authenticated;
revoke all on function public.integration_fail_outbox(uuid, text) from public, anon, authenticated;
revoke all on function public.integration_patient_progress(text, date, date)
  from public, anon, authenticated;
revoke all on function private.integration_reject(text, text, text, jsonb, text, jsonb)
  from public, anon, authenticated;
revoke all on function private.enqueue_task_completion_event()
  from public, anon, authenticated;

grant execute on function public.integration_link_patient(uuid, uuid, text, text, text, text)
  to service_role;
grant execute on function public.integration_apply_prescription_event(uuid, jsonb)
  to service_role;
grant execute on function public.integration_claim_outbox(integer, integer) to service_role;
grant execute on function public.integration_ack_outbox(uuid[]) to service_role;
grant execute on function public.integration_fail_outbox(uuid, text) to service_role;
grant execute on function public.integration_patient_progress(text, date, date)
  to service_role;
grant usage on schema private to service_role;
grant execute on function private.integration_reject(text, text, text, jsonb, text, jsonb)
  to service_role;
-- ==== 20261120120000_patient_provisioning_credentials
-- CRM patient provisioning with a generated temporary credential (phase 4).
--
-- OWNER DECISION 2026-11-20: no WhatsApp integration for now. SukunLife
-- generates the patient ID and a temporary password; staff send them to the
-- patient by hand. The CRM never supplies a password, and the temporary one
-- forces a change at first login (existing `profiles.requires_credential_change`
-- flow), after which the patient owns a permanent password nobody else knows.
--
-- DESIGN
--   * `integration_provision_patient` creates the patient row for an
--     integration actor (staff), with or without a login (a profile without a
--     login is a family member). Idempotent by request id.
--   * `integration_patient_credential_state` tells the gateway whether this
--     profile needs a temporary credential. An already activated account
--     (requires_credential_change = false) is NEVER given a new password, so an
--     existing permanent password cannot be reset by a new CRM prescription.
--   * `integration_record_credential_issue` writes the audit row. The password
--     itself is never stored or logged anywhere in SukunLife.
--   * Service role only.
--
-- ROLLBACK
--   drop function public.integration_provision_patient,
--   public.integration_patient_credential_state,
--   public.integration_record_credential_issue, private.require_integration_actor;

create or replace function private.require_integration_actor(p_actor uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_actor is null or not exists (
    select 1 from public.user_roles
    where user_id = p_actor and role::text in ('super_admin', 'raqi')
  ) then
    raise exception 'A staff service actor is required.' using errcode = '42501';
  end if;
end;
$$;

-- Creates (or returns, by request id) the patient row. p_user_id null makes a
-- login-less family profile.
create or replace function public.integration_provision_patient(
  p_actor_user_id uuid,
  p_user_id uuid,
  p_full_name text,
  p_phone text,
  p_patient_code text,
  p_request_id uuid
)
returns public.patients
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing uuid;
  created public.patients%rowtype;
begin
  perform private.require_integration_actor(p_actor_user_id);
  if p_request_id is null or nullif(btrim(p_full_name), '') is null
     or nullif(btrim(p_patient_code), '') is null then
    raise exception 'Name, patient code and request id are required.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('provision:' || p_request_id::text, 0));

  select entity_id into existing from public.admin_audit_logs
  where actor_user_id = p_actor_user_id and action = 'patient.created'
    and request_id = p_request_id;
  if existing is not null then
    select * into created from public.patients where id = existing;
    if found then return created; end if;
  end if;

  if p_user_id is not null then
    if not exists (select 1 from auth.users where id = p_user_id) then
      raise exception 'The patient account was not found.' using errcode = 'P0002';
    end if;
    insert into public.profiles (id, display_name, requires_credential_change)
    values (p_user_id, btrim(p_full_name), true)
    on conflict (id) do update
      set display_name = excluded.display_name, requires_credential_change = true;
    insert into public.user_roles (user_id, role, granted_by)
    values (p_user_id, 'patient', p_actor_user_id)
    on conflict (user_id, role) do nothing;
    delete from public.user_roles
    where user_id = p_user_id and role = 'member'::public.app_role;
  end if;

  insert into public.patients (user_id, patient_code, full_name, phone, created_by)
  values (p_user_id, upper(btrim(p_patient_code)), btrim(p_full_name),
    nullif(btrim(p_phone), ''), p_actor_user_id)
  returning * into created;

  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, request_id, metadata)
  values (p_actor_user_id, 'patient.created', 'patient', created.id, created.id,
    p_request_id, jsonb_build_object('account_user_id', p_user_id, 'via', 'crm'));
  return created;
end;
$$;

create or replace function public.integration_patient_credential_state(
  p_actor_user_id uuid, p_patient_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pat public.patients%rowtype;
  must_change boolean;
begin
  perform private.require_integration_actor(p_actor_user_id);
  select * into pat from public.patients where id = p_patient_id and status = 'active';
  if not found then
    raise exception 'Patient profile was not found.' using errcode = 'P0002';
  end if;
  if pat.user_id is null then
    return jsonb_build_object('status', 'no_login', 'patient_code', pat.patient_code);
  end if;
  select requires_credential_change into must_change
  from public.profiles where id = pat.user_id;
  if must_change is distinct from true then
    return jsonb_build_object('status', 'already_active', 'patient_code', pat.patient_code);
  end if;
  return jsonb_build_object('status', 'needs_credentials', 'user_id', pat.user_id,
    'patient_code', pat.patient_code);
end;
$$;

create or replace function public.integration_record_credential_issue(
  p_actor_user_id uuid, p_patient_id uuid, p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_integration_actor(p_actor_user_id);
  insert into public.admin_audit_logs
    (actor_user_id, action, entity_type, entity_id, patient_id, metadata)
  values (p_actor_user_id, 'integration.credential_issued', 'patient', p_patient_id,
    p_patient_id, jsonb_build_object('reason', left(coalesce(p_reason, 'issue'), 40)));
end;
$$;

revoke all on function private.require_integration_actor(uuid) from public, anon, authenticated;
revoke all on function public.integration_provision_patient(uuid, uuid, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.integration_patient_credential_state(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.integration_record_credential_issue(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function private.require_integration_actor(uuid) to service_role;
grant execute on function public.integration_provision_patient(uuid, uuid, text, text, text, uuid)
  to service_role;
grant execute on function public.integration_patient_credential_state(uuid, uuid)
  to service_role;
grant execute on function public.integration_record_credential_issue(uuid, uuid, text)
  to service_role;
-- ==== 20261120130000_profile_scoped_routines
-- Personal routines belong to a PROFILE (owner decision 2026-11-20). The 40 day
-- challenge stays ONE per login, shared by the whole family (owner decision,
-- revised the same day), so challenge tables are not touched here.
--
-- DESIGN (additive)
--   * `personal_routines.patient_id` (nullable, references patients). Actions,
--     resources and progress hang off their routine, so they follow it.
--   * A BEFORE INSERT trigger fills a missing patient_id with the owner's OWN
--     patient (`patients.user_id = owner`). Older app versions and admin
--     routines that send no profile keep working and land on the owner profile.
--     A member account without a patient keeps null.
--   * Existing rows are backfilled the same way.
--   * Write policies also require that a given patient_id is one the caller may
--     act for (`private.can_access_patient`). Read stays "own login".
--
-- COMPATIBILITY
--   No existing client call changes meaning: no key, constraint or required
--   column is added, so the currently deployed app keeps working unchanged.
--
-- ROLLBACK
--   Restore policies routine_insert_self / routine_update_self from
--   20261017092711, then drop the trigger, function, index and column.

alter table public.personal_routines
  add column if not exists patient_id uuid references public.patients (id) on delete cascade;

update public.personal_routines r set patient_id = p.id
from public.patients p
where r.patient_id is null and p.user_id = r.owner_user_id;

create index if not exists personal_routines_patient_idx
  on public.personal_routines (patient_id) where patient_id is not null;

create or replace function private.default_profile_patient()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.patient_id is null then
    select p.id into new.patient_id from public.patients p
    where p.user_id = new.owner_user_id;
  end if;
  return new;
end;
$$;
revoke all on function private.default_profile_patient() from public, anon, authenticated;

drop trigger if exists personal_routines_default_profile on public.personal_routines;
create trigger personal_routines_default_profile
before insert on public.personal_routines
for each row execute function private.default_profile_patient();

drop policy if exists routine_insert_self on public.personal_routines;
create policy routine_insert_self on public.personal_routines
for insert to authenticated
with check (
  owner_user_id = (select auth.uid())
  and (patient_id is null or (select private.can_access_patient(patient_id)))
);
drop policy if exists routine_update_self on public.personal_routines;
create policy routine_update_self on public.personal_routines
for update to authenticated
using (owner_user_id = (select auth.uid()))
with check (
  owner_user_id = (select auth.uid())
  and (patient_id is null or (select private.can_access_patient(patient_id)))
);

-- Post-checks (read only), reported as one row.
create temp table dry_report (k text, v text) on commit drop;
insert into dry_report select 'templates', count(*)::text from public.care_templates;
insert into dry_report select 'routines_total', count(*)::text from public.personal_routines;
insert into dry_report select 'routines_unassigned_but_owner_has_patient', count(*)::text
  from public.personal_routines r
  where r.patient_id is null and exists (select 1 from public.patients p where p.user_id = r.owner_user_id);
insert into dry_report select 'patients', count(*)::text from public.patients;
do $$
declare u record; n int; bad int := 0;
begin
  for u in select user_id from public.patients where user_id is not null and status = 'active' loop
    perform set_config('request.jwt.claim.sub', u.user_id::text, true);
    select count(*) into n from public.my_family_profiles();
    if n <> 1 then bad := bad + 1; end if;
  end loop;
  insert into dry_report values ('patient_users_without_exactly_one_profile', bad::text);
end $$;
-- The script ends with an error ON PURPOSE: the error aborts the transaction, so
-- nothing can ever be kept, and the editor shows the report inside the message.
do $$
declare report text;
begin
  select jsonb_pretty(jsonb_object_agg(k, v)) into report from dry_report;
  raise exception 'DRY RUN FINISHED, EVERYTHING ROLLED BACK. REPORT: %', report;
end $$;
