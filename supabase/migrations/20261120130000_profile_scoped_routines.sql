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
