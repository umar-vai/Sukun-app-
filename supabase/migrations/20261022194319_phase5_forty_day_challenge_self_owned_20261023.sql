-- Phase 5: opt-in, FREE public Sukun forty-day self-guided challenge.
-- Contains no clinical observations, prescriptions, payment or patient data.
-- Enrollment and check-ins are always bound to the verified auth.uid() via RLS.
create table if not exists public.challenge_enrollments (
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_key text not null default 'sukun_40_day',
  started_on date not null default current_date,
  paused_on date,
  paused_days integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenge_enrollments_pk primary key (user_id, challenge_key),
  constraint challenge_approved_key check (challenge_key = 'sukun_40_day'),
  constraint challenge_pause_days_valid check (paused_days between 0 and 3650),
  constraint challenge_start_date_valid check (
    started_on between date '2020-01-01' and (current_date + 1)
  ),
  constraint challenge_pause_date_valid check (paused_on is null or paused_on >= started_on)
);

create table if not exists public.challenge_day_checkins (
  user_id uuid not null,
  challenge_key text not null default 'sukun_40_day',
  day_number smallint not null,
  completed_at timestamptz not null default now(),
  constraint challenge_day_checkins_pk primary key
    (user_id, challenge_key, day_number),
  constraint challenge_day_range check (day_number between 1 and 40),
  constraint challenge_checkins_enrollment_fk foreign key (user_id, challenge_key)
    references public.challenge_enrollments(user_id, challenge_key)
    on delete cascade
);

create index if not exists idx_challenge_checkins_owner_time
  on public.challenge_day_checkins (user_id, completed_at desc);

alter table public.challenge_enrollments enable row level security;
alter table public.challenge_day_checkins enable row level security;

revoke all on public.challenge_enrollments from public, anon, authenticated;
revoke all on public.challenge_day_checkins from public, anon, authenticated;
grant select, insert, update on public.challenge_enrollments to authenticated;
grant select, insert, delete on public.challenge_day_checkins to authenticated;

create policy "Challenge enrollment is visible only to its owner"
on public.challenge_enrollments for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Only own account can enroll"
on public.challenge_enrollments for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Only own account can pause or resume"
on public.challenge_enrollments for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Checkins belong to signed-in account"
on public.challenge_day_checkins for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Only enrolled owner can complete day"
on public.challenge_day_checkins for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Only owner can undo own day"
on public.challenge_day_checkins for delete to authenticated
using ((select auth.uid()) = user_id);

comment on table public.challenge_enrollments is
  'Phase 5 voluntary free challenge; non-clinical owner-only progress.';
comment on table public.challenge_day_checkins is
  'Append-only day completion except owner-initiated undo. No patient plan details.';
