-- Personal routines and the 40 day challenge belong to a PROFILE (owner
-- decision 2026-11-20), not to the whole family login.
--
-- DESIGN (additive)
--   * `personal_routines.patient_id`, `challenge_enrollments.patient_id` and
--     `challenge_day_checkins.patient_id` (nullable, references patients).
--     Actions, resources and progress rows hang off their routine, so they
--     follow it and need no new column.
--   * A BEFORE INSERT trigger fills a missing patient_id with the owner's OWN
--     patient (`patients.user_id = owner`). Older app versions and admin
--     routines that do not send a profile therefore keep working and land on
--     the owner profile. A member account without a patient keeps null.
--   * Existing rows are backfilled the same way.
--   * Challenge primary keys gain a generated `profile_key`
--     (= patient_id, or a zero uuid when null) so one login can run the
--     challenge once per profile. Client upserts use
--     on_conflict = user_id,challenge_key,profile_key.
--   * Write policies additionally require that a given patient_id is one the
--     caller may act for (`private.can_access_patient`). Read policies stay
--     "own login" so a family sees its own rows; clients filter by profile.
--
-- ROLLBACK
--   Restore the previous primary keys/foreign key and the six policies from
--   migrations 20261017092711 and 20261022194319, then drop the new columns
--   and trigger functions. No row other than the new columns is changed.

alter table public.personal_routines
  add column if not exists patient_id uuid references public.patients (id) on delete cascade;
alter table public.challenge_enrollments
  add column if not exists patient_id uuid references public.patients (id) on delete cascade;
alter table public.challenge_day_checkins
  add column if not exists patient_id uuid references public.patients (id) on delete cascade;

-- Backfill: the owner's own patient, if there is one.
update public.personal_routines r set patient_id = p.id
from public.patients p
where r.patient_id is null and p.user_id = r.owner_user_id;
update public.challenge_enrollments e set patient_id = p.id
from public.patients p
where e.patient_id is null and p.user_id = e.user_id;
update public.challenge_day_checkins c set patient_id = p.id
from public.patients p
where c.patient_id is null and p.user_id = c.user_id;

create index if not exists personal_routines_patient_idx
  on public.personal_routines (patient_id) where patient_id is not null;

create or replace function private.default_profile_patient()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  if new.patient_id is null then
    -- Routines carry owner_user_id, challenge rows carry user_id.
    owner_id := coalesce(
      to_jsonb(new) ->> 'owner_user_id', to_jsonb(new) ->> 'user_id')::uuid;
    select p.id into new.patient_id from public.patients p
    where p.user_id = owner_id;
  end if;
  return new;
end;
$$;
revoke all on function private.default_profile_patient() from public, anon, authenticated;

drop trigger if exists personal_routines_default_profile on public.personal_routines;
create trigger personal_routines_default_profile
before insert on public.personal_routines
for each row execute function private.default_profile_patient();
drop trigger if exists challenge_enrollments_default_profile on public.challenge_enrollments;
create trigger challenge_enrollments_default_profile
before insert on public.challenge_enrollments
for each row execute function private.default_profile_patient();
drop trigger if exists challenge_day_checkins_default_profile on public.challenge_day_checkins;
create trigger challenge_day_checkins_default_profile
before insert on public.challenge_day_checkins
for each row execute function private.default_profile_patient();

-- Challenge keys: one enrollment and one set of check-ins per profile.
alter table public.challenge_enrollments
  add column if not exists profile_key uuid generated always as
    (coalesce(patient_id, '00000000-0000-0000-0000-000000000000'::uuid)) stored;
alter table public.challenge_day_checkins
  add column if not exists profile_key uuid generated always as
    (coalesce(patient_id, '00000000-0000-0000-0000-000000000000'::uuid)) stored;

alter table public.challenge_day_checkins drop constraint challenge_checkins_enrollment_fk;
alter table public.challenge_day_checkins drop constraint challenge_day_checkins_pk;
alter table public.challenge_enrollments drop constraint challenge_enrollments_pk;

alter table public.challenge_enrollments
  add constraint challenge_enrollments_pk primary key (user_id, challenge_key, profile_key);
alter table public.challenge_day_checkins
  add constraint challenge_day_checkins_pk
    primary key (user_id, challenge_key, profile_key, day_number);
alter table public.challenge_day_checkins
  add constraint challenge_checkins_enrollment_fk
    foreign key (user_id, challenge_key, profile_key)
    references public.challenge_enrollments (user_id, challenge_key, profile_key)
    on delete cascade;

-- Write policies: own login AND a profile the caller may act for.
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

drop policy if exists "Only own account can enroll" on public.challenge_enrollments;
create policy "Only own account can enroll" on public.challenge_enrollments
for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and (patient_id is null or (select private.can_access_patient(patient_id)))
);
drop policy if exists "Only own account can pause or resume" on public.challenge_enrollments;
create policy "Only own account can pause or resume" on public.challenge_enrollments
for update to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and (patient_id is null or (select private.can_access_patient(patient_id)))
);

drop policy if exists "Only enrolled owner can complete day" on public.challenge_day_checkins;
create policy "Only enrolled owner can complete day" on public.challenge_day_checkins
for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and (patient_id is null or (select private.can_access_patient(patient_id)))
);
