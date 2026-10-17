-- Member-owned routines are explicitly separate from clinician-approved
-- patient care plans. Every action belongs to ONE auth user, never a patient.
-- No server reminder dispatch is enabled by this migration.
create table public.personal_routines (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_user_id)
);

create table public.personal_routine_actions (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null,
  owner_user_id uuid not null,
  title text not null check (char_length(btrim(title)) between 1 and 160),
  notification_title text not null
    check (char_length(btrim(notification_title)) between 1 and 160),
  notes text check (notes is null or char_length(notes) <= 2000),
  resource_provider text not null default 'manual'
    check (resource_provider in ('manual','cms','quran','hadith')),
  content_item_id uuid references public.content_items(id) on delete restrict,
  external_resource_ref text check (
    external_resource_ref is null or
    (char_length(external_resource_ref) between 1 and 120 and
     external_resource_ref ~ '^[A-Za-z0-9:_/-]+$')
  ),
  schedule_kind text not null default 'manual'
    check (schedule_kind in ('manual','fixed','fajr','maghrib')),
  local_time time without time zone,
  prayer_offset_minutes smallint not null default 10
    check (prayer_offset_minutes between 0 and 120),
  timezone_name text not null default 'Asia/Dhaka'
    check (char_length(timezone_name) between 2 and 80),
  prayer_city text check (prayer_city is null or char_length(prayer_city) <= 120),
  prayer_latitude double precision,
  prayer_longitude double precision,
  prayer_method text check (prayer_method is null or prayer_method in
    ('karachi','muslim_world_league','umm_al_qura','egyptian','singapore','north_america')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint personal_routine_action_owned foreign key (routine_id,owner_user_id)
    references public.personal_routines(id,owner_user_id) on delete cascade,
  constraint personal_routine_resource_shape check (
    (resource_provider='manual' and content_item_id is null and external_resource_ref is null)
    or (resource_provider='cms' and content_item_id is not null and external_resource_ref is null)
    or (resource_provider in ('quran','hadith') and
        content_item_id is null and external_resource_ref is not null)
  ),
  constraint personal_routine_schedule_shape check (
    (schedule_kind='manual' and local_time is null)
    or (schedule_kind='fixed' and local_time is not null)
    or (schedule_kind in ('fajr','maghrib') and local_time is null and
        prayer_latitude between -90 and 90 and
        prayer_longitude between -180 and 180 and prayer_method is not null
        and prayer_city is not null)
  )
);

create table public.personal_routine_progress (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null,
  owner_user_id uuid not null,
  local_date date not null,
  outcome text not null check (outcome in ('done','skipped')),
  occurred_at timestamptz not null default now(),
  constraint personal_progress_owned foreign key (action_id,owner_user_id)
    references public.personal_routine_actions(id,owner_user_id) on delete cascade,
  unique (action_id,local_date)
);
-- Make action/owner pair referenceable for progress, without client-supplied
-- ownership becoming authoritative.
alter table public.personal_routine_actions
  add constraint personal_routine_actions_owner_key unique (id,owner_user_id);

create index personal_routines_owner_idx
  on public.personal_routines(owner_user_id, created_at desc);
create index personal_routine_actions_owner_idx
  on public.personal_routine_actions(owner_user_id,routine_id);
create index personal_routine_progress_owner_idx
  on public.personal_routine_progress(owner_user_id,local_date desc);

alter table public.personal_routines enable row level security;
alter table public.personal_routine_actions enable row level security;
alter table public.personal_routine_progress enable row level security;

create policy routine_select_self on public.personal_routines
for select to authenticated using (owner_user_id = (select auth.uid()));
create policy routine_insert_self on public.personal_routines
for insert to authenticated with check (owner_user_id = (select auth.uid()));
create policy routine_update_self on public.personal_routines
for update to authenticated using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));
create policy routine_delete_self on public.personal_routines
for delete to authenticated using (owner_user_id = (select auth.uid()));

-- Existence checks are evaluated under the caller's current authorization.
-- Only public/published CMS resources may be attached to a personal action.
create policy personal_action_select_self on public.personal_routine_actions
for select to authenticated using (owner_user_id = (select auth.uid()));
create policy personal_action_insert_self on public.personal_routine_actions
for insert to authenticated
with check (
  owner_user_id = (select auth.uid()) and
  (resource_provider != 'cms' or exists (
    select 1 from public.content_items c
    where c.id = content_item_id
      and c.status = 'published'
      and c.visibility = 'public'
  ))
);
create policy personal_action_update_self on public.personal_routine_actions
for update to authenticated
using (owner_user_id = (select auth.uid()))
with check (
  owner_user_id = (select auth.uid()) and
  (resource_provider != 'cms' or exists (
    select 1 from public.content_items c
    where c.id = content_item_id
      and c.status = 'published'
      and c.visibility = 'public'
  ))
);
create policy personal_action_delete_self on public.personal_routine_actions
for delete to authenticated using (owner_user_id = (select auth.uid()));

create policy personal_progress_select_self on public.personal_routine_progress
for select to authenticated using (owner_user_id = (select auth.uid()));
create policy personal_progress_insert_self on public.personal_routine_progress
for insert to authenticated with check (owner_user_id = (select auth.uid()));
create policy personal_progress_update_self on public.personal_routine_progress
for update to authenticated using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));
create policy personal_progress_delete_self on public.personal_routine_progress
for delete to authenticated using (owner_user_id = (select auth.uid()));

revoke all on public.personal_routines from anon;
revoke all on public.personal_routine_actions from anon;
revoke all on public.personal_routine_progress from anon;
grant select,insert,update,delete on public.personal_routines to authenticated;
grant select,insert,update,delete on public.personal_routine_actions to authenticated;
grant select,insert,update,delete on public.personal_routine_progress to authenticated;

comment on table public.personal_routines is
  'Private self-service routines; never modify or replace approved patient care plans.';
comment on table public.personal_routine_actions is
  'Stored personal schedule preferences, NOT proof of push delivery. Fajr/Maghrib must be recalculated per local date.';
