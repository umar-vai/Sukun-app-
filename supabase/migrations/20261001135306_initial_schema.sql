-- Sukun Life foundational schema.
-- Clinical and religious-source history is archived/versioned rather than overwritten.

create schema if not exists private;

create type public.app_role as enum ('patient', 'super_admin');
create type public.patient_status as enum ('active', 'inactive', 'archived');
create type public.record_visibility as enum ('patient', 'staff_only');
create type public.prescription_source_type as enum (
  'manual',
  'imported',
  'future_external_sync'
);
create type public.care_plan_status as enum (
  'draft',
  'active',
  'inactive',
  'archived'
);
create type public.action_review_status as enum (
  'draft',
  'needs_review',
  'approved',
  'rejected'
);
create type public.task_status as enum (
  'pending',
  'completed',
  'snoozed',
  'skipped',
  'missed',
  'cancelled'
);
create type public.content_type as enum (
  'dua',
  'amal',
  'quran',
  'hadith',
  'article',
  'guide',
  'audio',
  'video',
  'pdf',
  'book',
  'book_chapter',
  'external_link'
);
create type public.resource_visibility as enum (
  'public',
  'patient_only',
  'assigned_only',
  'staff_only'
);
create type public.content_status as enum (
  'draft',
  'review',
  'verified',
  'published',
  'archived'
);
create type public.verification_status as enum (
  'not_required',
  'pending',
  'verified',
  'rejected'
);
create type public.media_source_type as enum (
  'direct_audio_url',
  'direct_video_url',
  'youtube',
  'external_pdf',
  'external_web'
);
create type public.device_platform as enum ('android', 'ios');
create type public.notification_status as enum (
  'scheduled',
  'sent',
  'opened',
  'cancelled',
  'failed'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  locale text not null default 'en',
  requires_credential_change boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (
    display_name is null or char_length(display_name) between 1 and 160
  ),
  constraint profiles_locale_length check (char_length(locale) between 2 and 16)
);

create table public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users (id) on delete set null,
  patient_code text not null,
  full_name text not null,
  phone text,
  status public.patient_status not null default 'active',
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint patients_code_not_blank check (btrim(patient_code) <> ''),
  constraint patients_name_not_blank check (btrim(full_name) <> ''),
  constraint patients_archive_consistency check (
    (status = 'archived' and archived_at is not null)
    or (status <> 'archived' and archived_at is null)
  )
);

create unique index patients_patient_code_lower_key
  on public.patients (lower(patient_code));

create table public.patient_external_refs (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  source_system text not null,
  external_id text not null,
  created_at timestamptz not null default now(),
  constraint patient_external_refs_source_not_blank check (
    btrim(source_system) <> ''
  ),
  constraint patient_external_refs_id_not_blank check (btrim(external_id) <> ''),
  unique (source_system, external_id)
);

create table public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete restrict,
  source_type public.prescription_source_type not null default 'manual',
  source_external_id text,
  raw_text text not null,
  session_date date,
  visibility public.record_visibility not null default 'patient',
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint prescriptions_raw_text_not_blank check (btrim(raw_text) <> '')
);

create table public.prescription_versions (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions (id) on delete restrict,
  version integer not null,
  raw_text text not null,
  visibility public.record_visibility not null,
  change_note text,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint prescription_versions_positive check (version > 0),
  constraint prescription_versions_text_not_blank check (btrim(raw_text) <> ''),
  unique (prescription_id, version)
);

create table public.care_plans (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete restrict,
  prescription_id uuid references public.prescriptions (id) on delete restrict,
  version integer not null,
  name text not null,
  start_date date not null,
  end_date date,
  status public.care_plan_status not null default 'draft',
  published_at timestamptz,
  published_by uuid references auth.users (id) on delete restrict,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint care_plans_positive_version check (version > 0),
  constraint care_plans_name_not_blank check (btrim(name) <> ''),
  constraint care_plans_date_order check (
    end_date is null or end_date >= start_date
  ),
  constraint care_plans_publish_consistency check (
    (status = 'draft' and published_at is null and published_by is null)
    or (status <> 'draft' and published_at is not null and published_by is not null)
  ),
  constraint care_plans_archive_consistency check (
    (status = 'archived' and archived_at is not null)
    or (status <> 'archived' and archived_at is null)
  ),
  unique (patient_id, version)
);

create unique index care_plans_one_active_per_patient_idx
  on public.care_plans (patient_id)
  where status = 'active';

create table public.plan_actions (
  id uuid primary key default gen_random_uuid(),
  care_plan_id uuid not null references public.care_plans (id) on delete restrict,
  type text not null,
  title text not null,
  instruction text,
  count_target integer,
  duration_minutes integer,
  frequency_rule jsonb not null,
  time_window text,
  exact_time time,
  start_date date not null,
  end_date date,
  sort_order integer not null default 0,
  review_status public.action_review_status not null default 'draft',
  reminder_enabled boolean not null default false,
  ai_source jsonb,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plan_actions_type_not_blank check (btrim(type) <> ''),
  constraint plan_actions_title_not_blank check (btrim(title) <> ''),
  constraint plan_actions_count_positive check (
    count_target is null or count_target > 0
  ),
  constraint plan_actions_duration_positive check (
    duration_minutes is null or duration_minutes > 0
  ),
  constraint plan_actions_frequency_object check (
    jsonb_typeof(frequency_rule) = 'object'
  ),
  constraint plan_actions_time_window check (
    time_window is null
    or time_window in ('morning', 'afternoon', 'evening', 'night', 'anytime')
  ),
  constraint plan_actions_date_order check (
    end_date is null or end_date >= start_date
  ),
  constraint plan_actions_sort_order_nonnegative check (sort_order >= 0)
);

create table public.task_instances (
  id uuid primary key default gen_random_uuid(),
  plan_action_id uuid not null references public.plan_actions (id) on delete restrict,
  patient_id uuid not null references public.patients (id) on delete restrict,
  scheduled_at timestamptz not null,
  status public.task_status not null default 'pending',
  completed_at timestamptz,
  snoozed_until timestamptz,
  skip_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint task_instances_state_consistency check (
    (status = 'completed' and completed_at is not null)
    or (status <> 'completed' and completed_at is null)
  ),
  constraint task_instances_snooze_consistency check (
    (status = 'snoozed' and snoozed_until is not null)
    or (status <> 'snoozed' and snoozed_until is null)
  ),
  constraint task_instances_skip_consistency check (
    status = 'skipped' or skip_reason is null
  ),
  unique (plan_action_id, scheduled_at)
);

create table public.task_completions (
  id uuid primary key default gen_random_uuid(),
  task_instance_id uuid not null references public.task_instances (id) on delete restrict,
  patient_id uuid not null references public.patients (id) on delete restrict,
  status public.task_status not null,
  occurred_at timestamptz not null default now(),
  snoozed_until timestamptz,
  skip_reason text,
  client_event_id uuid not null unique,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint task_completions_patient_states check (
    status in ('completed', 'snoozed', 'skipped')
  ),
  constraint task_completions_snooze_consistency check (
    (status = 'snoozed' and snoozed_until is not null)
    or (status <> 'snoozed' and snoozed_until is null)
  ),
  constraint task_completions_skip_consistency check (
    status = 'skipped' or skip_reason is null
  )
);

create table public.content_categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.content_categories (id) on delete restrict,
  name text not null,
  name_bn text,
  slug text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint content_categories_name_not_blank check (btrim(name) <> ''),
  constraint content_categories_slug_format check (
    slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  constraint content_categories_sort_order_nonnegative check (sort_order >= 0),
  constraint content_categories_not_self_parent check (parent_id is distinct from id)
);

create table public.content_items (
  id uuid primary key default gen_random_uuid(),
  type public.content_type not null,
  category_id uuid references public.content_categories (id) on delete restrict,
  title text not null,
  title_bn text,
  slug text not null unique,
  summary text,
  body text,
  arabic_text text,
  bangla_text text,
  transliteration text,
  translation text,
  reference_text text,
  source_type text,
  source_reference text,
  source_url text,
  translation_source text,
  verification_status public.verification_status not null default 'not_required',
  verified_by uuid references auth.users (id) on delete restrict,
  verified_at timestamptz,
  surah_number smallint,
  ayah_number integer,
  collection_name text,
  book_name text,
  hadith_number text,
  narrator text,
  grade text,
  author text,
  publisher text,
  rights_note text,
  thumbnail_url text,
  media_source_type public.media_source_type,
  media_url text,
  youtube_video_id text,
  visibility public.resource_visibility not null default 'staff_only',
  status public.content_status not null default 'draft',
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  archived_at timestamptz,
  constraint content_items_title_not_blank check (btrim(title) <> ''),
  constraint content_items_slug_format check (
    slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  constraint content_items_source_url_https check (
    source_url is null or source_url ~ '^https://'
  ),
  constraint content_items_media_url_https check (
    media_url is null or media_url ~ '^https://'
  ),
  constraint content_items_thumbnail_url_https check (
    thumbnail_url is null or thumbnail_url ~ '^https://'
  ),
  constraint content_items_media_consistency check (
    (media_source_type is null and media_url is null and youtube_video_id is null)
    or (
      media_source_type is not null
      and (
        (media_source_type = 'youtube' and youtube_video_id is not null)
        or (media_source_type <> 'youtube' and media_url is not null)
      )
    )
  ),
  constraint content_items_verification_consistency check (
    (verification_status = 'verified' and verified_by is not null and verified_at is not null)
    or (verification_status <> 'verified' and verified_by is null and verified_at is null)
  ),
  constraint content_items_canonical_publication check (
    status <> 'published'
    or type not in ('quran', 'hadith')
    or (
      verification_status = 'verified'
      and nullif(btrim(source_reference), '') is not null
      and coalesce(source_type, '') <> 'generative_ai'
    )
  ),
  constraint content_items_quran_reference check (
    type <> 'quran'
    or (
      surah_number between 1 and 114
      and ayah_number is not null
      and ayah_number > 0
    )
  ),
  constraint content_items_publish_consistency check (
    (status = 'published' and published_at is not null)
    or (status <> 'published' and published_at is null)
  ),
  constraint content_items_archive_consistency check (
    (status = 'archived' and archived_at is not null)
    or (status <> 'archived' and archived_at is null)
  )
);

create table public.content_tags (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint content_tags_name_not_blank check (btrim(name) <> ''),
  constraint content_tags_slug_format check (
    slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  )
);

create table public.content_item_tags (
  content_item_id uuid not null references public.content_items (id) on delete cascade,
  content_tag_id uuid not null references public.content_tags (id) on delete cascade,
  primary key (content_item_id, content_tag_id)
);

create table public.plan_action_resources (
  plan_action_id uuid not null references public.plan_actions (id) on delete restrict,
  content_item_id uuid not null references public.content_items (id) on delete restrict,
  usage_note text,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (plan_action_id, content_item_id)
);

create table public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  patient_id uuid references public.patients (id) on delete cascade,
  platform public.device_platform not null,
  push_token text not null unique,
  timezone text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_devices_token_not_blank check (btrim(push_token) <> ''),
  constraint notification_devices_timezone_not_blank check (btrim(timezone) <> '')
);

create table public.notification_events (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.patients (id) on delete restrict,
  device_id uuid references public.notification_devices (id) on delete set null,
  plan_action_id uuid references public.plan_actions (id) on delete set null,
  task_instance_id uuid references public.task_instances (id) on delete set null,
  scheduled_at timestamptz not null,
  notification_type text not null,
  status public.notification_status not null default 'scheduled',
  opened_at timestamptz,
  snoozed_until timestamptz,
  provider_message_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_events_type_not_blank check (
    btrim(notification_type) <> ''
  ),
  constraint notification_events_open_consistency check (
    opened_at is null or status = 'opened'
  )
);

create table public.admin_audit_logs (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  patient_id uuid references public.patients (id) on delete restrict,
  request_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint admin_audit_logs_action_not_blank check (btrim(action) <> ''),
  constraint admin_audit_logs_entity_not_blank check (btrim(entity_type) <> ''),
  constraint admin_audit_logs_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create table public.app_settings (
  key text primary key,
  value jsonb not null,
  is_public boolean not null default false,
  updated_by uuid not null references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  constraint app_settings_key_format check (key ~ '^[a-z0-9]+(?:[._-][a-z0-9]+)*$')
);

-- Foreign keys and common RLS/filter paths are indexed explicitly.
create index user_roles_granted_by_idx on public.user_roles (granted_by);
create index patients_created_by_idx on public.patients (created_by);
create index patients_active_name_idx on public.patients (lower(full_name))
  where status = 'active';
create index patient_external_refs_patient_id_idx
  on public.patient_external_refs (patient_id);
create index prescriptions_patient_created_idx
  on public.prescriptions (patient_id, created_at desc);
create index prescriptions_created_by_idx on public.prescriptions (created_by);
create index prescription_versions_created_by_idx
  on public.prescription_versions (created_by);
create index care_plans_prescription_id_idx on public.care_plans (prescription_id);
create index care_plans_created_by_idx on public.care_plans (created_by);
create index care_plans_published_by_idx on public.care_plans (published_by);
create index plan_actions_plan_sort_idx
  on public.plan_actions (care_plan_id, sort_order);
create index plan_actions_created_by_idx on public.plan_actions (created_by);
create index task_instances_patient_schedule_idx
  on public.task_instances (patient_id, scheduled_at);
create index task_instances_pending_schedule_idx
  on public.task_instances (scheduled_at)
  where status in ('pending', 'snoozed');
create index task_instances_action_idx on public.task_instances (plan_action_id);
create index task_completions_task_occurred_idx
  on public.task_completions (task_instance_id, occurred_at desc);
create index task_completions_patient_occurred_idx
  on public.task_completions (patient_id, occurred_at desc);
create index task_completions_created_by_idx on public.task_completions (created_by);
create index content_categories_parent_id_idx on public.content_categories (parent_id);
create index content_categories_created_by_idx on public.content_categories (created_by);
create index content_categories_updated_by_idx on public.content_categories (updated_by);
create index content_items_category_id_idx on public.content_items (category_id);
create index content_items_created_by_idx on public.content_items (created_by);
create index content_items_updated_by_idx on public.content_items (updated_by);
create index content_items_verified_by_idx on public.content_items (verified_by);
create index content_items_browse_idx
  on public.content_items (visibility, type, published_at desc)
  where status = 'published';
create index content_tags_created_by_idx on public.content_tags (created_by);
create index content_item_tags_tag_id_idx on public.content_item_tags (content_tag_id);
create index plan_action_resources_content_item_idx
  on public.plan_action_resources (content_item_id);
create index plan_action_resources_created_by_idx
  on public.plan_action_resources (created_by);
create index notification_devices_user_id_idx on public.notification_devices (user_id);
create index notification_devices_patient_id_idx on public.notification_devices (patient_id);
create index notification_events_patient_schedule_idx
  on public.notification_events (patient_id, scheduled_at desc);
create index notification_events_device_id_idx on public.notification_events (device_id);
create index notification_events_plan_action_id_idx
  on public.notification_events (plan_action_id);
create index notification_events_task_instance_id_idx
  on public.notification_events (task_instance_id);
create index admin_audit_logs_actor_created_idx
  on public.admin_audit_logs (actor_user_id, created_at desc);
create index admin_audit_logs_patient_created_idx
  on public.admin_audit_logs (patient_id, created_at desc);
create index admin_audit_logs_request_id_idx
  on public.admin_audit_logs (request_id)
  where request_id is not null;
create index app_settings_updated_by_idx on public.app_settings (updated_by);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function private.validate_task_patient()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  expected_patient_id uuid;
begin
  select cp.patient_id
    into expected_patient_id
  from public.plan_actions pa
  join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = new.plan_action_id;

  if expected_patient_id is null or expected_patient_id <> new.patient_id then
    raise exception 'Task patient must match the action care plan patient.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function private.validate_completion_patient()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  expected_patient_id uuid;
begin
  select ti.patient_id
    into expected_patient_id
  from public.task_instances ti
  where ti.id = new.task_instance_id;

  if expected_patient_id is null or expected_patient_id <> new.patient_id then
    raise exception 'Completion patient must match the task patient.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function private.prevent_published_plan_rewrite()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.status <> 'draft' and (
    new.patient_id is distinct from old.patient_id
    or new.prescription_id is distinct from old.prescription_id
    or new.version is distinct from old.version
    or new.name is distinct from old.name
    or new.start_date is distinct from old.start_date
    or new.end_date is distinct from old.end_date
    or new.published_at is distinct from old.published_at
    or new.published_by is distinct from old.published_by
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  ) then
    raise exception 'Published care plan history cannot be rewritten.'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

create or replace function private.prevent_task_identity_rewrite()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.plan_action_id is distinct from old.plan_action_id
    or new.patient_id is distinct from old.patient_id
    or new.scheduled_at is distinct from old.scheduled_at then
    raise exception 'A generated task identity cannot be rewritten.'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();
create trigger patients_set_updated_at
before update on public.patients
for each row execute function private.set_updated_at();
create trigger care_plans_set_updated_at
before update on public.care_plans
for each row execute function private.set_updated_at();
create trigger care_plans_prevent_published_rewrite
before update on public.care_plans
for each row execute function private.prevent_published_plan_rewrite();
create trigger plan_actions_set_updated_at
before update on public.plan_actions
for each row execute function private.set_updated_at();
create trigger task_instances_set_updated_at
before update on public.task_instances
for each row execute function private.set_updated_at();
create trigger content_categories_set_updated_at
before update on public.content_categories
for each row execute function private.set_updated_at();
create trigger content_items_set_updated_at
before update on public.content_items
for each row execute function private.set_updated_at();
create trigger notification_devices_set_updated_at
before update on public.notification_devices
for each row execute function private.set_updated_at();
create trigger notification_events_set_updated_at
before update on public.notification_events
for each row execute function private.set_updated_at();
create trigger app_settings_set_updated_at
before update on public.app_settings
for each row execute function private.set_updated_at();

create trigger task_instances_validate_patient
before insert or update of plan_action_id, patient_id on public.task_instances
for each row execute function private.validate_task_patient();
create trigger task_instances_prevent_identity_rewrite
before update on public.task_instances
for each row execute function private.prevent_task_identity_rewrite();
create trigger task_completions_validate_patient
before insert or update of task_instance_id, patient_id on public.task_completions
for each row execute function private.validate_completion_patient();

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_auth_user();

insert into public.profiles (id, display_name)
select
  u.id,
  nullif(btrim(u.raw_user_meta_data ->> 'full_name'), '')
from auth.users u
on conflict (id) do nothing;

comment on table public.prescriptions is
  'Immutable human-authored prescription sources; corrections are recorded in prescription_versions.';
comment on table public.care_plans is
  'Versioned patient plans. At most one plan is active per patient.';
comment on table public.content_items is
  'Canonical reusable resources. Qur''an and Hadith publication requires verified source metadata.';
comment on table public.task_completions is
  'Append-only patient task interaction events written through record_task_completion.';
