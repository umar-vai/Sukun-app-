-- Public, rights-approved RUQYAH audio copies for browser Web Audio FFT.
-- Independent from patient-only data. Public GET; no anon/authenticated writes.
-- Apply to STAGING first. Production promotion requires separate approval.
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'sukun-public-audio', 'sukun-public-audio', true,
  47185920, array['audio/mpeg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Never grant anonymous, member, or patient upload/delete/update rights.
-- The authenticated super-admin imports through a separately authenticated
-- Edge Function; its server-only service role writes the objects.
-- Storage reads are via the public object route, subject to CDN/CORS policy.

create table if not exists public.audio_rehost_imports (
  id uuid primary key default gen_random_uuid(),
  content_item_id uuid not null references public.content_items(id) on delete restrict,
  original_url text not null,
  object_path text not null unique,
  byte_size bigint not null check (byte_size between 1 and 47185920),
  content_sha256 text not null check (content_sha256 ~ '^[a-f0-9]{64}$'),
  imported_by uuid not null references auth.users(id) on delete restrict,
  rights_confirmed boolean not null default true check (rights_confirmed),
  created_at timestamptz not null default now(),
  constraint audio_rehost_imports_https_source
    check (original_url like 'https://files.ruqyahbd.org/audio/%.mp3')
);

create index if not exists audio_rehost_imports_content_idx
  on public.audio_rehost_imports (content_item_id, created_at desc);

alter table public.audio_rehost_imports enable row level security;
revoke all on public.audio_rehost_imports from public, anon, authenticated;
grant select on public.audio_rehost_imports to authenticated;

create policy audio_rehost_imports_read_admin
on public.audio_rehost_imports for select to authenticated
using ((select private.is_super_admin()));

comment on table public.audio_rehost_imports is
  'Admin-only proof of licensed public MP3 server-side imports. No patient data. Public copies live in sukun-public-audio bucket.';
