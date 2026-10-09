-- Staff/patient mapping only. This table DOES NOT grant access to
-- clinical records, prescriptions, patient identifiers beyond the UUID,
-- or counselling information. Broader access requires a separate,
-- explicitly reviewed RLS migration with negative tests.
create table public.care_team_assignments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete restrict,
  staff_user_id uuid not null references auth.users (id) on delete cascade,
  assignment_role public.app_role not null,
  active boolean not null default true,
  assigned_by uuid not null references auth.users (id) on delete restrict,
  assigned_at timestamptz not null default now(),
  ended_at timestamptz,
  unique (patient_id, staff_user_id, assignment_role),
  constraint care_team_role_only check (
    assignment_role in ('raqi'::public.app_role, 'support_staff'::public.app_role)
  ),
  constraint care_team_end_consistency check (
    (active = true and ended_at is null)
    or (active = false and ended_at is not null)
  )
);

create index care_team_staff_active_lookup
  on public.care_team_assignments (staff_user_id, active);

revoke all on public.care_team_assignments from public, anon, authenticated;
grant select, insert, update, delete on public.care_team_assignments
  to authenticated;

alter table public.care_team_assignments enable row level security;

-- Super Admin can see all, but staff can only see their own active links,
-- and only if they actually hold the matching role in user_roles.
create policy care_team_select_admin_or_own_active
on public.care_team_assignments
for select to authenticated
using (
  (select private.is_super_admin())
  or (
    staff_user_id = (select auth.uid())
    and active = true
    and exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
        and ur.role = public.care_team_assignments.assignment_role
    )
  )
);

create policy care_team_insert_admin
on public.care_team_assignments
for insert to authenticated
with check (
  (select private.is_super_admin())
  and assigned_by = (select auth.uid())
);

create policy care_team_update_admin
on public.care_team_assignments
for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

create policy care_team_delete_admin
on public.care_team_assignments
for delete to authenticated
using ((select private.is_super_admin()));

comment on table public.care_team_assignments is
  'Assignments are metadata only. No direct patient/clinical RLS privileges for raqi or support_staff in this phase.';
