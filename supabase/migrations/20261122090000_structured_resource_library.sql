-- Structured Islamic resource library (owner request, 2026-11-22).
--
-- Adds, in one idempotent step:
--   * Ruqyah audio grouped into seven library categories (by topic, by
--     reciter, other audio, selected ayat/surah/dua, special ruqyah,
--     alternate/short versions, more reciters). Audio that is already in the
--     CMS with the same media URL is moved into its library category instead
--     of being duplicated, so care plans that reference it keep working.
--   * 90 daily dua and dhikr in 18 groups, with Arabic, pronunciation,
--     meaning, hadith reference and per-dua audio where available.
--   * Ruqyah PDFs in a dedicated PDF category.
--   * A Self-diagnosis area: seven self-assessment tests (questions, option
--     scores and result bands, all editable by a Super Admin) and the amulet
--     disposal guide.
--
-- Media is link-based only: every audio/PDF row stores an external HTTPS URL;
-- no file is copied into Supabase Storage. Rows are published and public in
-- one step, as with the existing one-step publishing workflow. The owner
-- confirmed permission for this content on 2026-11-22.
--
-- content_items.sort_order gives a stable in-category order that a Super Admin
-- can change from the content editor (set_content_item_sort_order).
--
-- On a database without a Super Admin (disposable CI stack) the schema is
-- created and the content install is skipped; tests call
-- private.install_resource_library directly.

-- 1. Stable in-category order for content items -------------------------------
alter table public.content_items
  add column if not exists sort_order integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'content_items_sort_order_nonnegative'
  ) then
    alter table public.content_items
      add constraint content_items_sort_order_nonnegative
      check (sort_order >= 0);
  end if;
end;
$$;

create index if not exists content_items_category_order_idx
  on public.content_items (category_id, sort_order, id);

create or replace function public.set_content_item_sort_order(
  p_content_item_id uuid,
  p_sort_order integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (select private.is_super_admin()) then
    raise exception 'Only a Super Admin can reorder resources.'
      using errcode = '42501';
  end if;
  if p_sort_order is null or p_sort_order < 0 or p_sort_order > 100000 then
    raise exception 'Order must be between 0 and 100000.'
      using errcode = '22023';
  end if;
  update public.content_items
  set sort_order = p_sort_order,
      updated_by = (select auth.uid())
  where id = p_content_item_id;
  if not found then
    raise exception 'Resource not found.' using errcode = 'P0002';
  end if;
  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, metadata
  ) values (
    (select auth.uid()), 'content_item_sort_order_set', 'content_item',
    p_content_item_id, jsonb_build_object('sort_order', p_sort_order)
  );
end;
$$;

revoke execute on function public.set_content_item_sort_order(uuid, integer)
  from public, anon;
grant execute on function public.set_content_item_sort_order(uuid, integer)
  to authenticated;

-- 2. Self-assessment tests -------------------------------------------------------
create table if not exists public.self_assessment_tests (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title_bn text not null,
  description_bn text,
  note_bn text,
  scoring_mode text not null default 'total',
  dimensions jsonb not null default '[]'::jsonb,
  rules jsonb not null default '[]'::jsonb,
  outcomes jsonb not null default '[]'::jsonb,
  fallback_bn text,
  sort_order integer not null default 0,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  constraint self_assessment_tests_slug_format
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint self_assessment_tests_title_not_blank
    check (btrim(title_bn) <> ''),
  constraint self_assessment_tests_scoring_mode
    check (scoring_mode in ('total', 'dimensions')),
  constraint self_assessment_tests_json_arrays
    check (
      jsonb_typeof(dimensions) = 'array'
      and jsonb_typeof(rules) = 'array'
      and jsonb_typeof(outcomes) = 'array'
    ),
  constraint self_assessment_tests_sort_nonnegative check (sort_order >= 0)
);

create table if not exists public.self_assessment_questions (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null
    references public.self_assessment_tests (id) on delete cascade,
  sort_order integer not null default 0,
  question_bn text not null,
  options jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint self_assessment_questions_text_not_blank
    check (btrim(question_bn) <> ''),
  constraint self_assessment_questions_options_shape
    check (
      jsonb_typeof(options) = 'array'
      and jsonb_array_length(options) between 2 and 6
    ),
  constraint self_assessment_questions_sort_nonnegative
    check (sort_order >= 0)
);

create index if not exists self_assessment_questions_test_order_idx
  on public.self_assessment_questions (test_id, sort_order, id);

create table if not exists public.self_assessment_result_bands (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null
    references public.self_assessment_tests (id) on delete cascade,
  min_score integer not null,
  message_bn text not null,
  needs_ruqyah boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint self_assessment_result_bands_min_nonnegative
    check (min_score >= 0),
  constraint self_assessment_result_bands_message_not_blank
    check (btrim(message_bn) <> ''),
  constraint self_assessment_result_bands_unique_min
    unique (test_id, min_score)
);

drop trigger if exists self_assessment_tests_set_updated_at
  on public.self_assessment_tests;
create trigger self_assessment_tests_set_updated_at
before update on public.self_assessment_tests
for each row execute function private.set_updated_at();

drop trigger if exists self_assessment_questions_set_updated_at
  on public.self_assessment_questions;
create trigger self_assessment_questions_set_updated_at
before update on public.self_assessment_questions
for each row execute function private.set_updated_at();

drop trigger if exists self_assessment_result_bands_set_updated_at
  on public.self_assessment_result_bands;
create trigger self_assessment_result_bands_set_updated_at
before update on public.self_assessment_result_bands
for each row execute function private.set_updated_at();

create or replace function private.can_read_self_assessment_test(
  target_test_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_super_admin())
    or exists (
      select 1
      from public.self_assessment_tests t
      where t.id = target_test_id
        and t.is_published
    );
$$;

revoke execute on function private.can_read_self_assessment_test(uuid)
  from public;
grant execute on function private.can_read_self_assessment_test(uuid)
  to anon, authenticated;

alter table public.self_assessment_tests enable row level security;
alter table public.self_assessment_questions enable row level security;
alter table public.self_assessment_result_bands enable row level security;

drop policy if exists self_assessment_tests_select
  on public.self_assessment_tests;
create policy self_assessment_tests_select
on public.self_assessment_tests for select to anon, authenticated
using ((select private.can_read_self_assessment_test(id)));

drop policy if exists self_assessment_tests_insert_admin
  on public.self_assessment_tests;
create policy self_assessment_tests_insert_admin
on public.self_assessment_tests for insert to authenticated
with check ((select private.is_super_admin()));

drop policy if exists self_assessment_tests_update_admin
  on public.self_assessment_tests;
create policy self_assessment_tests_update_admin
on public.self_assessment_tests for update to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

drop policy if exists self_assessment_questions_select
  on public.self_assessment_questions;
create policy self_assessment_questions_select
on public.self_assessment_questions for select to anon, authenticated
using ((select private.can_read_self_assessment_test(test_id)));

drop policy if exists self_assessment_questions_write_admin
  on public.self_assessment_questions;
create policy self_assessment_questions_write_admin
on public.self_assessment_questions for all to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

drop policy if exists self_assessment_result_bands_select
  on public.self_assessment_result_bands;
create policy self_assessment_result_bands_select
on public.self_assessment_result_bands for select to anon, authenticated
using ((select private.can_read_self_assessment_test(test_id)));

drop policy if exists self_assessment_result_bands_write_admin
  on public.self_assessment_result_bands;
create policy self_assessment_result_bands_write_admin
on public.self_assessment_result_bands for all to authenticated
using ((select private.is_super_admin()))
with check ((select private.is_super_admin()));

revoke all on table public.self_assessment_tests from public, anon, authenticated;
revoke all on table public.self_assessment_questions from public, anon, authenticated;
revoke all on table public.self_assessment_result_bands from public, anon, authenticated;
grant select on table public.self_assessment_tests to anon, authenticated;
grant select on table public.self_assessment_questions to anon, authenticated;
grant select on table public.self_assessment_result_bands to anon, authenticated;
grant insert, update on table public.self_assessment_tests to authenticated;
grant insert, update, delete on table public.self_assessment_questions
  to authenticated;
grant insert, update, delete on table public.self_assessment_result_bands
  to authenticated;

-- Admin edits are audited like other sensitive CMS changes.
create or replace function private.audit_self_assessment_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_id uuid := coalesce(new.id, old.id);
begin
  if (select auth.uid()) is not null then
    insert into public.admin_audit_logs (
      actor_user_id, action, entity_type, entity_id, metadata
    ) values (
      (select auth.uid()),
      'self_assessment_' || lower(tg_op),
      tg_table_name,
      row_id,
      '{}'::jsonb
    );
  end if;
  return coalesce(new, old);
end;
$$;

revoke execute on function private.audit_self_assessment_change()
  from public, anon, authenticated;

drop trigger if exists self_assessment_tests_audit
  on public.self_assessment_tests;
create trigger self_assessment_tests_audit
after insert or update or delete on public.self_assessment_tests
for each row execute function private.audit_self_assessment_change();

drop trigger if exists self_assessment_questions_audit
  on public.self_assessment_questions;
create trigger self_assessment_questions_audit
after insert or update or delete on public.self_assessment_questions
for each row execute function private.audit_self_assessment_change();

drop trigger if exists self_assessment_result_bands_audit
  on public.self_assessment_result_bands;
create trigger self_assessment_result_bands_audit
after insert or update or delete on public.self_assessment_result_bands
for each row execute function private.audit_self_assessment_change();

-- 3. Library content ---------------------------------------------------------------
create or replace function private.resource_library_payload()
returns jsonb
language sql
immutable
set search_path = ''
as $library_fn$
select $library$
{
 "categories": [
  {
   "slug": "ruqyah-lib-topic",
   "parent": "ruqyah",
   "name": "Ruqyah by topic",
   "name_bn": "বিষয়ভিত্তিক রুকইয়াহ",
   "sort": 210
  },
  {
   "slug": "ruqyah-lib-reciters",
   "parent": "ruqyah",
   "name": "Common ruqyah by reciter",
   "name_bn": "বিভিন্ন ক্বারির সাধারণ রুকইয়াহ",
   "sort": 211
  },
  {
   "slug": "ruqyah-lib-other",
   "parent": "ruqyah",
   "name": "Other ruqyah audio",
   "name_bn": "অন্যান্য রুকইয়াহ অডিও",
   "sort": 212
  },
  {
   "slug": "ruqyah-lib-special",
   "parent": "ruqyah",
   "name": "Selected ayat, surah and dua audio",
   "name_bn": "বিশেষ আয়াত, সুরা ও দোয়ার অডিও",
   "sort": 213
  },
  {
   "slug": "ruqyah-lib-hibshi",
   "parent": "ruqyah",
   "name": "Special ruqyah (Khalid al-Hibshi)",
   "name_bn": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ",
   "sort": 214
  },
  {
   "slug": "ruqyah-lib-short",
   "parent": "ruqyah",
   "name": "Alternate and short versions",
   "name_bn": "বিকল্প ও সংক্ষিপ্ত সংস্করণ",
   "sort": 215
  },
  {
   "slug": "ruqyah-lib-more-reciters",
   "parent": "ruqyah",
   "name": "More common ruqyah recitations",
   "name_bn": "আরও কিছু ক্বারির রুকইয়াহ",
   "sort": 216
  },
  {
   "slug": "pdf-ruqyah",
   "parent": "pdf",
   "name": "Ruqyah PDFs",
   "name_bn": "রুকইয়াহ বিষয়ক পিডিএফ",
   "sort": 401
  },
  {
   "slug": "self-diagnosis-guide",
   "parent": "self-diagnosis",
   "name": "Self-diagnosis guides",
   "name_bn": "সেলফ ডায়াগনোসিস গাইড",
   "sort": 501
  },
  {
   "slug": "dua-azkar-ma-01",
   "parent": "dua-azkar",
   "name": "হিফাজতের প্রাথমিক দোয়া",
   "name_bn": "হিফাজতের প্রাথমিক দোয়া",
   "sort": 301
  },
  {
   "slug": "dua-azkar-ma-02",
   "parent": "dua-azkar",
   "name": "হিফাজতের প্রাথমিক আয়াত (তিনকুল)",
   "name_bn": "হিফাজতের প্রাথমিক আয়াত (তিনকুল)",
   "sort": 302
  },
  {
   "slug": "dua-azkar-ma-03",
   "parent": "dua-azkar",
   "name": "উপকারী আরও কিছু আয়াত",
   "name_bn": "উপকারী আরও কিছু আয়াত",
   "sort": 303
  },
  {
   "slug": "dua-azkar-ma-04",
   "parent": "dua-azkar",
   "name": "হিফাজত ও ফজিলতের আরও দোয়া",
   "name_bn": "হিফাজত ও ফজিলতের আরও দোয়া",
   "sort": 304
  },
  {
   "slug": "dua-azkar-ma-05",
   "parent": "dua-azkar",
   "name": "সকাল-সন্ধ্যার আরও কিছু দোয়া",
   "name_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া",
   "sort": 305
  },
  {
   "slug": "dua-azkar-ma-06",
   "parent": "dua-azkar",
   "name": "ফজিলতপূর্ণ আরও কিছু দোয়া",
   "name_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া",
   "sort": 306
  },
  {
   "slug": "dua-azkar-ma-07",
   "parent": "dua-azkar",
   "name": "ঘুমের আগে: প্রাথমিক দোয়া ও আয়াত",
   "name_bn": "ঘুমের আগে: প্রাথমিক দোয়া ও আয়াত",
   "sort": 307
  },
  {
   "slug": "dua-azkar-ma-08",
   "parent": "dua-azkar",
   "name": "ঘুমের আগে: তিনকুল",
   "name_bn": "ঘুমের আগে: তিনকুল",
   "sort": 308
  },
  {
   "slug": "dua-azkar-ma-09",
   "parent": "dua-azkar",
   "name": "ঘুমের আগে: ফজিলতের আরও দোয়া",
   "name_bn": "ঘুমের আগে: ফজিলতের আরও দোয়া",
   "sort": 309
  },
  {
   "slug": "dua-azkar-ma-10",
   "parent": "dua-azkar",
   "name": "ঘুমের মাঝে সমস্যা হলে",
   "name_bn": "ঘুমের মাঝে সমস্যা হলে",
   "sort": 310
  },
  {
   "slug": "dua-azkar-ma-11",
   "parent": "dua-azkar",
   "name": "ঘুম থেকে জেগে: প্রাথমিক দোয়া",
   "name_bn": "ঘুম থেকে জেগে: প্রাথমিক দোয়া",
   "sort": 311
  },
  {
   "slug": "dua-azkar-ma-12",
   "parent": "dua-azkar",
   "name": "ঘুম থেকে জেগে: আরও কিছু আয়াত",
   "name_bn": "ঘুম থেকে জেগে: আরও কিছু আয়াত",
   "sort": 312
  },
  {
   "slug": "dua-azkar-ma-13",
   "parent": "dua-azkar",
   "name": "অন্যান্য সময়ের যিকর",
   "name_bn": "অন্যান্য সময়ের যিকর",
   "sort": 313
  },
  {
   "slug": "dua-azkar-ma-14",
   "parent": "dua-azkar",
   "name": "শত্রুর ক্ষতির আশংকা করলে",
   "name_bn": "শত্রুর ক্ষতির আশংকা করলে",
   "sort": 314
  },
  {
   "slug": "dua-azkar-ma-15",
   "parent": "dua-azkar",
   "name": "বিপদে বা পেরেশানির সময়",
   "name_bn": "বিপদে বা পেরেশানির সময়",
   "sort": 315
  },
  {
   "slug": "dua-azkar-ma-16",
   "parent": "dua-azkar",
   "name": "ফজিলতপূর্ণ আরও কিছু আয়াত",
   "name_bn": "ফজিলতপূর্ণ আরও কিছু আয়াত",
   "sort": 316
  },
  {
   "slug": "dua-azkar-ma-17",
   "parent": "dua-azkar",
   "name": "দোয়া কবুলের দোয়া",
   "name_bn": "দোয়া কবুলের দোয়া",
   "sort": 317
  },
  {
   "slug": "dua-azkar-ma-18",
   "parent": "dua-azkar",
   "name": "দাজ্জালের ক্ষতি থেকে বাঁচতে",
   "name_bn": "দাজ্জালের ক্ষতি থেকে বাঁচতে",
   "sort": 318
  }
 ],
 "audio": [
  {
   "slug": "ruqyah-lib-topic-01",
   "category": "ruqyah-lib-topic",
   "sort": 10,
   "title_bn": "বদনজরের রুকইয়াহ",
   "summary": "১০এমবি (৫৫মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-EvilEye-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-02",
   "category": "ruqyah-lib-topic",
   "sort": 20,
   "title_bn": "বদনজর ও হাসাদের রুকইয়াহ",
   "summary": "১৬এমবি (১ঘণ্টা ৩৪মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-EyeHasad-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-03",
   "category": "ruqyah-lib-topic",
   "sort": 30,
   "title_bn": "সিহরের রুকইয়াহ (জাদু ও জিন)",
   "summary": "১৪এমবি (১ঘন্টা ১৬মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Sihr-Mass-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-04",
   "category": "ruqyah-lib-topic",
   "sort": 40,
   "title_bn": "কালো যাদু, বান ও জিনের রুকইয়াহ",
   "summary": "১৬এমবি (১ঘন্টা ৩৪মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Sihr-Hibshi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-05",
   "category": "ruqyah-lib-topic",
   "sort": 50,
   "title_bn": "আয়াতুল হারক",
   "summary": "আযাব এবং জাহান্নাম সংক্রান্ত আয়াত · ১৪এমবি (৪৬মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Harq-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-06",
   "category": "ruqyah-lib-topic",
   "sort": 60,
   "title_bn": "জিনের আছরের রুকইয়াহ",
   "summary": "জিন সংক্রান্ত সব সমস্যায় উপকারী আয়াতগুলো · ১৯এমবি (১ঘন্টা ৪৮মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Jinn-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-07",
   "category": "ruqyah-lib-topic",
   "sort": 70,
   "title_bn": "তিনকুলের রুকইয়াহ",
   "summary": "সুরা ইখলাস, ফালাক, নাস এর পুনরাবৃত্তি · ৭এমবি (৩০ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-3Kul-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-08",
   "category": "ruqyah-lib-topic",
   "sort": 80,
   "title_bn": "আট সুরার রুকইয়াহ",
   "summary": "সুরা ইয়াসিন, সফফাত, দুখান, জিন, যিলযাল, ৩কুল · ১২এমবি (৫১ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-8surah-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-09",
   "category": "ruqyah-lib-topic",
   "sort": 90,
   "title_bn": "আয়াতুল কুরসির রুকইয়াহ",
   "summary": "৭এমবি (৩০ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-AyatulKursi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-topic-10",
   "category": "ruqyah-lib-topic",
   "sort": 100,
   "title_bn": "যাদুকরদের প্রতি অভিশাপ",
   "summary": "৪এমবি (১৩মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/curse-against-magician-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-01",
   "category": "ruqyah-lib-reciters",
   "sort": 10,
   "title_bn": "শাইখ আস-সুদাইস",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৮এমবি (৪৩ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Sudais-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-02",
   "category": "ruqyah-lib-reciters",
   "sort": 20,
   "title_bn": "শাইখ হুজাইফি",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৯এমবি (১ঘন্টা ২০মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Hujaifi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-03",
   "category": "ruqyah-lib-reciters",
   "sort": 30,
   "title_bn": "শাইখ আশ-শুরাইম",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৪ এমবি (৫৮মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Shuraim-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-04",
   "category": "ruqyah-lib-reciters",
   "sort": 40,
   "title_bn": "সা'দ আল-গামিদী",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৩এমবি (৩২মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Ghamidi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-05",
   "category": "ruqyah-lib-reciters",
   "sort": 50,
   "title_bn": "মিশারী রাশেদ আল-আফাসী",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৯এমবি (১ঘন্টা ১৪মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Mishary-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-06",
   "category": "ruqyah-lib-reciters",
   "sort": 60,
   "title_bn": "শাইখ আহমাদ আজমি",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৪এমবি (১ঘন্টা ১৮মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-AhmadAjmy-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-07",
   "category": "ruqyah-lib-reciters",
   "sort": 70,
   "title_bn": "নাসের আল কাতামি",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৮এমবি (৫২মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-NasserQatami-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-08",
   "category": "ruqyah-lib-reciters",
   "sort": 80,
   "title_bn": "শাইখ ইদরীস আবকার",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৮এমবি (১ঘন্টা ১৬মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-IdreesAbkar-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-09",
   "category": "ruqyah-lib-reciters",
   "sort": 90,
   "title_bn": "খালিদ আল হিবশী",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৯এমবি (১ঘন্টা ৮মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-KhalidHibshi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-10",
   "category": "ruqyah-lib-reciters",
   "sort": 100,
   "title_bn": "শাইখ লুহাইদান",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৮এমবি (৪৪মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Luhaidan-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-11",
   "category": "ruqyah-lib-reciters",
   "sort": 110,
   "title_bn": "মুফতি জুনাইদের সিডি থেকে",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১১এমবি (২৩মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-JunaidCD1-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-reciters-12",
   "category": "ruqyah-lib-reciters",
   "sort": 120,
   "title_bn": "মাজিদ আয-যামিল",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৫ এমবি (১৭মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-MajidZamil-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-01",
   "category": "ruqyah-lib-other",
   "sort": 10,
   "title_bn": "রুকইয়াহর দু‘আ",
   "summary": "৪এমবি (১০ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-dua-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-02",
   "category": "ruqyah-lib-other",
   "sort": 20,
   "title_bn": "আযান রুকইয়াহ (পুনরাবৃত্তি)",
   "summary": "১৫ মেগাবাইট (১৬ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Azan-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-02-v1",
   "category": "ruqyah-lib-other",
   "sort": 21,
   "title_bn": "আযান রুকইয়াহ (পুনরাবৃত্তি) (সিম্পল ভার্শন)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Azan1-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-03",
   "category": "ruqyah-lib-other",
   "sort": 30,
   "title_bn": "সুরা বাকারা (শাইখ সুদাইস)",
   "summary": "১ঘণ্টা ৩৬মিনিট (২৩এমবি)",
   "media_url": "https://files.ruqyahbd.org/audio/Surah-Baqara-by-Sudais-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-04",
   "category": "ruqyah-lib-other",
   "sort": 40,
   "title_bn": "সুরা ফাতিহার রুকইয়াহ",
   "summary": "২৯এমবি (১ঘন্টা)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-SuraFatiha-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-05",
   "category": "ruqyah-lib-other",
   "sort": 50,
   "title_bn": "যিনা ও ফাহিশা বিষয়ক রুকইয়াহ",
   "summary": "১৮এমবি (১ঘন্টা ৫মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Zina-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-06",
   "category": "ruqyah-lib-other",
   "sort": 60,
   "title_bn": "শিফা ও সাকিনাহর রুকইয়াহ",
   "summary": "১৪এমবি (৪৭ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Shifa-Sakina-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-06-v1",
   "category": "ruqyah-lib-other",
   "sort": 61,
   "title_bn": "শিফা ও সাকিনাহর রুকইয়াহ (ভার্সন-২)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Ayat-ShifaSakina-combo-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-other-07",
   "category": "ruqyah-lib-other",
   "sort": 70,
   "title_bn": "রুকইয়াহ খুরুজ",
   "summary": "১২ মেগাবাইট (৪৫ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Khuruj-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-01",
   "category": "ruqyah-lib-special",
   "sort": 10,
   "title_bn": "আয়াতুশ শিফা",
   "summary": "শারীরিক-মানসিক অসুস্থতায় উপকারী · ২এমবি (১মিনিট ২১সে.)",
   "media_url": "https://files.ruqyahbd.org/clips/ayat-shifa-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-01-v1",
   "category": "ruqyah-lib-special",
   "sort": 11,
   "title_bn": "আয়াতুশ শিফা (পুনরাবৃত্তি)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Ayat-shifa-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-02",
   "category": "ruqyah-lib-special",
   "sort": 20,
   "title_bn": "আয়াতুস সাকিনা",
   "summary": "পেরেশানি, ডিপ্রেশন ও মানসিক রোগে উপকারী · ৪এমবি (৩মি. ২০সে.)",
   "media_url": "https://files.ruqyahbd.org/clips/ayatus-sakinah-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-02-v1",
   "category": "ruqyah-lib-special",
   "sort": 21,
   "title_bn": "আয়াতুস সাকিনা (একত্রে)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Ayat-ShifaSakina-combo-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-03",
   "category": "ruqyah-lib-special",
   "sort": 30,
   "title_bn": "সুরা তাগাবুন",
   "summary": "৪এমবি (৪মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/SuraTaghabun-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-04",
   "category": "ruqyah-lib-special",
   "sort": 40,
   "title_bn": "সুরা যিলযাল থেকে নাস",
   "summary": "৫এমবি (৭মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Sura-Zilzal-to-Nas-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-05",
   "category": "ruqyah-lib-special",
   "sort": 50,
   "title_bn": "সুরা বাকারা (শাইখ হুজাইফি)",
   "summary": "জিন-জাদু এবং ওয়াসওয়াসার জটিল চিকিৎসায় কার্যকর · ২ঘন্টা ১২মিনিট (৩২এমবি)",
   "media_url": "https://files.ruqyahbd.org/audio/Surah-Baqara-by-Hujaifi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-06",
   "category": "ruqyah-lib-special",
   "sort": 60,
   "title_bn": "সুরা ফুরকান ২৩ আয়াত (পুনরাবৃত্তি)",
   "summary": "জাদু-টোনার সমস্যায় আক্রান্তদের জন্য উপকারী · ১২এমবি (১৬মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Furqan23-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-07",
   "category": "ruqyah-lib-special",
   "sort": 70,
   "title_bn": "লা-ইলাহা ইল্লাল্লাহু ওয়াহদাহু (১০০ বার)",
   "summary": "লা-শারীকালাহু লাহুল মূলকু ওয়ালাহুল হামদু ওয়াহুওয়া ‘আলা কুল্লি‌ শাইয়িন ক্বদীর · ৩.৫এমবি (১৪মিনিট)",
   "media_url": "https://files.ruqyahbd.org/clips/Dua-laa-ilaha-illallahu-wahdahu-100xtime-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-08",
   "category": "ruqyah-lib-special",
   "sort": 80,
   "title_bn": "আয়াতুল ইযাম",
   "summary": "হাড়ক্ষয় রোগ ও হাড়ের অন্যান্য সমস্যার জন্য · ৪এমবি (৪মিনিট)",
   "media_url": "https://files.ruqyahbd.org/clips%2Fayat-ejam-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-09",
   "category": "ruqyah-lib-special",
   "sort": 90,
   "title_bn": "রুকইয়াহ ইলম",
   "summary": "পড়াশোনা সংক্রান্ত ও বিবিধ সমস্যা জন্য · ২৯এমবি (১ঘন্টা ২৮মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-ilm-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-10",
   "category": "ruqyah-lib-special",
   "sort": 100,
   "title_bn": "রুকইয়াহ তাদমির ও ক্বিতাল",
   "summary": "অত্যাচারী জিন শয়তানের চিকিৎসায় উপকারী। · ২৪এমবি (১ঘন্টা ৩৫মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-tadmir-qital-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-special-11",
   "category": "ruqyah-lib-special",
   "sort": 110,
   "title_bn": "জাদু ধ্বংসের দোয়া",
   "summary": "২.৫এমবি (৫মিনিট)",
   "media_url": "https://files.ruqyahbd.org/clips/Dua-DestroyMagic-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-01",
   "category": "ruqyah-lib-hibshi",
   "sort": 1,
   "title_bn": "জিনদের প্রতি নসিহত",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-nasiha-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-02",
   "category": "ruqyah-lib-hibshi",
   "sort": 2,
   "title_bn": "তালাকের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-talaq-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-03",
   "category": "ruqyah-lib-hibshi",
   "sort": 3,
   "title_bn": "রিযিকের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-rizq-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-04",
   "category": "ruqyah-lib-hibshi",
   "sort": 4,
   "title_bn": "স্তন ক্যান্সারের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-bcanser-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-05",
   "category": "ruqyah-lib-hibshi",
   "sort": 5,
   "title_bn": "হাঁটা ও পায়ের সমস্যার রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-walk-leg-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-06",
   "category": "ruqyah-lib-hibshi",
   "sort": 6,
   "title_bn": "হিদায়াতের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-hidaya-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-07",
   "category": "ruqyah-lib-hibshi",
   "sort": 7,
   "title_bn": "খ্রিস্টান জিনের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-nasara-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-08",
   "category": "ruqyah-lib-hibshi",
   "sort": 8,
   "title_bn": "ইহুদি জিনের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-yahod-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-09",
   "category": "ruqyah-lib-hibshi",
   "sort": 9,
   "title_bn": "পাখির রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-bird-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-10",
   "category": "ruqyah-lib-hibshi",
   "sort": 10,
   "title_bn": "কবরস্থানের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-graves-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-11",
   "category": "ruqyah-lib-hibshi",
   "sort": 11,
   "title_bn": "পাহাড়ের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-jibal-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-12",
   "category": "ruqyah-lib-hibshi",
   "sort": 12,
   "title_bn": "সমুদ্র, নদী ও পানির রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-sea-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-13",
   "category": "ruqyah-lib-hibshi",
   "sort": 13,
   "title_bn": "চুলের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-shaar-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-hibshi-14",
   "category": "ruqyah-lib-hibshi",
   "sort": 14,
   "title_bn": "তারা ও গ্রহের রুকইয়াহ",
   "summary": "খালিদ আল হিবশীর বিশেষ রুকইয়াহ। নির্দিষ্ট প্রয়োজনে, অভিজ্ঞ কারো পরামর্শ নিয়ে শুনুন।",
   "media_url": "https://archive.org/download/ruqyah-hibshi/ruqya-stars-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-short-01",
   "category": "ruqyah-lib-short",
   "sort": 10,
   "title_bn": "রুকইয়াহর দোয়া ২ (শায়খ ইদরিস)",
   "summary": "১১এমবি (২৪মিনিট ৩সে.)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Dua-by-idrees-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-short-02",
   "category": "ruqyah-lib-short",
   "sort": 20,
   "title_bn": "কমন রুকইয়াহ (বাংলা অনুবাদসহ)",
   "summary": "৩২এমবি (৩৯মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-withBangla-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-short-03",
   "category": "ruqyah-lib-short",
   "sort": 30,
   "title_bn": "রুকইয়াহ যিনা (সংক্ষিপ্ত)",
   "summary": "৯ এমবি (২২ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Zina-Short-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-short-04",
   "category": "ruqyah-lib-short",
   "sort": 40,
   "title_bn": "রুকইয়াহ খুরুজ (সংক্ষিপ্ত)",
   "summary": "১৩এমবি (৩৩ মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Khuruj-Short-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-short-05",
   "category": "ruqyah-lib-short",
   "sort": 50,
   "title_bn": "আয়াতুল হারক ২ (শাইখ শুরাইম)",
   "summary": "১৪ এমবি (৪০মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Harq-Shuraim-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-short-06",
   "category": "ruqyah-lib-short",
   "sort": 60,
   "title_bn": "আয়াতুল হারক ৩ (শাইখ সালেহ, দীর্ঘ)",
   "summary": "১৪এমবি (১ঘণ্টা ৩৭মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Harq-long-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-01",
   "category": "ruqyah-lib-more-reciters",
   "sort": 10,
   "title_bn": "সিদ্দিক আল মিনশাবী",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৪এমবি (৫৯মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Manshawi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-02",
   "category": "ruqyah-lib-more-reciters",
   "sort": 20,
   "title_bn": "শাইখ মুহাইসিনী",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৮এমবি (৪৫মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Muhaisini-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-03",
   "category": "ruqyah-lib-more-reciters",
   "sort": 30,
   "title_bn": "সা‘দ আল-গামিদী (দীর্ঘ)",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৫এমবি (১ঘন্টা ৫মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-ghamidi-long-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-04",
   "category": "ruqyah-lib-more-reciters",
   "sort": 40,
   "title_bn": "খালিদ হিবশির মুখতাসার (সংক্ষিপ্ত)",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৭এমবি (২৩মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Hibshi-Mukhtasar-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-05",
   "category": "ruqyah-lib-more-reciters",
   "sort": 50,
   "title_bn": "মুহাম্মাদ আল-হাশিমি (সংক্ষিপ্ত)",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ৪ এমবি (১০মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-Hashimi-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-06",
   "category": "ruqyah-lib-more-reciters",
   "sort": 60,
   "title_bn": "মুহাম্মাদ বিন মুসা আত্তারি",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৪এমবি (৬৮মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio%2FRuqyah-MousaAttary-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-07",
   "category": "ruqyah-lib-more-reciters",
   "sort": 70,
   "title_bn": "ধমকের সুরে তিলাওয়াত",
   "summary": "সাধারণ রুকইয়ার আয়াতের তিলাওয়াত · ১৫এমবি (৩৯মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio/Ruqyah-WithStrongForce-ruqyahbd.org.mp3"
  },
  {
   "slug": "ruqyah-lib-more-reciters-08",
   "category": "ruqyah-lib-more-reciters",
   "sort": 80,
   "title_bn": "শাইখ নোওরিন মুহাম্মাদ সিদ্দিক (হাফস ছাড়া অন্য কিরাআত)",
   "summary": "নোটঃ ইনার ক্বিরাতের ধরণ একটু ভিন্ন, এটা ভুল না। · ১৫ এমবি (৪১মিনিট)",
   "media_url": "https://files.ruqyahbd.org/audio%2FRuqyah-NourinSiddiq-ruqyahbd.org.mp3"
  }
 ],
 "pdf": [
  {
   "slug": "pdf-ruqyah-01",
   "category": "pdf-ruqyah",
   "sort": 10,
   "title_bn": "রুকইয়ার কমন আয়াত",
   "summary": "সাধারণ রুকইয়ার আয়াত, যেকোনো ঝাড়ফুঁকে উপকারী",
   "media_url": "https://files.ruqyahbd.org/pdf/ruqyah-ayat-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-01-v1",
   "category": "pdf-ruqyah",
   "sort": 11,
   "title_bn": "রুকইয়ার কমন আয়াত (কলিকাতা ছাপা)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-ruqyah-kolkata-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-02",
   "category": "pdf-ruqyah",
   "sort": 20,
   "title_bn": "রুকইয়াহর দোয়া",
   "summary": "রুকইয়ার উপযোগী কিছু দোয়া, যেকোনো ঝাড়ফুঁকে উপকারী",
   "media_url": "https://files.ruqyahbd.org/pdf/ruqyah-dua-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-03",
   "category": "pdf-ruqyah",
   "sort": 30,
   "title_bn": "রুকইয়ার আয়াত ও দোয়া (একত্রে)",
   "summary": "একত্রে সাধারণ আয়াত ও দোয়ার পিডিএফ",
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-ruqyah-n-dua-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-04",
   "category": "pdf-ruqyah",
   "sort": 40,
   "title_bn": "বদনজরের রুকইয়াহর আয়াত",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-ruqyah-evileye-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-05",
   "category": "pdf-ruqyah",
   "sort": 50,
   "title_bn": "আয়াতুল হারক",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/ayatul-harq-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-06",
   "category": "pdf-ruqyah",
   "sort": 60,
   "title_bn": "সিহরের আয়াত (অর্থসহ, সংক্ষিপ্ত)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-sihr-bangla-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-07",
   "category": "pdf-ruqyah",
   "sort": 70,
   "title_bn": "জ্বিন-শয়তান বিষয়ক আয়াত",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-jinn-full-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-08",
   "category": "pdf-ruqyah",
   "sort": 80,
   "title_bn": "আয়াতুশ শিফা এবং তাখফীফ",
   "summary": "শারীরিক-মানসিক এবং অন্যান্য রোগব্যাধির জন্য",
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-shifa-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-09",
   "category": "pdf-ruqyah",
   "sort": 90,
   "title_bn": "আয়াতুস সাকিনাহ",
   "summary": "মানসিক সমস্যা ও অস্থিরতার জন্য",
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-sakina-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-10",
   "category": "pdf-ruqyah",
   "sort": 100,
   "title_bn": "যাদুকরের প্রতি অভিশাপ এবং যাদু ধ্বংসের দোয়া",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/curse-against-magician-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-10-v1",
   "category": "pdf-ruqyah",
   "sort": 101,
   "title_bn": "যাদুকরের প্রতি অভিশাপ এবং যাদু ধ্বংসের দোয়া (বাংলা)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/curse-against-magician-bangla-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-11",
   "category": "pdf-ruqyah",
   "sort": 110,
   "title_bn": "আয়াতে কিতাল ওয়া তাদমির",
   "summary": "মৃত্যু, যুদ্ধ এবং ধ্বংস উল্লেখিত আয়াতসমুহ",
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-qital-tadmir-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-11-v1",
   "category": "pdf-ruqyah",
   "sort": 111,
   "title_bn": "আয়াতে কিতাল ওয়া তাদমির (সংক্ষিপ্ত)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-qital-short-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-12",
   "category": "pdf-ruqyah",
   "sort": 120,
   "title_bn": "আয়াতে ইযাম",
   "summary": "হাড়ক্ষয় রোগের রুকইয়াহ",
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-ejam-mobile-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-12-v1",
   "category": "pdf-ruqyah",
   "sort": 121,
   "title_bn": "আয়াতে ইযাম (কলিকাতা ছাপা)",
   "summary": null,
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-ejam-kolkatta-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-13",
   "category": "pdf-ruqyah",
   "sort": 130,
   "title_bn": "রুকইয়াহ যিনা ফাহিশা",
   "summary": "যিনা এবং ফাহিশার নিন্দা সংক্রান্ত আয়াতসমুহ",
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-zina-fahisha-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-14",
   "category": "pdf-ruqyah",
   "sort": 140,
   "title_bn": "আয়াত খুরুজ ওয়া তানযিল",
   "summary": "বের হওয়া, অবতরণ করা বিষয়ক আয়াত",
   "media_url": "https://files.ruqyahbd.org/pdf/ayat-khuruj-ruqyahbd.org.pdf"
  },
  {
   "slug": "pdf-ruqyah-15",
   "category": "pdf-ruqyah",
   "sort": 150,
   "title_bn": "মাসনুন আমল (সংক্ষিপ্ত)",
   "summary": "জিন জাদু নজর এবং বিপদ-আপদ থেকে হিফাজতের আমল",
   "media_url": "https://files.ruqyahbd.org/docs/masnun-amal-ruqyahbd.org.pdf"
  }
 ],
 "dua": [
  {
   "slug": "dua-ma-01-01",
   "category": "dua-azkar-ma-01",
   "sort": 1,
   "type": "dua",
   "title_bn": "হিফাজতের প্রাথমিক দোয়া ১",
   "summary": "সকাল-সন্ধ্যায় ১০ বার",
   "arabic_text": "لاَ إِلَهَ إِلَّا اللَّهُ، وَحْدَہٗ لاَ شَرِيْكَ لَہٗ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ يُحْيِيْ وَيُمِيْتُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيْرٌ",
   "transliteration": "লা ইলা-হা ইল্লাল্লা-হু ওয়াহ্‌দাহূ লা- শারীকালাহূ, লাহুল মুলকু, ওয়ালাহুল হামদু, ইউহ্‌ য়ী ওয়া ইউমীতু, ওয়াহুয়া ‘আলা কুল্লি শায়ইন ক্বাদীর।",
   "translation": "একমাত্র আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই, তাঁর কোনো শরীক নেই; রাজত্ব তাঁরই, প্রশংসাও তাঁরই; তিনি জীবিত করেন, তিনিই মৃত্যু দেন, আর তিনি সকল কিছুর ওপর ক্ষমতাবান।",
   "reference_text": "আহমাদ ২৩০০৭",
   "media_url": null
  },
  {
   "slug": "dua-ma-01-02",
   "category": "dua-azkar-ma-01",
   "sort": 2,
   "type": "dua",
   "title_bn": "আয়াতুল কুরসি, ১ বার",
   "summary": null,
   "arabic_text": "أَعُوْذُ بِاللّٰهِ مِنَ الشَّيْطَانِ الرَّجِيْمِ\nبِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِیْمِ\nاَللّٰهُ لَاۤ اِلٰهَ اِلَّا هُوَ ۚاَلْحَیُّ الْقَیُّوْمُ ۚ لَا تَاْخُذُہٗ سِنَةٌ وَّلَا نَوْمٌ ؕ لَہٗ مَا فِی السَّمٰوٰتِ وَمَا فِی الْاَرْضِ ؕ مَنْ ذَا الَّذِیْ یَشْفَعُ عِنْدَہٗۤ اِلَّا بِاِذْنِہٖ ؕ یَعْلَمُ مَا بَیْنَ اَیْدِیْهِمْ وَمَا خَلْفَهُمْ ۚوَلَا یُحِیْطُوْنَ بِشَیْءٍ مِّنْ عِلْمِہٖۤ اِلَّا بِمَاشَآءَ ۚوَسِعَ كُرْسِیُّهُ السَّمٰوٰتِ وَالْاَرْضَ ۚوَلَا یَـُٔوْدُہٗ حِفْظُهُمَا ۚوَهُوَ الْعَلِیُّ الْعَظِیْمُ ﴿۲۵۵﴾",
   "transliteration": null,
   "translation": "বিতাড়িত শয়তান থেকে আমি আল্লাহ্‌র আশ্রয় নিচ্ছি।\nআল্লাহ্, তিনি ছাড়া কোনো সত্য ইলাহ্ নেই। তিনি চিরঞ্জীব, সর্বসত্তার ধারক। তাঁকে তন্দ্রাও স্পর্শ করতে পারে না, নিদ্রাও নয়। আসমানসমূহে যা রয়েছে ও যমীনে যা রয়েছে সবই তাঁর। কে সে, যে তাঁর অনুমতি ব্যতীত তাঁর কাছে সুপারিশ করবে? তাদের সামনে ও পিছনে যা কিছু আছে তা তিনি জানেন। আর যা তিনি ইচ্ছে করেন তা ছাড়া তাঁর জ্ঞানের কোনো কিছুকেই তারা পরিবেষ্টন করতে পারে না। তাঁর ‘কুরসী’ আসমানসমূহ ও যমীনকে পরিব্যাপ্ত করে আছে; আর এ দুটোর রক্ষণাবেক্ষণ তাঁর জন্য বোঝা হয় না। আর তিনি সুউচ্চ সুমহান।",
   "reference_text": "হাকিম ১/৫৬২, তারিখে কাবির ১/২৪",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_002_255.mp3"
  },
  {
   "slug": "dua-ma-01-03",
   "category": "dua-azkar-ma-01",
   "sort": 3,
   "type": "dua",
   "title_bn": "হিফাজতের প্রাথমিক দোয়া ৩",
   "summary": "৩ বার",
   "arabic_text": "أَعُوْذُ بِكَلِمَاتِ اللّٰه ِالتَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ",
   "transliteration": "আ‘ঊযু বিকালিমা-তিল্লা-হিত তা-ম্মাতি মিন শাররি মা খালাক্ব।",
   "translation": "আল্লাহ্‌র পরিপূর্ণ কালেমাসমূহের ওসিলায় আমি তাঁর নিকট তাঁর সৃষ্টির ক্ষতি থেকে আশ্রয় চাই।",
   "reference_text": "তিরমিযি ৩৫৫৯",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_93.mp3"
  },
  {
   "slug": "dua-ma-01-04",
   "category": "dua-azkar-ma-01",
   "sort": 4,
   "type": "dua",
   "title_bn": "হিফাজতের প্রাথমিক দোয়া ৪",
   "summary": "৩ বার",
   "arabic_text": "بِسْمِ اللّٰه ِالَّذِيْ لَا يَضُرُّ مَعَ اسْمِهٖ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيْعُ العَلِيْمُ",
   "transliteration": "বিস্‌মিল্লা-হিল্লাযী লা ইয়াদ্বুররু মা‘আ ইস্‌মিহী শাইউন ফিল্ আরদ্বি ওয়ালা ফিস্ সামা-ই, ওয়াহুয়াস্ সামী‘উল ‘আলীম",
   "translation": "আল্লাহ্‌র নামে; যাঁর নামের সাথে আসমান ও যমীনে কোনো কিছুই ক্ষতি করতে পারে না। আর তিনি সর্বশ্রোতা, মহাজ্ঞানী।”",
   "reference_text": "তিরমিযি ৩৩৮৮",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_83.mp3"
  },
  {
   "slug": "dua-ma-01-05",
   "category": "dua-azkar-ma-01",
   "sort": 5,
   "type": "dua",
   "title_bn": "হিফাজতের প্রাথমিক দোয়া ৫",
   "summary": "৭ বার",
   "arabic_text": "حَسْبِيَ اللّٰهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيْمِ",
   "transliteration": "হাসবিয়াল্লা-হু লা ইলা-হা ইল্লা হুয়া, ‘আলাইহি তাওয়াক্কালতু, ওয়াহুয়া রব্বুল ‘আরশিল ‘আযীম",
   "translation": "আল্লাহই আমার জন্য যথেষ্ট, তিনি ছাড়া আর কোনো হক্ব ইলাহ নেই। আমি তাঁর উপরই ভরসা করি। আর তিনি মহান আরশের রব্ব।",
   "reference_text": "আবু দাউদ ৫০৮১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_80.mp3"
  },
  {
   "slug": "dua-ma-02-01",
   "category": "dua-azkar-ma-02",
   "sort": 1,
   "type": "dua",
   "title_bn": "তিন কুল ৩বার পড়ুন",
   "summary": null,
   "arabic_text": "بِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nقُلْ ہُوَ اللہُ اَحَدٌ ﴿۱﴾ اَللہُ الصَّمَدُ ﴿۲﴾ لَمْ یَلِدْ ۬ۙ وَ لَمْ یُوۡلَدْ ﴿۳﴾ وَ لَمْ یَكُنۡ لَّہٗ كُفُوًا اَحَدٌ ﴿۴﴾\n\nبِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nقُلْ اَعُوۡذُ بِرَبِّ الْفَلَقِ ﴿۱﴾ مِنۡ شَرِّ مَا خَلَقَ ﴿۲﴾ وَ مِنۡ شَرِّ غَاسِقٍ اِذَا وَقَبَ ﴿۳﴾ وَ مِنۡ شَرِّ النَّفّٰثٰتِ فِی الْعُقَدِ ﴿۴﴾ وَ مِنۡ شَرِّ حَاسِدٍ اِذَا حَسَدَ ﴿۵﴾\n\nبِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nقُلْ اَعُوۡذُ بِرَبِّ النَّاسِ ﴿۱﴾ مَلِکِ النَّاسِ ﴿۲﴾ اِلٰہِ النَّاسِ ﴿۳﴾ مِنۡ شَرِّ الْوَسْوَاسِ ۬ۙ الْخَنَّاسِ ﴿۴﴾ الَّذِیۡ یُوَسْوِسُ فِیۡ صُدُوۡرِ النَّاسِ ﴿۵﴾ مِنَ الْجِنَّۃِ وَ النَّاسِ ﴿۶﴾ \"",
   "transliteration": null,
   "translation": "বলুন, তিনি আল্লাহ্, এক-অদ্বিতীয়। আল্লাহ্ হচ্ছেন ‘সামাদ’ (তিনি কারো মুখাপেক্ষী নন, সকলেই তাঁর মুখাপেক্ষী)। তিনি কাউকেও জন্ম দেন নি এবং তাঁকেও জন্ম দেয়া হয় নি। আর তাঁর সমতুল্য কেউই নেই।\n\nবলুন, আমি আশ্রয় প্রার্থনা করছি ঊষার রবের। তিনি যা সৃষ্টি করেছেন তার অনিষ্ট হতে। ‘আর অনিষ্ট হতে রাতের অন্ধকারের, যখন তা গভীর হয়। আর অনিষ্ট হতে সমস্ত নারীদের, যারা গিরায় ফুঁক দেয়। আর অনিষ্ট হতে হিংসুকের, যখন সে হিংসা করে।\n\nবলুন, আমি আশ্রয় প্রার্থনা করছি মানুষের রবের, মানুষের অধিপতির, মানুষের ইলাহের কাছে, আত্মগোপনকারী কুমন্ত্রণাদাতার অনিষ্ট হতে; যে কুমন্ত্রণা দেয় মানুষের অন্তরে, জিনের মধ্য থেকে এবং মানুষের মধ্য থেকে।",
   "reference_text": "তিরমিযি ৩৫৭৫",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_3qul.mp3"
  },
  {
   "slug": "dua-ma-03-01",
   "category": "dua-azkar-ma-03",
   "sort": 1,
   "type": "dua",
   "title_bn": "সুরা বাকারা; আয়াত ১-৫, ২৫৫-২৫৭, ২৮৪-২৮৬",
   "summary": "সুরা বাকারা; আয়াত ১-৫, ২৫৫-২৫৭, ২৮৪-২৮৬\n- ১ বার করে পড়ুন",
   "arabic_text": "بِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nالٓـمّٓ ﴿۱﴾ ذٰلِکَ الْکِتٰبُ لَا رَیۡبَ ۚۖۛ فِیۡہِ ۚۛ ہُدًی لِّلْمُتَّقِیۡنَ ﴿۲﴾ الَّذِیۡنَ یُؤْمِنُوۡنَ بِالْغَیۡبِ وَیُقِیۡمُوۡنَ الصَّلٰوۃَ وَمِمَّا رَزَقْنٰہُمۡ یُنۡفِقُوۡنَ ﴿۳﴾ وَالَّذِیۡنَ یُؤْمِنُوۡنَ بِمَاۤ اُنۡزِلَ اِلَیۡکَ وَمَاۤ اُنۡزِلَ مِنۡ قَبْلِکَ ۚ وَ بِالۡاٰخِرَۃِ ہُمۡ یُوۡقِنُوۡنَ ﴿۴﴾ اُولٰٓئِکَ عَلٰی ہُدًی مِّنۡ رَّبِّہِمۡ ٭ وَ اُولٰٓئِکَ ہُمُ الْمُفْلِحُوۡنَ ﴿۵﴾\n\nبِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nاَللّٰهُ لَاۤ اِلٰهَ اِلَّا هُوَ ۚاَلْحَیُّ الْقَیُّوْمُ ۚ لَا تَاْخُذُہٗ سِنَةٌ وَّلَا نَوْمٌ ؕ لَہٗ مَا فِی السَّمٰوٰتِ وَمَا فِی الْاَرْضِ ؕ مَنْ ذَا الَّذِیْ یَشْفَعُ عِنْدَہٗۤ اِلَّا بِاِذْنِہٖ ؕ یَعْلَمُ مَا بَیْنَ اَیْدِیْهِمْ وَمَا خَلْفَهُمْ ۚوَلَا یُحِیْطُوْنَ بِشَیْءٍ مِّنْ عِلْمِہٖۤ اِلَّا بِمَاشَآءَ ۚوَسِعَ كُرْسِیُّهُ السَّمٰوٰتِ وَالْاَرْضَ ۚوَلَا یَـُٔوْدُہٗ حِفْظُهُمَا ۚوَهُوَ الْعَلِیُّ الْعَظِیْمُ ﴿۲۵۵﴾ لَاۤ اِکۡرَاہَ فِی الدِّیۡنِ ۟ۙ قَدۡ تَّبَیَّنَ الرُّشۡدُ مِنَ الۡغَیِّ ۚ فَمَنۡ یَّکۡفُرۡ بِالطَّاغُوۡتِ وَ یُؤۡمِنۡۢ بِاللّٰہِ فَقَدِ اسۡتَمۡسَکَ بِالۡعُرۡوَۃِ الۡوُثۡقٰی ٭ لَا انۡفِصَامَ لَہَا ؕ وَ اللّٰہُ سَمِیۡعٌ عَلِیۡمٌ ﴿۲۵۶﴾ اَللّٰہُ وَلِیُّ الَّذِیۡنَ اٰمَنُوۡا ۙ یُخۡرِجُہُمۡ مِّنَ الظُّلُمٰتِ اِلَی النُّوۡرِ۬ؕ وَ الَّذِیۡنَ کَفَرُوۡۤا اَوۡلِیٰٓـُٔہُمُ الطَّاغُوۡتُ ۙ یُخۡرِجُوۡنَہُمۡ مِّنَ النُّوۡرِ اِلَی الظُّلُمٰتِ ؕ اُولٰٓئِکَ اَصۡحٰبُ النَّارِ ۚ ہُمۡ فِیۡہَا خٰلِدُوۡنَ ﴿۲۵۷﴾٪\n\nبِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nلِلّٰہِ مَا فِی السَّمٰوٰتِ وَ مَا فِی الۡاَرۡضِ ؕ وَ اِنۡ تُبۡدُوۡا مَا فِیۡۤ اَنۡفُسِکُمۡ اَوۡ تُخۡفُوۡہُ یُحَاسِبۡکُمۡ بِہِ اللّٰہُ ؕ فَیَغۡفِرُ لِمَنۡ یَّشَآءُ وَ یُعَذِّبُ مَنۡ یَّشَآءُ ؕ وَ اللّٰہُ عَلٰی کُلِّ شَیۡءٍ قَدِیۡرٌ ﴿۲۸۴﴾ اٰمَنَ الرَّسُوْلُ بِمَاۤ اُنْزِلَ اِلَیْهِ مِنْ رَّبِّہٖ وَالْمُؤْمِنُوْنَ ؕ كُلٌّ اٰمَنَ بِاللّٰهِ وَمَلٰٓئِکَتِہٖ وَكُتُبِہٖ وَرُسُلِہٖ ۟ لَا نُفَرِّقُ بَیْنَ اَحَدٍ مِّنْ رُّسُلِہٖ ۟ وَقَالُوْا سَمِعْنَا وَ اَطَعْنَا ٭ غُفْرَانَكَ رَبَّنَا وَ اِلَیْكَ الْمَصِیْرُ ﴿۲۸۵﴾ لَا یُکَلِّفُ اللّٰهُ نَفْسًا اِلَّا وُسْعَهَا ؕ لَهَا مَا کَسَبَتْ وَعَلَیْهَا مَا اكْتَسَبَتْ ؕ رَبَّنَا لَا تُؤَاخِذْنَاۤ اِنْ نَّسِیْنَاۤ اَوْ اَخْطَاْنَا ۚرَبَّنَا وَلَا تَحْمِلْ عَلَیْنَاۤ اِصْرًا کَمَا حَمَلْتَہٗ عَلَی الَّذِیْنَ مِنْ قَبْلِنَا ۚرَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَۃَ لَنَا بِہٖ ۚوَاعْفُ عَنَّا ٝ وَاغْفِرْ لَنَا ٝ وَارْحَمْنَا ٝ اَنْتَ مَوْلٰىنَا فَانْصُرْنَا عَلَی الْقَوْمِ الْکٰفِرِیْنَ ﴿۲۸۶﴾",
   "transliteration": null,
   "translation": "আলিফ লাম মীম। (১) এ সেই কিতাব যাতে কোনই সন্দেহ নেই। পথ প্রদর্শনকারী পরহেযগারদের জন্য। (২) যারা অদেখা বিষয়ের উপর বিশ্বাস স্থাপন করে এবং নামায প্রতিষ্ঠা করে। আর আমি তাদেরকে যে রুযী দান করেছি তা থেকে ব্যয় করে। (৩) এবং যারা বিশ্বাস স্থাপন করেছে সেসব বিষয়ের উপর যা কিছু তোমার প্রতি অবতীর্ণ হয়েছে এবং সেসব বিষয়ের উপর যা তোমার পূর্ববর্তীদের প্রতি অবতীর্ণ হয়েছে। আর আখেরাতকে যারা নিশ্চিত বলে বিশ্বাস করে। (৪) তারাই নিজেদের পালনকর্তার পক্ষ থেকে সুপথ প্রাপ্ত, আর তারাই যথার্থ সফলকাম।(৫)\n\nআল্লাহ (এমন এক সত্তা যে), তিনি ছাড়া কোন মাবুদ নেই। (তিনি) চিরঞ্জীব ও অবিনশ্বর। তাঁকে তন্দ্রায় কিংবা নিদ্রায় ধরে না। আসমানে ও জমিনে যা কিছু আছে তা (সব) তাঁরই। এমন কে আছে যে তাঁর অনুমতি ছাড়া তাঁর কাছে সুপারিশ করতে পারে? যা কিছু তাদের সামনে আছে ও যা কিছু তাদের পেছনে আছে তিনি তা (সব) জানেন। তিনি যতটুকু চান তা ছাড়া তাঁর জ্ঞানের কিছুই তারা আয়ত্ত করতে পারে না। তাঁর কুরসী আসমান ও জমিন পরিব্যাপ্ত করে আছে। এ দুইয়ের সংরক্ষণে তাঁর কোন কষ্ট হয় না। তিনি সর্বোচ্চ, মহামহিম। (২৫৫) দ্বীনের ব্যাপারে কোন জবরদস্তি নেই। নিঃসন্দেহে হেদায়াত গোমরাহী থেকে পৃথক হয়ে গেছে। এখন যারা গোমরাহকারী ‘তাগুত’দেরকে অস্বীকার করবে এবং আল্লাহতে বিশ্বাস স্থাপন করবে, সে ধারণ করে নিয়েছে সুদৃঢ় হাতল যা ভাংবার নয়। আর আল্লাহ সবই শুনেন এবং জানেন। (২৫৬) আল্লাহ ঈমানদারদের অভিভাবক। তিনি তাদেরকে অন্ধকার থেকে বের করে আলোতে নিয়ে আসেন। আর যারা কাফের তাদের অভিভাবক হল তাগূত। তারা তাদেরকে আলো থেকে বের করে অন্ধকারে নিয়ে যায়। তারা জাহান্নামের অধিবাসী, সেখানে তারা চিরদিন থাকবে।\n\nযা কিছু আকাশসমূহে রয়েছে এবং যা কিছু যমীনে আছে, সব আল্লাহরই। যদি তোমরা মনের কথা প্রকাশ কর কিংবা গোপন কর, আল্লাহ তোমাদের কাছ থেকে তার হিসাব নেবেন। অতঃপর যাকে ইচ্ছা তিনি ক্ষমা করবেন এবং যাকে ইচ্ছা তিনি শাস্তি দেবেন। আল্লাহ সর্ববিষয়ে শক্তিমান।(২৮৪) রসূল বিশ্বাস রাখেন ঐ সমস্ত বিষয় সম্পর্কে যা তাঁর পালনকর্তার পক্ষ থেকে তাঁর কাছে অবতীর্ণ হয়েছে এবং মুসলমানরাও সবাই বিশ্বাস রাখে আল্লাহর প্রতি, তাঁর ফেরেশতাদের প্রতি, তাঁর গ্রন্থসমুহের প্রতি এবং তাঁর পয়গম্বরগণের প্রতি। তারা বলে আমরা তাঁর পয়গম্বরদের মধ্যে কোন তারতম্য করিনা। তারা বলে, আমরা শুনেছি এবং কবুল করেছি। আমরা তোমার ক্ষমা চাই, হে আমাদের পালনকর্তা। তোমারই দিকে প্রত্যাবর্তন করতে হবে। (২৮৫) আল্লাহ কাউকে তার সাধ্যাতীত কোন কাজের ভার দেন না, সে তাই পায় যা সে উপার্জন করে এবং তাই তার উপর বর্তায় যা সে করে। হে আমাদের পালনকর্তা, যদি আমরা ভুলে যাই কিংবা ভুল করি, তবে আমাদেরকে অপরাধী করো না। হে আমাদের পালনকর্তা! এবং আমাদের উপর এমন দায়িত্ব অর্পণ করো না, যেমন আমাদের পূর্ববর্তীদের উপর অর্পণ করেছ, হে আমাদের প্রভূ! এবং আমাদের দ্বারা ঐ বোঝা বহন করিও না, যা বহন করার শক্তি আমাদের নাই। আমাদের পাপ মোচন কর। আমাদেরকে ক্ষমা কর এবং আমাদের প্রতি দয়া কর। তুমিই আমাদের প্রভু। সুতরাং কাফের সম্প্রদায়ের বিরুদ্ধে আমাদের কে সাহায্যে কর।(২৮৬)",
   "reference_text": "তাবারানী ৯/১৪৭",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_1234.mp3"
  },
  {
   "slug": "dua-ma-03-02",
   "category": "dua-azkar-ma-03",
   "sort": 2,
   "type": "dua",
   "title_bn": "উপকারী আরও কিছু আয়াত ২",
   "summary": "তিন বার করে বলুন",
   "arabic_text": "فَاللّٰهُ خَيْرٌ حٰفِظًا ۪ وَّهُوَ اَرْحَمُ الرّٰحِمِيْنَ ﴿۶۴﴾\n\nوَحِفْظًا مِّنْ كُلِّ شَيْطٰنٍ مَّارِدٍ ۚ﴿٨﴾",
   "transliteration": null,
   "translation": "আল্লাহ উত্তম হেফাযতকারী এবং তিনিই সর্বাধিক দয়ালু।\n\nএবং সংরক্ষন করেছি প্রত্যেক অবাধ্য শয়তান থেকে।",
   "reference_text": null,
   "media_url": null
  },
  {
   "slug": "dua-ma-04-01",
   "category": "dua-azkar-ma-04",
   "sort": 1,
   "type": "dua",
   "title_bn": "সায়্যিদুল ইস্তেগফার",
   "summary": null,
   "arabic_text": "اَللّٰهُمَّ أَنْتَ رَبِّيْ لَا إِلٰهَ إِلَّا أَنْتَ، خَلَقْتَنِيْ وَأَنَا عَبْدُكَ، وَأَنَا عَلٰى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوْذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوْءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوْءُ بِذَنْۢبِيْ فَاغْفِرْ لِيْ فَإِنَّهٗ لَا يَغْفِرُ الذُّنُوْبَ إِلَّا أَنْتَ.",
   "transliteration": "আল্লা-হুম্মা আনতা রব্বী লা ইলা-হা ইল্লা আনতা খলাক্বতানী ওয়া আনা ‘আব্দুকা, ওয়া আনা ‘আলা ‘আহদিকা ওয়া ওয়া‘দিকা মাস্তাত্বা‘তু। আ‘উযু বিকা মিন শাররি মা সানা‘তু, আবূউলাকা বিনি‘মাতিকা ‘আলাইয়্যা, ওয়া আবূউ বিযাম্বী। ফাগফির লী, ফাইন্নাহূ লা ইয়াগফিরুয যুনূবা ইল্লা আনতা।",
   "translation": "হে আল্লাহ্‌! আপনি আমার রব্ব, আপনি ছাড়া আর কোনো হক্ব ইলাহ নেই। আপনি আমাকে সৃষ্টি করেছেন এবং আমি আপনার বান্দা। আর আমি আমার সাধ্য মতো আপনার (তাওহীদের) অঙ্গীকার ও (জান্নাতের) প্রতিশ্রুতির উপর রয়েছি। আমি আমার কৃতকর্মের অনিষ্ট থেকে আপনার আশ্রয় চাই। আপনি আমাকে আপনার যে নিয়ামত দিয়েছেন তা আমি স্বীকার করছি, আর আমি স্বীকার করছি আমার অপরাধ। অতএব আপনি আমাকে মাফ করুন। নিশ্চয় আপনি ছাড়া আর কেউ গুনাহসমূহ মাফ করে না।",
   "reference_text": "বুখারি ৬৩০৬",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_76.mp3"
  },
  {
   "slug": "dua-ma-04-02",
   "category": "dua-azkar-ma-04",
   "sort": 2,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ২",
   "summary": null,
   "arabic_text": "اَللّٰهُمَّ أَنْتَ رَبِّيْ لَا إِلٰهَ إِلَّا أَنْتَ ، عَلَيْكَ تَوَكَّلْتُ ، وَأَنْتَ رَبُّ الْعَرْشِ الْكَرِيْمِ ، مَا شَاءَ اللّٰهُ كَانَ ، وَمَا لَمْ يَشَأْ لَمْ يَكُنْ ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللّٰهِ الْعَلِيِّ الْعَظِيْمِ ، أَعْلَمُ أَنَّ اللّٰهَ عَلىٰ كُلِّ شَيْءٍ قَدِيْرٌ ، وَأَنَّ اللّٰهَ قَدْ أَحَاطَ بِكُلِّ شَيْءٍ عِلْمًا ، اَللّٰهُمَّ إِنِّيْ أَعُوْذُ بِكَ مِنْ شَرِّ نَفْسِيْ ، وَمِنْ شَرِّ كُلِّ دَابَّةٍ أَنْتَ آخِذٌۢ بِنَاصِيَتِهَا ، إِنَّ رَبِّيْ عَلىٰ صِرَاطٍ مُّسْتَقِيْمٍ",
   "transliteration": "আল্লা-হুম্মা, আন্তা রাব্বী, লা-ইলাহা ইল্লা-আন্তা, ‘আলাইকা তাওয়াক্কালতু ওয়া আন্তা রাব্বুল ‘আরশিল কারীম, মাশা-আল্লাহু কা-না ওয়া মা-লাম ইয়াশা’ লাম ইয়াকুন, ওয়া লা-হাউলা ওয়া লা-কূউওয়াতা ইল্লা-বিল্লা‌-হিল আ’লিইয়িল ‘আযীম। আ’লামু আন্নাল্লাহা ‘আলা কুল্লি শাই ইন ক্বদীর, ওয়া আন্নাল্লা-হা ক্বদ আহা-ত্বা বিকুল্লি শাই ইন 'ইলমা- আল্লা-হুম্মা ইন্নী আ’উযু বিকা মিন শাররি নাফসী ওয়া মিন শাররি কুল্লি দাব্বাতিন আনতা আ-খিযুম বি না-সিয়াতিহা- ইন্না রাব্বী ‘আলা সিরা-তিম মুস্তাকীম।",
   "translation": "হে আল্লাহ! তুমি আমার প্রতিপালক। তুমি ছাড়া আর কোনো ইলাহ নেই। আমি তোমারই উপর ভরসা করেছি। আর তুমি তো মহান আরশের মালিক। আল্লাহ যা চান তাই হয়। আর তিনি যা চান না তা হয় না। কোনো শক্তি ও সামর্থ নেই একমাত্র মহামহিম আল্লাহ ছাড়া। আমি জানি যে, আল্লাহ তায়ালা সবকিছুর উপর সর্বশক্তিমান এবং সবকিছুকে তিনি তার ইলম দ্বারা বেষ্টন করে রেখেছেন। হে আল্লাহ! আমি তোমার কাছে আশ্রয় প্রার্থনা করছি আমার নফসের অনিষ্ট থেকে এবং সব প্রাণীদের অনিষ্ট থেকে। তাদের সব ক্ষমতা তো তোমারই হাতে। অবশ্যই আমার প্রতিপালক সঠিক পথেই রয়েছেন।",
   "reference_text": "তাবারানী;আদ-দুআ ৩৪৩",
   "media_url": null
  },
  {
   "slug": "dua-ma-04-03",
   "category": "dua-azkar-ma-04",
   "sort": 3,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ৩",
   "summary": null,
   "arabic_text": "أَعُوْذُ بِكَلِمَاتِ اللّٰهِ التَّامَّةِ ، مِنْ كُلِّ شَيْطَانٍ وَّهَامَّةٍ ، وَمِنْ كُلِّ عَيْنٍ لَّامَّةٍ",
   "transliteration": "আউযু বিকালিমা-তিল্লা-হিত্তা-ম্মাতি মিং কুল্লি শাইত্বা-নিন- ওয়াহা-ম্মাহ। ওয়ামিং কুল্লি আইনিন লা-ম্মাহ।",
   "translation": "আমরা আল্লাহর পরিপূর্ণ কল্যাণময় বাক্যাবলীর দ্বারা প্রতিটি শয়তান, প্রাণনাশকারী বিষাক্ত জীব এবং অনিষ্টকারী বদনজর থেকে আশ্রয় প্রার্থনা করছি।",
   "reference_text": "বুখারি ৩৩৭১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_4_3.mp3"
  },
  {
   "slug": "dua-ma-04-04",
   "category": "dua-azkar-ma-04",
   "sort": 4,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ৪",
   "summary": null,
   "arabic_text": "أَعُوْذُ بِكَلِمَاتِ اللّٰهِ التَّامَّةِ، مِنْ غَضَبِهٖ وَعِقَابِهٖ وَشَرِّ عِبَادِهٖ وَمِنْ هَمَزَاتِ الشَّيَاطِيْنِ وَأَنْ يَّحْضُرُوْنِ",
   "transliteration": "আ‘ঊযু বিকালিমা-তিল্লাহিত্তা-ম্মাতি মিন গাদাবিহি ওয়া ইকা-বিহি ওয়া শাররি ‘ইবা-দিহি ওয়ামিন হামাযা-তিশ শায়া-তিনি ওয়া আই-ইয়াহদুরূন।",
   "translation": "আমি আল্লাহর পরিপূর্ণ কালামসমূহের দ্বারা আশ্রয় চাই তাঁর ক্রোধ থেকে, তাঁর শাস্তি থেকে এবং তাঁর বান্দাদের অনিষ্ট থেকে, আর শয়তানদের কুমন্ত্রণা থেকে এবং তাদের উপস্থিতি থেকে।",
   "reference_text": "তিরমিযি ২৪২",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_109.mp3"
  },
  {
   "slug": "dua-ma-04-05",
   "category": "dua-azkar-ma-04",
   "sort": 5,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ৫",
   "summary": null,
   "arabic_text": "أَعُوْذُ بِكَلِمَاتِ اللّٰهِ التَّامَّاتِ الَّتِيْ لَا يُجَاوِزُهُنَّ بَرٌّ وَلَا فَاجِرٌ ، مِنْ شَرِّ مَا خَلَقَ وَذَرَأَ وَبَرَأَ ، وَمِنْ شَرِّ مَا يَنْزِلُ مِنَ السَّمَاءِ وَمِنْ شَرِّ مَا يَعْرُجُ فِيْهَا ، وَمِنْ شَرِّ مَا ذَرَأَ فِى الْأَرْضِ ، وَمِنْ شَرِّ مَا يَخْرُجُ مِنْهَا ، وَمِنْ فِتَنِ اللَّيْلِ وَالنَّهَارِ، وَمِنْ طَوَارِقِ اللَّيْلِ وَالنَّهَارِ، إِلَّا طَارِقًا يَطْرُقُ بِخَيْرٍ يَا رَحْمٰنُ",
   "transliteration": "আ‘ঊযু বিকালিমা-তিল্লা-হিত্-তা-ম্মা-তিল্লাতী লা ইয়ুজাউইযুহুন্না বাররুন ওয়ালা ফা-জিরুম মিন শাররি মা খালাক্বা, ওয়া বারা’আ, ওয়া যারা’আ, ওয়ামিন শাররি মা ইয়ানযিলু মিনাস্ সামা-য়ি, ওয়ামিন শাররি মা যারাআ ফিল আরদ্বি, ওয়ামিন শাররি মা ইয়াখরুজু মিনহা, ওয়ামিন শাররি ফিতানিল-লাইলি ওয়ান-নাহা-রি, ওয়ামিন শাররি কুল্লি ত্বা-রিকিন ইল্লা ত্বা-রিকান ইয়াত্বরুকু বিখাইরিন, ইয়া রহ্‌মানু",
   "translation": "আমি আল্লাহ্‌র ঐ সকল পরিপূর্ণ বাণীসমূহের সাহায্যে আশ্রয় চাই যা কোনো সৎলোক বা অসৎলোক অতিক্রম করতে পারে না— আল্লাহ যা সৃষ্টি করেছেন, অস্তিত্বে এনেছেন এবং তৈরি করেছেন তার অনিষ্ট থেকে, আসমান থেকে যা নেমে আসে তার অনিষ্ট থেকে, যা আকাশে উঠে তার অনিষ্ট থেকে, যা পৃথিবীতে তিনি সৃষ্টি করেছেন তার অনিষ্ট থেকে, যা পৃথিবী থেকে বেরিয়ে আসে তার অনিষ্ট থেকে, দিনে-রাতে সংঘটিত ফেতনার অনিষ্ট থেকে, আর রাত্রিবেলা হঠাৎ করে আগত অনিষ্ট থেকে, তবে রাতে আগত যে বিষয় কল্যাণ নিয়ে আসে তা ব্যতীত; হে দয়াময়!",
   "reference_text": "আহমাদ ১৫৪৬১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_234.mp3"
  },
  {
   "slug": "dua-ma-04-06",
   "category": "dua-azkar-ma-04",
   "sort": 6,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ৬",
   "summary": null,
   "arabic_text": "اَللَّهُمَّ إِنِّيْ أَعُوْذُ بِوَجْهِكَ الْكَرِيْمِ ، وَكَلِمَاتِكَ التَّامَّاتِ مِنْ شَرِّ مَا أَنْتَ آخِذٌ بِنَاصِيَتِهِ ، اللَّهُمَّ أَنْتَ تَكْشِفُ الْمَغْرَمَ وَالْمَأْثَمَ ، اللَّهُمَّ لَا يُهْزَمُ جُنْدُكَ ، وَلَا يُخْلَفُ وَعْدُكُ ، سُبْحَانَكَ وَبِحَمْدِكَ",
   "transliteration": null,
   "translation": "হে আল্লাহ! তােমার দয়ালু ও পবিত্র স্বত্বা আর তােমার পরিপূর্ণ কালেমার মাধ্যমে সেই সকল কিছুর অনিষ্ট থেকে আশ্রয় প্রার্থনা করছি যা তােমার আয়ত্বাধীন রয়েছে। হে আল্লাহ তুমি পাপ ও দেনা মুক্তকারী। হে আল্লাহ তােমার সেনাদল পরাস্থ হয় না আর না তােমার ওয়াদা ভঙ্গ হয়। আমরা তােমারই গুণকীর্তন ও প্রশংসা বর্ণনা করি।",
   "reference_text": null,
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_4_6.mp3"
  },
  {
   "slug": "dua-ma-04-07",
   "category": "dua-azkar-ma-04",
   "sort": 7,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ৭",
   "summary": null,
   "arabic_text": "اَللَّهُمَّ إِنِّيْ أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِى الدُّنْيَا وَالآخِرَةِ ، اللَّهُمَّ إِنِّيْ أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِيْ دِيْنِيْ وَدُنْيَايَ وَأَهْلِيْ وَمَالِيْ ، اَللَّهُمَ اسْتُرْ عَوْرَتِيْ ، وَآمِنْ رَوْعَتِيْ ، وَاحْفَظْنِيْ مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِيْ ، وَعَنْ يَمِيْنِيْ ، وَعَنْ شِمَالِيْ ، وَمِنْ فَوْقِيْ ، وَأَعُوْذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِيْ",
   "transliteration": "আল্লা-হুম্মা ইন্নী আসআলুকাল ‘আফওয়া ওয়াল- ‘আ-ফিয়াতা ফিদ্দুনইয়া ওয়াল আ-খিরাতি। আল্লা-হুম্মা ইন্নী আসআলুকাল ‘আফওয়া ওয়াল-‘আ-ফিয়াতা ফী দীনী ওয়াদুনইয়াইয়া, ওয়া আহ্‌লী ওয়া মা-লী, আল্লা-হুম্মাসতুর ‘আওরা-তী ওয়া আ-মিন রাও‘আ-তি। আল্লা-হুম্মাহফাযনী মিম্বাইনি ইয়াদাইয়্যা ওয়া মিন খালফী ওয়া ‘আন ইয়ামীনী ওয়া শিমা-লী ওয়া মিন ফাওকী। ওয়া আ‘ঊযু বি‘আযামাতিকা আন উগতা-লা মিন তাহ্‌তী",
   "translation": "হে আল্লাহ! আমি আপনার নিকট দুনিয়া ও আখেরাতে ক্ষমা ও নিরাপত্তা প্রার্থনা করছি। হে আল্লাহ! আমি আপনার নিকট ক্ষমা এবং নিরাপত্তা চাচ্ছি আমার দ্বীন, দুনিয়া, পরিবার ও অর্থ-সম্পদের। হে আল্লাহ! আপনি আমার গোপন ত্রুটিসমূহ ঢেকে রাখুন, আমার উদ্বিগ্নতাকে রূপান্তরিত করুন নিরাপত্তায়। হে আল্লাহ! আপনি আমাকে হেফাযত করুন আমার সামনের দিক থেকে, আমার পিছনের দিক থেকে, আমার ডান দিক থেকে, আমার বাম দিক থেকে এবং আমার উপরের দিক থেকে। আর আপনার মহত্ত্বের অসিলায় আশ্রয় চাই আমার নীচ থেকে হঠাৎ আক্রান্ত হওয়া থেকে",
   "reference_text": "আদাবুল মুফরাদ ১২০০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_81.mp3"
  },
  {
   "slug": "dua-ma-04-08",
   "category": "dua-azkar-ma-04",
   "sort": 8,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ৮",
   "summary": "দুটি ৩ বার করে",
   "arabic_text": "اَللّٰهُمَّ عَافِنِيْ فِيْ بَدَنِيْ، اللّٰهُمَّ عَافِنِيْ فِيْ سَمْعِيْ، اللّٰهُمَّ عَافِنِيْ فِيْ بَصَرِيْ، لاَ إِلَهَ إِلاَّ أَنْتَ، -\nاللّٰهُمَّ إِنِّيْ أَعُوْذُ بِكَ مِنَ الْكُفْرِ، وَالفَقْرِ، وَأَعُوْذُ بِكَ مِنْ عَذَابِ القَبْرِ، لاَ إِلَهَ إِلاَّ أَنْتَ -",
   "transliteration": "আল্লা-হুম্মা ‘আ-ফিনী ফী বাদানী, আল্লা-হুম্মা ‘আ-ফিনী ফী সাম্‘ঈ আল্লা-হুম্মা ‘আ-ফিনী ফী বাসারী। লা ইলা-হা ইল্লা আনতা। আল্লা-হুম্মা ইন্নী আ‘উযু বিকা মিনাল কুফরি ওয়াল-ফাক্বরি ওয়া আ‘উযু বিকা মিন ‘আযা-বিল ক্বাবরি, লা ইলাহা ইল্লা আন্‌তা।",
   "translation": "হে আল্লাহ! আমাকে নিরাপত্তা দিন আমার শরীরে। হে আল্লাহ! আমাকে নিরাপত্তা দিন আমার শ্রবণশক্তিতে। হে আল্লাহ! আমাকে নিরাপত্তা দিন আমার দৃষ্টিশক্তিতে। আপনি ছাড়া কোনো হক্ব ইলাহ নেই। হে আল্লাহ! আমি আপনার কাছে আশ্রয় চাই কুফরি ও দারিদ্র্য থেকে। আর আমি আপনার আশ্রয় চাই কবরের আযাব থেকে। আপনি ছাড়া আর কোনো হক্ব ইলাহ নেই।",
   "reference_text": "আবু দাউদ ৫০৯২",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_79.mp3"
  },
  {
   "slug": "dua-ma-04-09",
   "category": "dua-azkar-ma-04",
   "sort": 9,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ৯",
   "summary": null,
   "arabic_text": "يَا حَيُّ يَا قَيُّوْمُ بِرَحْمَتِكَ أَسْتَغِيْثُ، أَصْلِحْ لِيْ شَأْنِيْ كُلَّهٗ، وَلَا تَكِلْنِيْ إِلٰى نَفْسِيْ طَرْفَةَ عَيْنٍ،",
   "transliteration": "ইয়া হাইয়্যু ইয়া ক্বাইয়্যূমু বিরহ্‌মাতিকা আস্তাগীসু, আসলিহ্‌ লী শা’নী কুল্লাহু, ওয়ালা তাকিলনী ইলা নাফসী ত্বারফাতা ‘আইন",
   "translation": "হে চিরঞ্জীব, হে চিরস্থায়ী! আমি আপনার রহমতের অসীলায় আপনার কাছে উদ্ধার কামনা করি, আপনি আমার সার্বিক অবস্থা সংশোধন করে দিন, আর আমাকে আমার নিজের কাছে নিমেষের জন্যও সোপর্দ করবেন না।",
   "reference_text": "হাকিম ১/৫৪৫",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_85.mp3"
  },
  {
   "slug": "dua-ma-04-10",
   "category": "dua-azkar-ma-04",
   "sort": 10,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ১০",
   "summary": null,
   "arabic_text": "اَللّٰهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمٰوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَّمَلِيْكَهُ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ، أَعُوْذُ بِكَ مِنْ شَرِّ نَفْسِيْ، وَمِنْ شَرِّ الشَّيْطَانِ وَ شِرْكِهِ ، وَأَنْ أَقْتَرِفَ عَلٰى نَفْسِيْ سُوْءًا، أَوْ أَجُرَّهُ إِلٰى مُسْلِمٍ،",
   "transliteration": "আল্লা-হুম্মা আ-লিমাল গাইবি ওয়াশ্‌শাহা-দাতি ফা-ত্বিরাস সামা-ওয়া-তি ওয়াল আরদ্বি, রব্বা কুল্লি শাই’ইন ওয়া মালীকাহু, আশহাদু আল-লা ইলা-হা ইল্লা আনতা। আ‘উযু বিকা মিন শাররি নাফ্‌সী ওয়া মিন শাররিশ শাইত্বা-নি ওয়াশিরকিহী ওয়া আন আক্বতারিফা ‘আলা নাফ্‌সী সূওআন আউ আজুররাহূ ইলা মুসলিম",
   "translation": "হে আল্লাহ! হে গায়েব ও উপস্থিতের জ্ঞানী, হে আসমানসমূহ ও যমীনের স্রষ্টা, হে সব কিছুর রব্ব ও মালিক! আমি সাক্ষ্য দিচ্ছি যে, আপনি ছাড়া আর কোনো হক্ব ইলাহ নেই। আমি আপনার কাছে আশ্রয় চাই আমার আত্মার অনিষ্ট থেকে, শয়তানের অনিষ্টতা থেকে ও তার শির্ক বা তার ফাঁদ থেকে, আমার নিজের উপর কোনো অনিষ্ট করা, অথবা কোনো মুসলিমের দিকে তা টেনে নেওয়া থেকে।",
   "reference_text": "তিরমিযি ৩৬২৯",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_82.mp3"
  },
  {
   "slug": "dua-ma-04-11",
   "category": "dua-azkar-ma-04",
   "sort": 11,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ১১",
   "summary": null,
   "arabic_text": "أَعُوْذُ بِوَجْهِ اللَّهِ الْعَظِيْمِ الَّذِي لَا شَيْءَ أَعْظَمُ مِنْهُ ، وَبِكَلِمَاتِهِ التَّامَّاتِ الَّتِي لَا يُجَاوِزُهُنَّ بَرٌّ وَلَا فَاجِرٌ ، وَأَسْمَاءِ اللَّهِ الْحُسْنَى مَا عَلِمْتُ مِنْهَا ، وَمَا لَمْ أَعْلَمْ ، مِنْ شَرِّ مَا خَلَقَ ، وَذَرَأَ ، وَبَرَأَ ، وَمِنْ شَرِّ كُلِّ ذِيْ شَرٍّ لَا أُطِيْقُ شَرَّهُ ، وَمِنْ شَرِّ كُلِّ ذِيْ شَرٍّ أَنْتَ آخِذٌ بِنَاصِيَتِهِ ، إِنَّ رَبِّيْ عَلَى صِرَاطٍ مُسْتَقِيْمٍ",
   "transliteration": "আউ-যুবি ওয়াজহিল্লা-হিল আযিমিল্লাযি লা লা-শাইআ আ'যামু মিনহু। ওয়া বিকালিমাতিল্লা-হিত তাম্মা‌তিল লাতী লা-ইউজা-উইয়ূযু হুন্না বাররুন ওয়ালা-ফাজির ওয়া আসমা-ইল্লাহিল হুসনা মা-আলিমাতু মিনহা ওয়া মা-লাম আয়লামু মিন শাররি মা-খলাকা ওয়া যারাআ ওয়া বারাআ ওয়া মিন শাররি কুললি যি শাররিন লা-উত্বীক্বু শাররুহু- ওয়ামিন শাররি কুললি যি শাররিন আনতা আ-খিযুম বিনা-ছিয়াতিহী ইন্না রাব্বী 'আলা-সিরাতিম মুসতাক্বীম।",
   "translation": "আমি মহান আল্লাহ তায়ালার সুমহান স্বত্বার আশ্রয় প্রার্থনা করি যার চেয়ে বড় আর কিছু নেই এবং আল্লাহ তায়ালার পবিত্র কালেমার মাধ্যমে আশ্রয় চাই যাকে কোন কল্যাণ ও অনিষ্ট অতিক্রম করে না। আর আল্লাহ তায়ালা সুন্দর নামসমূহের মাধ্যমে যা আমি জানি ও যা জানিনা। আর আশ্রয় প্রার্থনা করি সৃষ্টি জগতের সকল প্রকার অনিষ্ট থেকে যা তােমার আয়ত্বাধীন। নিশ্চয় আমার প্রভু সরল সােজা পথেই ।",
   "reference_text": null,
   "media_url": null
  },
  {
   "slug": "dua-ma-04-12",
   "category": "dua-azkar-ma-04",
   "sort": 12,
   "type": "dua",
   "title_bn": "হিফাজত ও ফজিলতের আরও দোয়া ১২",
   "summary": null,
   "arabic_text": "تَحَصَّنْتُ بِاللَّهِ الَّذِي لَا إِلَهَ إِلَّا هُوَ ، إِلَهِي وَإِلَهِ كُلِّ شَيْءٍ ، وَاعْتَصَمْتُ بِرَبِّي وَرَبِّ كُلِّ شَيْءٍ ، وَتَوَكَّلْتُ عَلَى الْحَيِّ الَّذِي لَا يَمُوتُ ، وَاسْتَدْفَعْتُ الشَّرَّ بِلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ ، حَسْبِيَ اللَّهُ وَنِعْمَ الْوَكِيلُ ، حَسْبِيَ الرَّبُّ مِنَ الْعِبَادِ ، حَسْبِيَ الْخَالِقُ مِنَ الْمَخْلُوقِ ، حَسْبِيَ الرَّازِقُ مِنَ الْمَرْزُوقِ ، حَسْبِيَ الَّذِي هُوَ حَسْبِي ، حَسْبِيَ الَّذِي بِيَدِهِ مَلَكُوتُ كُلِّ شَيْءٍ ، وَهُوَ يُجِيرُ وَلَا يُجَارُ عَلَيْهِ ، حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ",
   "transliteration": null,
   "translation": "সেই আল্লাহকে রক্ষা কর্তা মেনেছি যাকে ব্যতীত আমার কোন উপাস্য নেই। তিনি আমার এবং সকল কিছুর উপাস্য। আমি আমার প্রভুকে আঁকড়ে ধরেছি এবং সেই চিরঞ্জীবের উপর ভরসা রাখি যার মৃত্যু নেই। এবং তার কাছেই অনিষ্টকে দমন করার সামর্থ চাই কেননা শক্তি-সামর্থ কেবল আল্লাহ তায়ালার। আল্লাহই আমার জন্যে যথেষ্ট এবং তিনিই উত্তম সাহায্যকারী। আমার প্রভু বান্দাদের অনিষ্ট থেকে রক্ষার জন্যে যথেষ্ট। আমার জন্য সৃষ্টি কর্তা যথেষ্ট, সমস্ত সৃষ্টিজগত থেকে রক্ষার জন্যে। রিযিকদাতা হিসেবে আমার জন্যে যথেষ্ট, রিযিক গ্রহণকারীদের থেকে রক্ষা করতে। আমার জন্য যিনি যথেষ্ট হওয়ার তিনিই যথেষ্ট। ঐ সত্ত্বা আমার জন্য যথেষ্ট যার হাতে সমস্ত কিছুর রাজত্ব তার কাছেই আশ্রয় নিতে হয় তার বিরুদ্ধে নয়। আল্লাহই আমার জন্য যথেষ্ট, তিনি ছাড়া আর কোনো হক্ব ইলাহ নেই। আমি তাঁর উপরই ভরসা করি। আর তিনি মহান আরশের রব্ব।",
   "reference_text": null,
   "media_url": null
  },
  {
   "slug": "dua-ma-05-01",
   "category": "dua-azkar-ma-05",
   "sort": 1,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ১",
   "summary": "সকালে বলুন",
   "arabic_text": "اللّٰهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوْتُ وَإِلَيْكَ النُّشُوْرُ",
   "transliteration": "আল্লা-হুম্মা বিকা আসবাহ্‌না ওয়াবিকা আমসাইনা ওয়াবিকা নাহ্‌ইয়া, ওয়াবিকা নামূতু ওয়া ইলাইকান নুশূর",
   "translation": "হে আল্লাহ! আমরা আপনার জন্য সকালে উপনীত হয়েছি এবং আপনারই জন্য আমরা বিকালে উপনীত হয়েছি। আর আপনার দ্বারা আমরা জীবিত থাকি, আপনার দ্বারাই আমরা মারা যাব; আর আপনার দিকেই উত্থিত হব।",
   "reference_text": "তিরমিযি ৩৩৯১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_75.mp3"
  },
  {
   "slug": "dua-ma-05-02",
   "category": "dua-azkar-ma-05",
   "sort": 2,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ২",
   "summary": "বিকালে বলুন",
   "arabic_text": "اللّٰهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوْتُ، وَإِلَيْكَ الْمَصِيْرُ",
   "transliteration": "আল্লা-হুম্মা বিকা আমসাইনা ওয়াবিকা আসবাহ্‌না ওয়াবিকা নাহ্‌ইয়া ওয়াবিকা নামূতু ওয়া ইলাইকাল মাসীর।",
   "translation": "হে আল্লাহ!আমরা আপনার জন্য বিকালে উপনীত হয়েছি এবং আপনারই জন্য আমরা সকালে উপনীত হয়েছি। আর আপনার দ্বারা আমরা জীবিত থাকি, আপনার দ্বারাই আমরা মারা যাব;আর আপনার দিকেই প্রত্যাবর্তিত হব।",
   "reference_text": "তিরমিযি ৩৩৯১",
   "media_url": null
  },
  {
   "slug": "dua-ma-05-03",
   "category": "dua-azkar-ma-05",
   "sort": 3,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ৩",
   "summary": "সকালে বলুন",
   "arabic_text": "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلّٰهِ، وَالْحَمْدُ لِلّٰهِ، لاَ إِلَهَ إلاَّ اللّٰهُ وَحْدَهُ لاَ شَرِيْكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيْرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِيْ هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوْذُ بِكَ مِنْ شَرِّ مَا فِيْ هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوْذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوْذُ بِكَ مِنْ عَذَابٍ فِيْ النَّارِ وَعَذَابٍ فِيْ الْقَبْرِ",
   "transliteration": "আসবাহ্‌না ওয়া আসবাহাল মুলকু লিল্লাহি ওয়ালহাম্‌দু লিল্লাহি, লা ইলা-হা ইল্লাল্লা-হু ওয়াহ্‌দাহু লা শারীকা লাহু, লাহুল মুলকু ওয়া লাহুল হামদু, ওয়াহুয়া আলা কুল্লি শাই’ইন ক্বাদীর। রব্বি আস্আলুকা খাইরা মা ফী হা-যাল ইয়াউমি ওয়া খাইরা মা বা‘দাহু, ওয়া আ‘ঊযু বিকা মিন শাররি মা ফী হা-যাল ইয়াউমি ওয়া শাররি মা বা‘দাহু। রব্বি আঊযু বিকা মিনাল কাসালি ওয়া সূইল-কিবারি। রব্বি আ‘ঊযু বিকা মিন ‘আযাবিন ফিন্না-রি ওয়া আযাবিন্ ফিল ক্বাবরি",
   "translation": "আমরা আল্লাহর জন্য সকালে উপনীত হয়েছি, অনুরূপ যাবতীয় রাজত্বও সকালে উপনীত হয়েছে, আল্লাহ্‌র জন্য। সমুদয় প্রশংসা আল্লাহ্‌র জন্য। একমাত্র আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই, তাঁর কোনো শরীক নেই। রাজত্ব তাঁরই এবং প্রশংসাও তাঁর, আর তিনি সকল কিছুর উপর ক্ষমতাবান। হে রব্ব! এই দিনের মাঝে এবং এর পরে যা কিছু কল্যাণ আছে আমি আপনার নিকট তা প্রার্থনা করি। আর এই দিনের মাঝে এবং এর পরে যা কিছু অকল্যাণ আছে, তা থেকে আমি আপনার আশ্রয় চাই। হে রব্ব! আমি আপনার কাছে আশ্রয় চাই অলসতা ও খারাপ বার্ধক্য থেকে। হে রব্ব!আমি আপনার কাছে আশ্রয় চাই জাহান্নামে আযাব হওয়া থেকে এবং কবরে আযাব হওয়া থেকে।",
   "reference_text": "মুসলিম ২৭২৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_74.mp3"
  },
  {
   "slug": "dua-ma-05-04",
   "category": "dua-azkar-ma-05",
   "sort": 4,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ৪",
   "summary": "বিকালে বলুন",
   "arabic_text": "أَمْسَيْنَا وَ أَمْسَىا الْمُلْكُ لِلّٰهِ، وَالْحَمْدُ لِلّٰهِ، لاَ إِلَهَ إلاَّ اللّٰهُ وَحْدَهُ لاَ شَرِيْكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيْرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِيْ هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوْذُ بِكَ مِنْ شَرِّ مَا فِيْ هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوْذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوْذُ بِكَ مِنْ عَذَابٍ فِيْ النَّارِ وَعَذَابٍ فِيْ الْقَبْرِ",
   "transliteration": "আমসাইনা ওয়া আমসাল মুলকু লিল্লাহি ওয়ালহাম্‌দু লিল্লাহি, লা ইলা-হা ইল্লাল্লা-হু ওয়াহ্‌দাহু লা শারীকা লাহু, লাহুল মুলকু ওয়া লাহুল হামদু, ওয়াহুয়া আলা কুল্লি শাই’ইন ক্বাদীর। রব্বি আস্আলুকা খাইরা মা ফী হাযিহিল লাইলাতি ওয়া খাইরা মা বা‘দাহা, ওয়া আ‘ঊযু বিকা মিন শাররি মা ফী হাযিহিল লাইলাতি ওয়া শাররি মা বা‘দাহা। রব্বি আঊযু বিকা মিনাল কাসালি ওয়া সূইল-কিবারি। রব্বি আ‘ঊযু বিকা মিন ‘আযাবিন ফিন্না-রি ওয়া আযাবিন্ ফিল ক্বাবরি",
   "translation": "আমরা আল্লাহর জন্য বিকালে উপনীত হয়েছি, অনুরূপ যাবতীয় রাজত্বও বিকালে উপনীত হয়েছে, আল্লাহ্‌র জন্য। সমুদয় প্রশংসা আল্লাহ্‌র জন্য। একমাত্র আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই, তাঁর কোনো শরীক নেই। রাজত্ব তাঁরই এবং প্রশংসাও তাঁর, আর তিনি সকল কিছুর উপর ক্ষমতাবান। হে রব্ব! এই রাতের মাঝে এবং এর পরে যা কিছু কল্যাণ আছে আমি আপনার নিকট তা প্রার্থনা করি। আর এই রাতের মাঝে এবং এর পরে যা কিছু অকল্যাণ আছে, তা থেকে আমি আপনার আশ্রয় চাই। হে রব্ব! আমি আপনার কাছে আশ্রয় চাই অলসতা ও খারাপ বার্ধক্য থেকে। হে রব্ব!আমি আপনার কাছে আশ্রয় চাই জাহান্নামে আযাব হওয়া থেকে এবং কবরে আযাব হওয়া থেকে।",
   "reference_text": "মুসলিম ২৭২৩",
   "media_url": null
  },
  {
   "slug": "dua-ma-05-05",
   "category": "dua-azkar-ma-05",
   "sort": 5,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ৫",
   "summary": "সকালে বলুন",
   "arabic_text": "أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلاَمِ، وَعَلَى كَلِمَةِ الْإِخْلاَصِ، وَعَلَى دِيْنِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ ، وَعَلَى مِلَّةِ أَبِيْنَا إِبْرَاهِيْمَ، حَنِيْفًا مُسْلِمًا وَّمَا كَانَ مِنَ الْمُشْرِكِيْنَ",
   "transliteration": "আসবাহনা ‘আলা ফিত্বরাতিল ইসলামি ওয়া আলা কালিমাতিল ইখলাসি ওয়া আলা দ্বীনি নাবিয়্যিনা মুহাম্মাদিন সাল্লাল্লা-হু আলাইহি ওয়াসাল্লাম ওয়া আলা মিল্লাতি আবীনা ইবরা-হীমা হানীফাম মুসলিমাও ওয়ামা কা-না মিনাল মুশরিকীন",
   "translation": "আমরা সকালে উপনীত হয়েছি ইসলামের ফিত্বরাতের উপর, নিষ্ঠাপূর্ণ বাণী (তাওহীদ) এর উপর, আমাদের নবী মুহাম্মাদ সাল্লাল্লাহু আলাইহি ওয়াসাল্লাম-এর দ্বীনের উপর, আর আমাদের পিতা ইব্রাহীম আলাইহিস সালাম-এর মিল্লাতের উপর—যিনি ছিলেন একনিষ্ঠ মুসলিম এবং যিনি মুশরিকদের অন্তর্ভুক্ত ছিলেন না",
   "reference_text": "আহমাদ ১৫৩৬০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_87.mp3"
  },
  {
   "slug": "dua-ma-05-06",
   "category": "dua-azkar-ma-05",
   "sort": 6,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ৬",
   "summary": "বিকালে বলুন",
   "arabic_text": "أَمْسَيْنَا عَلَى فِطْرَةِ الْإِسْلاَمِ، وَعَلَى كَلِمَةِ الْإِخْلاَصِ، وَعَلَى دِيْنِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ ، وَعَلَى مِلَّةِ أَبِيْنَا إِبْرَاهِيْمَ، حَنِيْفًا مُسْلِمًا وَّمَا كَانَ مِنَ الْمُشْرِكِيْنَ",
   "transliteration": "আমসাইনা ‘আলা ফিত্বরাতিল ইসলামি ওয়া আলা কালিমাতিল ইখলাসি ওয়া আলা দ্বীনি নাবিয়্যিনা মুহাম্মাদিন সাল্লাল্লা-হু আলাইহি ওয়াসাল্লাম ওয়া আলা মিল্লাতি আবীনা ইবরা-হীমা হানীফাম মুসলিমাও ওয়ামা কা-না মিনাল মুশরিকীন",
   "translation": "আমরা বিকালে উপনীত হয়েছি ইসলামের ফিত্বরাতের উপর, নিষ্ঠাপূর্ণ বাণী (তাওহীদ) এর উপর, আমাদের নবী মুহাম্মাদ সাল্লাল্লাহু আলাইহি ওয়াসাল্লাম-এর দ্বীনের উপর, আর আমাদের পিতা ইব্রাহীম আলাইহিস সালাম-এর মিল্লাতের উপর—যিনি ছিলেন একনিষ্ঠ মুসলিম এবং যিনি মুশরিকদের অন্তর্ভুক্ত ছিলেন না",
   "reference_text": "আহমাদ ১৫৩৬০",
   "media_url": null
  },
  {
   "slug": "dua-ma-05-07",
   "category": "dua-azkar-ma-05",
   "sort": 7,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ৭",
   "summary": "সকালে বলুন",
   "arabic_text": "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلّٰهِ رَبِّ الْعَالَمِيْنَ، اللّٰهُـمَّ إِنِّيْ أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ فَتْحَهُ، وَنَصْرَهُ، وَنُوْرَهُ، وَبَرَكَتَهُ، وَهُدَاهُ، وَأَعُوْذُ بِكَ مِنْ شَرِّ مَا فِيْهِ وَشَرِّ مَا بَعْدَهُ",
   "transliteration": "আসবাহ্‌না ওয়া আসবাহাল-মূলকু লিল্লা-হি রব্বিল ‘আলামীন। আল্লা-হুম্মা ইন্নী আস্আলুকা খাইরা হাযাল ইয়াওমি ফাতহাহু ওয়া নাসরাহু ওয়া নুরাহু ওয়া বারাকাতাহু ওয়া হুদা-হু। ওয়া আ‘ঊযু বিকা মিন শাররি মা ফীহি ওয়া শাররি মা বা‘দাহু",
   "translation": "আমরা সকালে উপনীত হয়েছি, অনুরূপ যাবতীয় রাজত্বও সকালে উপনীত হয়েছে সৃষ্টিকুলের রব্ব আল্লাহ্‌র জন্য। হে আল্লাহ! আমি আপনার কাছে কামনা করি এই দিনের কল্যাণ: বিজয়, সাহায্য, নূর, রবকত ও হেদায়াত। আর আমি আপনার কাছে আশ্রয় চাই এ দিনের এবং এ দিনের পরের অকল্যাণ থেকে।",
   "reference_text": "আবু দাউদ ৫০৮৪",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_86.mp3"
  },
  {
   "slug": "dua-ma-05-08",
   "category": "dua-azkar-ma-05",
   "sort": 8,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ৮",
   "summary": "বিকালে বলুন",
   "arabic_text": "أَمْسَيْنَا وَ أَمْسَىا لْمُلْكُ لِلّٰهِ رَبِّ الْعَالَمِيْنَ، اللّٰهُـمَّ إِنِّيْ أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ :فَتْحَهَا، وَنَصْرَهَا، وَنُوْرَهَا، وَبَرَكَتَها، وَهُدَاهَا، وَأَعُوْذُ بِكَ مِنْ شَرِّ مَا فِيْها وَشَرِّ مَا بَعْدَهَا",
   "transliteration": "আমসাইনা ওয়া আমসাল মুলকু লিল্লাহি রাব্বিল ‘আলামীন। আল্লা-হুম্মা ইন্নি আসআলুকা খাইরা হাযিহিল লাইলাতি ফাতহাহা ওয়া নাসরাহা, ওয়া নূরাহা, ওয়া বারাকাতাহা, ওয়া হুদাহা, ওয়া আ‘উযু বিকা মিন শাররি মা ফী-হা, ওয়া শাররি মা বা‘দাহা",
   "translation": "আমরা বিকালে উপনীত হয়েছি, অনুরূপ যাবতীয় রাজত্বও বিকালে উপত হয়েছে সৃষ্টিকুলের রব্ব আল্লাহ্‌র জন্য। হে আল্লাহ, আমি আপনার কাছে কামনা করি এই রাতের কল্যাণ: বিজয়, সাহায্য, নূর, রবকত ও হেদায়াত। আর আমি আপনার কাছে আশ্রয় চাই এ রাতের এবং এ রাতের পরের অকল্যাণ থেকে।",
   "reference_text": "আবু দাউদ ৫০৮৪",
   "media_url": null
  },
  {
   "slug": "dua-ma-05-09",
   "category": "dua-azkar-ma-05",
   "sort": 9,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ৯",
   "summary": "সকালে ৪ বার",
   "arabic_text": "اللّٰهُمَّ إِنّيْ أَصْبَحْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلاَئِكَتِكَ، وَجَمِيْعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللّٰهُ لَا إِلَهَ إِلاَّ أَنْتَ وَحْدَكَ لاَ شَرِيْكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُوْلُكَ",
   "transliteration": "আল্লা-হুম্মা ইন্নী আসবাহ্‌তু উশহিদুকা ওয়া উশহিদু হামালাতা ‘আরশিকা ওয়া মালা-ইকাতিকা ওয়া জামী‘আ খালক্বিকা, আন্নাকা আনতাল্লা-হু লা ইলা-হা ইল্লা আনতা ওয়াহ্‌দাকা লা শারীকা লাকা, ওয়া আন্না মুহাম্মাদান আব্দুকা ওয়া রাসূলুকা",
   "translation": "হে আল্লাহ! আমি সকালে উপনীত হয়েছি। আপনাকে আমি সাক্ষী রাখছি, আরও সাক্ষী রাখছি আপনার ‘আরশ বহনকারীদেরকে, আপনার ফেরেশতাগণকে ও আপনার সকল সৃষ্টিকে, (এর উপর) যে— নিশ্চয় আপনিই আল্লাহ, একমাত্র আপনি ছাড়া আর কোন হক্ব ইলাহ নেই, আপনার কোনো শরীক নেই; আর মুহাম্মাদ সাল্লাল্লাহু আলাইহি ওয়াসাল্লাম আপনার বান্দা ও রাসূল।",
   "reference_text": "আবু দাউদ ৫০৭১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_77.mp3"
  },
  {
   "slug": "dua-ma-05-10",
   "category": "dua-azkar-ma-05",
   "sort": 10,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ১০",
   "summary": "বিকালে ৪ বার",
   "arabic_text": "اللّٰهُمَّ إِنّيْ أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلاَئِكَتِكَ، وَجَمِيْعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللّٰهُ لَا إِلَهَ إِلاَّ أَنْتَ وَحْدَكَ لاَ شَرِيْكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُوْلُكَ",
   "transliteration": "আল্লা-হুম্মা ইন্নী আমসাইতু উশহিদুকা ওয়া উশহিদু হামালাতা ‘আরশিকা ওয়া মালা-ইকাতিকা ওয়া জামী‘আ খালক্বিকা, আন্নাকা আনতাল্লা-হু লা ইলা-হা ইল্লা আনতা ওয়াহ্‌দাকা লা শারীকা লাকা, ওয়া আন্না মুহাম্মাদান আব্দুকা ওয়া রাসূলুকা",
   "translation": "হে আল্লাহ! আমি বিকালে উপনীত হয়েছি। আপনাকে আমি সাক্ষী রাখছি, আরও সাক্ষী রাখছি আপনার ‘আরশ বহনকারীদেরকে, আপনার ফেরেশতাগণকে ও আপনার সকল সৃষ্টিকে, (এর উপর) যে— নিশ্চয় আপনিই আল্লাহ, একমাত্র আপনি ছাড়া আর কোন হক্ব ইলাহ নেই, আপনার কোনো শরীক নেই; আর মুহাম্মাদ সাল্লাল্লাহু আলাইহি ওয়াসাল্লাম আপনার বান্দা ও রাসূল।",
   "reference_text": "আবু দাউদ ৫০৭১",
   "media_url": null
  },
  {
   "slug": "dua-ma-05-11",
   "category": "dua-azkar-ma-05",
   "sort": 11,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ১১",
   "summary": "সকালে বলুন",
   "arabic_text": "اللّٰهُمَّ مَا أَصْبَحَ بِيْ مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لاَ شَرِيْكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ",
   "transliteration": "আল্লা-হুম্মা মা আসবাহা বী মিন নি‘মাতিন আউ বিআহাদিন মিন খালক্বিকা ফামিনকা ওয়াহ্‌দাকা লা শারীকা লাকা, ফালাকাল হাম্‌দু ওয়ালাকাশ্ শুক্‌রু",
   "translation": "হে আল্লাহ! যে নেয়ামত আমার সাথে সকালে উপনীত হয়েছে, অথবা আপনার সৃষ্টির অন্য কারও সাথে; এসব নেয়ামত কেবলমাত্র আপনার নিকট থেকেই; আপনার কোনো শরীক নেই। সুতরাং সকল প্রশংসা আপনারই। আর সকল কৃতজ্ঞতা আপনারই প্রাপ্য।",
   "reference_text": "আবু দাউদ ৫০৭৫",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_78.mp3"
  },
  {
   "slug": "dua-ma-05-12",
   "category": "dua-azkar-ma-05",
   "sort": 12,
   "type": "dua",
   "title_bn": "সকাল-সন্ধ্যার আরও কিছু দোয়া ১২",
   "summary": "বিকালে বলুন",
   "arabic_text": "اللّٰهُمَّ مَا أَمْسَى بِيْ مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لاَ شَرِيْكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ",
   "transliteration": "আল্লা-হুম্মা মা আমসা বী মিন নি‘মাতিন আউ বিআহাদিন মিন খালক্বিকা ফামিনকা ওয়াহ্‌দাকা লা শারীকা লাকা, ফালাকাল হাম্‌দু ওয়ালাকাশ্ শুক্‌রু",
   "translation": "হে আল্লাহ! যে নেয়ামত আমার সাথে বিকালে উপনীত হয়েছে, অথবা আপনার সৃষ্টির অন্য কারও সাথে; এসব নেয়ামত কেবলমাত্র আপনার নিকট থেকেই; আপনার কোনো শরীক নেই। সুতরাং সকল প্রশংসা আপনারই। আর সকল কৃতজ্ঞতা আপনারই প্রাপ্য।",
   "reference_text": "আবু দাউদ ৫০৭৫",
   "media_url": null
  },
  {
   "slug": "dua-ma-06-01",
   "category": "dua-azkar-ma-06",
   "sort": 1,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ১",
   "summary": "সাত বার বলুন",
   "arabic_text": "اَللَّهُمَّ أَجِرْنِيْ مِنَ النَّارِ",
   "transliteration": "আল্লাহুম্মা আজিরনি মিনান নার",
   "translation": "হে আল্লাহ! আমাকে জাহান্নামের আগুন থেকে মুক্তি দিন",
   "reference_text": null,
   "media_url": null
  },
  {
   "slug": "dua-ma-06-02",
   "category": "dua-azkar-ma-06",
   "sort": 2,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ২",
   "summary": "তিন বার বলুন",
   "arabic_text": "رَضِيْتُ بِاللّٰهِ رَبًّا، وَبِالْإِسْلاَمِ دِيْنًا وَّبِمُحَمَّدٍ صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا",
   "transliteration": "রদ্বীতু বিল্লা-হি রব্বান, ওয়াবিল ইসলা-মি দীনান, ওয়াবি মুহাম্মাদিন সাল্লাল্লা-হু ‘আলাইহি ওয়াসাল্লামা নাবিয়্যান",
   "translation": "আল্লাহকে রব, ইসলামকে দীন ও মুহাম্মাদ সাল্লাল্লাহু আলাইহি ওয়াসাল্লাম-কে নবীরূপে গ্রহণ করে আমি সন্তুষ্ট।",
   "reference_text": "আবু দাউদ ৫০৭২",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_84.mp3"
  },
  {
   "slug": "dua-ma-06-03",
   "category": "dua-azkar-ma-06",
   "sort": 3,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ৩",
   "summary": "দশবার বলুন",
   "arabic_text": "اللّٰهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ",
   "transliteration": "আল্লা-হুম্মা সাল্লি ওয়াসাল্লিম ‘আলা নাবিয়্যিনা মুহাম্মাদ",
   "translation": "হে আল্লাহ! আপনি সালাত ও সালাম বর্ষন করুন আমাদের নবী মুহাম্মাদের উপর।",
   "reference_text": "তাবারানি;কাবির, মাজমাউয যাওয়ায়েদ ১০/১২০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_94.mp3"
  },
  {
   "slug": "dua-ma-06-04",
   "category": "dua-azkar-ma-06",
   "sort": 4,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ৪",
   "summary": "তিনবার বলুন",
   "arabic_text": "سُبْحَانَ اللّٰهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ",
   "transliteration": "সুব্‌হা-নাল্লা-হি ওয়া বিহামদিহী ‘আদাদা খালক্বিহী, ওয়া রিদা নাফসিহী, ওয়া যিনাতা ‘আরশিহী, ওয়া মিদা-দা কালিমা-তিহী।",
   "translation": "আমি আল্লাহর প্রশংসাসহ পবিত্রতা ও মহিমা ঘোষণা করছি— তাঁর সৃষ্ট বস্তুসমূহের সংখ্যার সমান, তাঁর নিজের সন্তোষের সমান, তাঁর আরশের ওজনের সমান ও তাঁর বাণীসমূহ লেখার কালি পরিমাণ (অগণিত অসংখ্য)",
   "reference_text": "মুসলিম ২৭২৬",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_90.mp3"
  },
  {
   "slug": "dua-ma-06-05",
   "category": "dua-azkar-ma-06",
   "sort": 5,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ৫",
   "summary": "সকালবেলা তিন বার বলুন",
   "arabic_text": "اللّٰهُمَّ إِنِّيْ أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا",
   "transliteration": "আল্লা-হুম্মা ইন্নি আসআলুকা ইলমান নাফে‘আন ওয়া রিয্‌কান তাইয়্যেবান ওয়া ‘আমালান মুতাক্বাব্বালান",
   "translation": "হে আল্লাহ! আমি আপনার নিকট উপকারী জ্ঞান, পবিত্র রিযিক এবং কবুলযোগ্য আমল (করার তাওফিক) প্রার্থনা করি।",
   "reference_text": "ইবনু মাজাহ ৯২৫",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_91.mp3"
  },
  {
   "slug": "dua-ma-06-06",
   "category": "dua-azkar-ma-06",
   "sort": 6,
   "type": "dua",
   "title_bn": "দুশ্চিন্তা ও ঋণ থেকে মুক্তির জন্য পড়ুন",
   "summary": null,
   "arabic_text": "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ",
   "transliteration": "আল্লা-হুম্মা ইন্নি আ‘ঊযু বিকা মিনাল হাম্মি ওয়াল হাযানি, ওয়াল ‘আজযি ওয়াল কাসালি, ওয়াল বুখলি ওয়াল জুবনি, ওয়া দালা‘ইদ দ্বাইনে ওয়া গালাবাতির রিজা-লি",
   "translation": "হে আল্লাহ! নিশ্চয় আমি আপনার আশ্রয় নিচ্ছি দুশ্চিন্তা ও দুঃখ থেকে, অপারগতা ও অলসতা থেকে, কৃপণতা ও ভীরুতা থেকে, ঋণের ভার ও মানুষদের দমন-পীড়ন থেকে।",
   "reference_text": "বুখারি ২৮৯৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_116.mp3"
  },
  {
   "slug": "dua-ma-06-07",
   "category": "dua-azkar-ma-06",
   "sort": 7,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ৭",
   "summary": "সকাল-বিকেল ১০০ বার বলুন",
   "arabic_text": "سُبْحَانَ اللّٰهِ وَبِحَمْدِهِ",
   "transliteration": "সুবহা-নাল্লা-হি ওয়া বিহামদিহী",
   "translation": "আমি আল্লাহর প্রশংসাসহ পবিত্রতা ও মহিমা ঘোষণা করছি।",
   "reference_text": "মুসলিম ২৬৯২",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_67.mp3"
  },
  {
   "slug": "dua-ma-06-08",
   "category": "dua-azkar-ma-06",
   "sort": 8,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ৮",
   "summary": "প্রতিদিন ১০০ বার বলুন",
   "arabic_text": "أَسْتَغْفِرُ اللّٰهَ وَأَتُوْبُ إِلَيْهِ",
   "transliteration": "আস্তাগফিরুল্লাহ ওয়া আতূবু ইলাইহি",
   "translation": "আমি আল্লাহ্‌র কাছে ক্ষমা প্রার্থনা করছি এবং তাঁর নিকটই তাওবা করছি",
   "reference_text": "বুখারি ৬৩০৭",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_911.mp3"
  },
  {
   "slug": "dua-ma-06-09",
   "category": "dua-azkar-ma-06",
   "sort": 9,
   "type": "dua",
   "title_bn": "ফজিলতপূর্ণ আরও কিছু দোয়া ৯",
   "summary": "দিনে-রাতে ১০০ বার করে পড়ুন",
   "arabic_text": "لاَ إِلَهَ إِلَّا اللَّهُ، وَحْدَهُ لاَ شَرِيْكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيْرٌ",
   "transliteration": "লা ইলা-হা ইল্লাল্লা-হু ওয়াহ্‌দাহূ লা- শারীকালাহূ, লাহুল মুলকু, ওয়ালাহুল হামদু, ওয়াহুয়া ‘আলা কুল্লি শায়ইন ক্বাদীর।",
   "translation": "একমাত্র আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই, তাঁর কোনো শরীক নেই; রাজত্ব তাঁরই, প্রশংসাও তাঁরই; আর তিনি সকল কিছুর ওপর ক্ষমতাবান।",
   "reference_text": "বুখারি ৩২৯৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_89.mp3"
  },
  {
   "slug": "dua-ma-07-01",
   "category": "dua-azkar-ma-07",
   "sort": 1,
   "type": "dua",
   "title_bn": "ঘুমের আগে: প্রাথমিক দোয়া ও আয়াত ১",
   "summary": null,
   "arabic_text": "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا",
   "transliteration": "বিস্‌মিকাল্লা-হুম্মা আমূতু ওয়া আহ্ইয়া",
   "translation": "হে আল্লাহ ! আপনার নাম নিয়েই আমি মরছি (ঘুমাচ্ছি) এবং আপনার নাম নিয়েই জীবিত (জাগ্রত) হবো।",
   "reference_text": "বুখারি ৬৩২৪",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_101.mp3"
  },
  {
   "slug": "dua-ma-07-02",
   "category": "dua-azkar-ma-07",
   "sort": 2,
   "type": "dua",
   "title_bn": "আয়াতুল কুরসি, ১ বার",
   "summary": null,
   "arabic_text": "أَعُوْذُ بِاللّٰهِ مِنَ الشَّيْطَانِ الرَّجِيْمِ\n\nاَللّٰهُ لَآ إِلٰهَ إِلَّا هُوَ ۚ الْحَىُّ الْقَيُّومُ ۚ لَا تَأْخُذُهٗ سِنَةٌ وَّلَا نَوْمٌ ۚ لَهٗ مَا فِى السَّمٰوٰتِ وَمَا فِى الْأَرْضِ ؕ مَنْ ذَا الَّذِى يَشْفَعُ عِندَهٗ إِلَّا بِإِذْنِهٖ ؕ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيْطُوْنَ بِشَىْءٍ مِّنْ عِلْمِهٖۤ إِلَّا بِمَاشَآءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمٰوٰتِ وَالْأَرْضَ ۚ وَلَا يَـُٔوْدُهٗ حِفْظُهُمَا ۚ وَهُوَ الْعَلِىُّ الْعَظِيمُ ﴿۲۵۵﴾",
   "transliteration": null,
   "translation": "বিতাড়িত শয়তান থেকে আমি আল্লাহ্‌র আশ্রয় নিচ্ছি।\nআল্লাহ্, তিনি ছাড়া কোনো সত্য ইলাহ্ নেই। তিনি চিরঞ্জীব, সর্বসত্তার ধারক। তাঁকে তন্দ্রাও স্পর্শ করতে পারে না, নিদ্রাও নয়। আসমানসমূহে যা রয়েছে ও যমীনে যা রয়েছে সবই তাঁর। কে সে, যে তাঁর অনুমতি ব্যতীত তাঁর কাছে সুপারিশ করবে? তাদের সামনে ও পিছনে যা কিছু আছে তা তিনি জানেন। আর যা তিনি ইচ্ছে করেন তা ছাড়া তাঁর জ্ঞানের কোনো কিছুকেই তারা পরিবেষ্টন করতে পারে না। তাঁর ‘কুরসী’ আসমানসমূহ ও যমীনকে পরিব্যাপ্ত করে আছে; আর এ দুটোর রক্ষণাবেক্ষণ তাঁর জন্য বোঝা হয় না। আর তিনি সুউচ্চ সুমহান।",
   "reference_text": "বুখারি ৪/৪৮৭, ২৩১১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_002_255.mp3"
  },
  {
   "slug": "dua-ma-07-03",
   "category": "dua-azkar-ma-07",
   "sort": 3,
   "type": "dua",
   "title_bn": "সূরা বাকারার শেষ দুই আয়াত",
   "summary": null,
   "arabic_text": "بِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nاٰمَنَ الرَّسُوۡلُ بِمَاۤ اُنۡزِلَ اِلَیۡہِ مِنۡ رَّبِّہٖ وَ الۡمُؤۡمِنُوۡنَ ؕ کُلٌّ اٰمَنَ بِاللّٰہِ وَ مَلٰٓئِکَتِہٖ وَ کُتُبِہٖ وَ رُسُلِہٖ ۟ لَا نُفَرِّقُ بَیۡنَ اَحَدٍ مِّنۡ رُّسُلِہٖ ۟ وَ قَالُوۡا سَمِعۡنَا وَ اَطَعۡنَا ٭۫ غُفۡرَانَکَ رَبَّنَا وَ اِلَیۡکَ الۡمَصِیۡرُ ﴿٢٨٥﴾ لَا یُکَلِّفُ اللّٰہُ نَفۡسًا اِلَّا وُسۡعَہَا ؕ لَہَا مَا کَسَبَتۡ وَ عَلَیۡہَا مَا اکۡتَسَبَتۡ ؕ رَبَّنَا لَا تُؤَاخِذۡنَاۤ اِنۡ نَّسِیۡنَاۤ اَوۡ اَخۡطَاۡنَا ۚ رَبَّنَا وَ لَا تَحۡمِلۡ عَلَیۡنَاۤ اِصۡرًا کَمَا حَمَلۡتَہٗ عَلَی الَّذِیۡنَ مِنۡ قَبۡلِنَا ۚ رَبَّنَا وَ لَا تُحَمِّلۡنَا مَا لَا طَاقَۃَ لَنَا بِہٖ ۚ وَ اعۡفُ عَنَّا ٝ وَ اغۡفِرۡ لَنَا ٝ وَ ارۡحَمۡنَا ٝ اَنۡتَ مَوۡلٰىنَا فَانۡصُرۡنَا عَلَی الۡقَوۡمِ الۡکٰفِرِیۡنَ ﴿٢٨٦﴾",
   "transliteration": null,
   "translation": "রসূল বিশ্বাস রাখেন ঐ সমস্ত বিষয় সম্পর্কে যা তাঁর পালনকর্তার পক্ষ থেকে তাঁর কাছে অবতীর্ণ হয়েছে এবং মুসলমানরাও সবাই বিশ্বাস রাখে আল্লাহর প্রতি, তাঁর ফেরেশতাদের প্রতি, তাঁর গ্রন্থসমুহের প্রতি এবং তাঁর পয়গম্বরগণের প্রতি। তারা বলে আমরা তাঁর পয়গম্বরদের মধ্যে কোন তারতম্য করিনা। তারা বলে, আমরা শুনেছি এবং কবুল করেছি। আমরা তোমার ক্ষমা চাই, হে আমাদের পালনকর্তা। তোমারই দিকে প্রত্যাবর্তন করতে হবে। আল্লাহ কাউকে তার সাধ্যাতীত কোন কাজের ভার দেন না, সে তাই পায় যা সে উপার্জন করে এবং তাই তার উপর বর্তায় যা সে করে। হে আমাদের পালনকর্তা, যদি আমরা ভুলে যাই কিংবা ভুল করি, তবে আমাদেরকে অপরাধী করো না। হে আমাদের পালনকর্তা! এবং আমাদের উপর এমন দায়িত্ব অর্পণ করো না, যেমন আমাদের পূর্ববর্তীদের উপর অর্পণ করেছ, হে আমাদের প্রভূ! এবং আমাদের দ্বারা ঐ বোঝা বহন করিও না, যা বহন করার শক্তি আমাদের নাই। আমাদের পাপ মোচন কর। আমাদেরকে ক্ষমা কর এবং আমাদের প্রতি দয়া কর। তুমিই আমাদের প্রভু। সুতরাং কাফের সম্প্রদায়ের বিরুদ্ধে আমাদের কে সাহায্যে কর।",
   "reference_text": "বুখারি ৪০০৮",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_002_285_286.mp3"
  },
  {
   "slug": "dua-ma-07-04",
   "category": "dua-azkar-ma-07",
   "sort": 4,
   "type": "dua",
   "title_bn": "তিনবার বিছানা ঝাড়ার পর বিছানায় শুয়ে দোয়াটি পড়া",
   "summary": null,
   "arabic_text": "بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِيْ، وَبِكَ أَرْفَعُهُ، فَإِن أَمْسَكْتَ نَفْسِي فارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا، بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِيْنَ",
   "transliteration": "বিইসমিকারব্বী ওয়াদা‘তু জাম্বী, ওয়া বিকা আরফা‘উহু। ফাইন্ আম্‌সাক্তা নাফ্‌সী ফারহামহা, ওয়াইন আরসালতাহা ফাহ্‌ফায্‌হা বিমা তাহ্‌ফাযু বিহী ‘ইবা-দাকাস সা-লিহীন।",
   "translation": "আমার রব! আপনার নামে আমি আমার পার্শ্বদেশ রেখেছি (শুয়েছি) এবং আপনারই নাম নিয়ে আমি তা উঠাবো। যদি আপনি (ঘুমন্ত অবস্থায়) আমার প্রাণ আটকে রাখেন, তবে আপনি তাকে দয়া করুন। আর যদি আপনি তা ফেরত পাঠিয়ে দেন, তাহলে আপনি তার হেফাযত করুন যেভাবে আপনি আপনার সৎকর্মশীল বান্দাগণকে হেফাযত করে থাকেন।",
   "reference_text": "আবু দাউদ ৫০৫০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_98.mp3"
  },
  {
   "slug": "dua-ma-08-01",
   "category": "dua-azkar-ma-08",
   "sort": 1,
   "type": "dua",
   "title_bn": "দুই হাত একত্রে মিলিয়ে সূরা ইখলাস, ফালাক, নাস পড়ে তালুতে ফুঁ দিবে…",
   "summary": "দুই হাত একত্রে মিলিয়ে সূরা ইখলাস, ফালাক, নাস পড়ে তালুতে ফুঁ দিবে, তারপর হাত দ্বারা শরীরের যতটুকু সম্ভব মাসেহ করবে। (এভাবে তিনবার করবে )",
   "arabic_text": "بِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nقُلْ ہُوَ اللہُ اَحَدٌ ﴿۱﴾ اَللہُ الصَّمَدُ ﴿۲﴾ لَمْ یَلِدْ ۬ۙ وَ لَمْ یُوۡلَدْ ﴿۳﴾ وَ لَمْ یَكُنۡ لَّہٗ كُفُوًا اَحَدٌ ﴿۴﴾\n\nبِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nقُلْ اَعُوۡذُ بِرَبِّ الْفَلَقِ ﴿۱﴾ مِنۡ شَرِّ مَا خَلَقَ ﴿۲﴾ وَ مِنۡ شَرِّ غَاسِقٍ اِذَا وَقَبَ ﴿۳﴾ وَ مِنۡ شَرِّ النَّفّٰثٰتِ فِی الْعُقَدِ ﴿۴﴾ وَ مِنۡ شَرِّ حَاسِدٍ اِذَا حَسَدَ ﴿۵﴾\n\nبِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nقُلْ اَعُوۡذُ بِرَبِّ النَّاسِ ﴿۱﴾ مَلِکِ النَّاسِ ﴿۲﴾ اِلٰہِ النَّاسِ ﴿۳﴾ مِنۡ شَرِّ الْوَسْوَاسِ ۬ۙ الْخَنَّاسِ ﴿۴﴾ الَّذِیۡ یُوَسْوِسُ فِیۡ صُدُوۡرِ النَّاسِ ﴿۵﴾ مِنَ الْجِنَّۃِ وَ النَّاسِ ﴿۶﴾ \"",
   "transliteration": null,
   "translation": "বলুন, তিনি আল্লাহ্, এক-অদ্বিতীয়। আল্লাহ্ হচ্ছেন ‘সামাদ’ (তিনি কারো মুখাপেক্ষী নন, সকলেই তাঁর মুখাপেক্ষী)। তিনি কাউকেও জন্ম দেন নি এবং তাঁকেও জন্ম দেয়া হয় নি। আর তাঁর সমতুল্য কেউই নেই।\n\nবলুন, আমি আশ্রয় প্রার্থনা করছি ঊষার রবের। তিনি যা সৃষ্টি করেছেন তার অনিষ্ট হতে। ‘আর অনিষ্ট হতে রাতের অন্ধকারের, যখন তা গভীর হয়। আর অনিষ্ট হতে সমস্ত নারীদের, যারা গিরায় ফুঁক দেয়। আর অনিষ্ট হতে হিংসুকের, যখন সে হিংসা করে।\n\nবলুন, আমি আশ্রয় প্রার্থনা করছি মানুষের রবের, মানুষের অধিপতির, মানুষের ইলাহের কাছে, আত্মগোপনকারী কুমন্ত্রণাদাতার অনিষ্ট হতে; যে কুমন্ত্রণা দেয় মানুষের অন্তরে, জিনের মধ্য থেকে এবং মানুষের মধ্য থেকে।",
   "reference_text": "তিরমিযি ৩৪০২",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_3qul.mp3"
  },
  {
   "slug": "dua-ma-09-01",
   "category": "dua-azkar-ma-09",
   "sort": 1,
   "type": "dua",
   "title_bn": "ঘুমের আগে তাসবিহ (৩৩, ৩৩ ও ৩৪ বার)",
   "summary": "যথাক্রমে ৩৩- ৩৩- ৩৪ বার",
   "arabic_text": "سُبْحَانَ اللّٰهِ\nوَالْحَمْدُ لِلَّهِ\nاَللّٰهُ أَكْبَر‎",
   "transliteration": "সুবহা-নাল্লাহ\nআলহামদুলিল্লা-হ\nআল্লা-হু আকবার",
   "translation": "আল্লাহ অতি-পবিত্র\nসকল প্রশংসা আল্লাহর জন্য\nআল্লাহ অতি-মহান",
   "reference_text": "বুখারি ২৯৪৫",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_102.mp3"
  },
  {
   "slug": "dua-ma-09-02",
   "category": "dua-azkar-ma-09",
   "sort": 2,
   "type": "dua",
   "title_bn": "ঘুমের আগে: ফজিলতের আরও দোয়া ২",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ رَبَّ السَّمَوَاتِ السَّبْعِ وَرَبَّ الأَرْضِ، وَرَبَّ الْعَرْشِ الْعَظِيْمِ، رَبَّنَا وَرَبَّ كُلِّ شَيْءٍ، فَالِقَ الْحَبِّ وَالنَّوَى، وَمُنْزِلَ التَّوْرَاةِ وَالْإِنْجِيْلِ، وَالْفُرْقَانِ، أَعُوْذُ بِكَ مِنْ شَرِّ كُلِّ شَيْءٍ أَنْتَ آخِذٌ بِنَاصِيَتِهِ،",
   "transliteration": "আল্লা-হুম্মা রব্বাস্ সামা-ওয়া-তিস্ সাব‘ই ওয়া রব্বাল ‘আরশিল ‘আযীম, রব্বনা ওয়া রব্বা কুল্লি শাই’ইন্, ফা-লিক্বাল হাব্বি ওয়ান-নাওয়া, ওয়া মুনযিলাত্-তাওরা-তি ওয়াল ইনজীলি ওয়াল ফুরক্বা-ন, আ‘ঊযু বিকা মিন শাররি কুল্লি শাই’ইন্ আনতা আ-খিযুম-বিনা-সিয়াতিহি।",
   "translation": "হে আল্লাহ! হে সপ্ত আকাশের রব্ব, যমিনের রব্ব, মহান ‘আরশের রব্ব, আমাদের রব্ব ও প্রত্যেক বস্তুর রব্ব, হে শস্য-বীজ ও আঁটি বিদীর্ণকারী, হে তাওরাত, ইনজীল ও কুরআন নাযিলকারী, আমি প্রত্যেক এমন বস্তুর অনিষ্ট থেকে আপনার নিকট আশ্রয় প্রার্থনা করি, যাকে আপনি নিয়ন্ত্রণ করছেন।",
   "reference_text": "মুসলিম ২৭১৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_103.mp3"
  },
  {
   "slug": "dua-ma-09-03",
   "category": "dua-azkar-ma-09",
   "sort": 3,
   "type": "dua",
   "title_bn": "ঘুমের আগে: ফজিলতের আরও দোয়া ৩",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ أَنْتَ الأَوَّلُ فَلَيْسَ قَبْلَكَ شَيْءٌ، وَأَنْتَ الآخِرُ فَلَيْسَ بَعْدَكَ شَيْءٌ، وَأَنْتَ الظَّاهِرُ فَلَيْسَ فَوْقَكَ شَيْءٌ، وَأَنْتَ الْبَاطِنُ فَلَيْسَ دُوْنَكَ شَيْءٌ، اقْضِ عَنَّا الدَّيْنَ وَأَغْنِنَا مِنَ الْفَقْرِ",
   "transliteration": "আল্লা-হুম্মা আনতাল আউওয়ালু ফালাইসা ক্বাবলাকা শাইউন। ওয়া আনতাল আ-খিরু ফালাইসা বা‘দাকা শাইউন। ওয়া আনতায যা-হিরু ফালাইসা ফাওক্বাকা শাইউন। ওয়া আনতাল বা-ত্বিনু ফালাইসা দূনাকা শাইউন। ইক্বদ্বি ‘আন্নাদ্-দাইনা ওয়া আগনিনা মিনাল ফাক্বরি।",
   "translation": "হে আল্লাহ! আপনিই প্রথম, আপনার পূর্বে কিছুই ছিল না; আপনি সর্বশেষ, আপনার পরে কোনো কিছু থাকবে না; আপনি সব কিছুর উপরে, আপনার উপরে কিছুই নেই; আপনি সর্বনিকটে, আপনার চেয়ে নিকটবর্তী কিছু নেই, আপনি আমাদের সমস্ত ঋণ পরিশোধ করে দিন এবং আমাদেরকে অভাবগ্রস্ততা থেকে অভাবমুক্ত করুন।",
   "reference_text": "মুসলিম ২৭১৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_1032.mp3"
  },
  {
   "slug": "dua-ma-09-04",
   "category": "dua-azkar-ma-09",
   "sort": 4,
   "type": "dua",
   "title_bn": "ঘুমের আগে: ফজিলতের আরও দোয়া ৪",
   "summary": null,
   "arabic_text": "اللَّهُمَّ إِنَّكَ خَلَقْتَ نَفْسِي وَأَنْتَ تَوَفَّاهَا، لَكَ مَمَاتُهَا وَمَحْيَاهَا، إِنْ أَحْيَيْتَهَا فَاحْفَظْهَا، وَإِنْ أَمَتَّهَا فَاغْفِرْ لَهَا، اللَّهُمَّ إِنِّي أَسْأَلُكَ العَافِيَةَ",
   "transliteration": "আল্লা-হুম্মা ইন্নাকা খালাক্তা নাফসী ওয়া আন্তা তাওয়াফ্‌ফাহা। লাকা মামা-তুহা ওয়া মাহ্‌ইয়া-হা। ইন্ আহ্ইয়াইতাহা ফাহ্‌ফায্‌হা ওয়াইন আমাত্তাহা ফাগফির লাহা। আল্লা-হুম্মা ইন্নী আস্আলুকাল ‘আ-ফিয়াতা।",
   "translation": "হে আল্লাহ! নিশ্চয় আপনি আমার আত্মাকে সৃষ্টি করেছেন এবং আপনি তার মৃত্যু ঘটাবেন। তার মৃত্যু ও তার জীবন আপনার মালিকানায়। যদি তাকে বাঁচিয়ে রাখেন তাহলে আপনি তার হেফাযত করুন, আর যদি তার মৃত্যু ঘটান তবে তাকে মাফ করে দিন। হে আল্লাহ! আমি আপনার কাছে নিরাপত্তা চাই।",
   "reference_text": "মুসলিম ২৭১২",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_99.mp3"
  },
  {
   "slug": "dua-ma-09-05",
   "category": "dua-azkar-ma-09",
   "sort": 5,
   "type": "dua",
   "title_bn": "ঘুমের আগে: ফজিলতের আরও দোয়া ৫",
   "summary": null,
   "arabic_text": "اَللّٰهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمٰوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَّمَلِيْكَهُ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ، أَعُوْذُ بِكَ مِنْ شَرِّ نَفْسِيْ، وَمِنْ شَرِّ الشَّيْطَانِ وَ شِرْكِهِ ، وَأَنْ أَقْتَرِفَ عَلٰى نَفْسِيْ سُوْءًا، أَوْ أَجُرَّهُ إِلٰى مُسْلِمٍ،",
   "transliteration": "আল্লা-হুম্মা আ-লিমাল গাইবি ওয়াশ্‌শাহা-দাতি ফা-ত্বিরাস সামা-ওয়া-তি ওয়াল আরদ্বি, রব্বা কুল্লি শাই’ইন ওয়া মালীকাহু, আশহাদু আল-লা ইলা-হা ইল্লা আনতা। আ‘উযু বিকা মিন শাররি নাফ্‌সী ওয়া মিন শাররিশ শাইত্বা-নি ওয়াশারাকিহী ওয়া আন আক্বতারিফা ‘আলা নাফ্‌সী সূওআন আউ আজুররাহূ ইলা মুসলিম",
   "translation": "হে আল্লাহ! হে গায়েব ও উপস্থিতের জ্ঞানী, হে আসমানসমূহ ও যমীনের স্রষ্টা, হে সব কিছুর রব্ব ও মালিক! আমি সাক্ষ্য দিচ্ছি যে, আপনি ছাড়া আর কোনো হক্ব ইলাহ নেই। আমি আপনার কাছে আশ্রয় চাই আমার আত্মার অনিষ্ট থেকে, শয়তানের অনিষ্টতা থেকে ও তার শির্ক বা তার ফাঁদ থেকে, আমার নিজের উপর কোনো অনিষ্ট করা, অথবা কোনো মুসলিমের দিকে তা টেনে নেওয়া থেকে।",
   "reference_text": "তিরমিযি ৩৬২৯",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_82.mp3"
  },
  {
   "slug": "dua-ma-09-06",
   "category": "dua-azkar-ma-09",
   "sort": 6,
   "type": "dua",
   "title_bn": "ঘুমের আগে: ফজিলতের আরও দোয়া ৬",
   "summary": null,
   "arabic_text": "اَلْحَمْدُ لِلّٰهِ الَّذِيْ أَطْعَمَنَا وَسَقَانَا، وَكَفَانَا، وَآوَانَا، فَكَمْ مِمَّنْ لاَ كَافِيَ لَهُ وَلاَ مُؤْوِيَ",
   "transliteration": "আলহামদু লিল্লা-হিল্লাযী আত‘আমানা, ওয়া সাক্বা-না, ওয়া কাফা-না, ওয়া আ-ওয়ানা, ফাকাম্ মিম্মান লা কা-ফিয়া লাহু, ওয়ালা মু’উইয়া",
   "translation": "সকল প্রশংসা আল্লাহ্‌র জন্য, যিনি আমাদেরকে আহার করিয়েছেন, পান করিয়েছেন, আমাদের প্রয়োজন পূর্ণ করেছেন এবং আমাদেরকে আশ্রয় দিয়েছেন। কেননা, এমন বহু লোক আছে যাদের প্রয়োজনপূর্ণকারী কেউ নেই এবং যাদের আশ্রয়দানকারীও কেউ নেই।",
   "reference_text": null,
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_104.mp3"
  },
  {
   "slug": "dua-ma-09-07",
   "category": "dua-azkar-ma-09",
   "sort": 7,
   "type": "dua",
   "title_bn": "ডান কাতে শোয়ার পর বলা",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ قِنِيْ عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ",
   "transliteration": "আল্লা-হুম্মা ক্বিনী ‘আযা-বাকা ইয়াওমা তাব‘আছু ‘ইবা-দাকা",
   "translation": "হে আল্লাহ! আমাকে আপনার আযাব থেকে রক্ষা করুন, যেদিন আপনি আপনার বান্দাদেরকে পুনর্জীবিত করবেন।",
   "reference_text": "তিরমিযি ৩৩৯৮",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_100.mp3"
  },
  {
   "slug": "dua-ma-09-08",
   "category": "dua-azkar-ma-09",
   "sort": 8,
   "type": "dua",
   "title_bn": "ওযু করে ডান কাতে শুয়ে এরপর পড়া",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ أَسْلَمْتُ نَفْسِيْ إِلَيْكَ، وَفَوَّضْتُ أَمْرِيْ إِلَيْكَ، وَوَجَّهْتُ وَجْهِيْ إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِيْ إِلَيْكَ، رَغْبَةً وَّرَهْبَةً إِلَيْكَ، لاَ مَلْجَأَ وَلاَ مَنْجَا مِنْكَ إِلاَّ إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِيْ أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِيْ أَرْسَلْتَ",
   "transliteration": "আল্লা-হুম্মা আস্‌লামতু নাফ্‌সী ইলাইকা, ওয়া ফাউওয়াদ্বতু আমরী ইলাইকা, ওয়া ওয়াজ্জাহ্‌তু ওয়াজহিয়া ইলাইকা, ওয়াআলজা’তু যাহ্‌রী ইলাইকা, রাগবাতান ওয়া রাহবাতান ইলাইকা। লা মালজা’আ ওয়ালা মান্‌জা মিনকা ইল্লা ইলাইকা। আ-মানতু বিকিতা-বিকাল্লাযী আনযালতা ওয়াবিনাবিয়্যিকাল্লাযী আরসালতা",
   "translation": "হে আল্লাহ! আমি নিজেকে আপনার কাছে সঁপে দিলাম। আমার যাবতীয় বিষয় আপনার কাছেই সোপর্দ করলাম, আমার চেহারা আপনার দিকেই ফিরালাম, আর আমার পৃষ্ঠদেশকে আপনার দিকেই ন্যস্ত করলাম; আপনার প্রতি অনুরাগী হয়ে এবং আপনার ভয়ে ভীত হয়ে। একমাত্র আপনার নিকট ছাড়া আপনার (পাকড়াও) থেকে বাঁচার কোনো আশ্রয়স্থল নেই এবং কোনো মুক্তির উপায় নেই। আমি ঈমান এনেছি আপনার নাযিলকৃত কিতাবের উপর এবং আপনার প্রেরিত নবীর উপর।",
   "reference_text": "বুখারি ৬৩১৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_107.mp3"
  },
  {
   "slug": "dua-ma-09-09",
   "category": "dua-azkar-ma-09",
   "sort": 9,
   "type": "dua",
   "title_bn": "সূরা মুলক (সূরা#৬৭) তিলাওয়াত করা।",
   "summary": "সূরা মুলক (সূরা#৬৭) তিলাওয়াত করা।\nএছাড়া সূরা সাজদা (সূরা#৩২) এবং সুরা যুমার (সূরা#৩৯) পড়াও সুন্নাত।",
   "arabic_text": null,
   "transliteration": null,
   "translation": null,
   "reference_text": "তিরমিযি ২৮৯২, ৩৪০৪",
   "media_url": null
  },
  {
   "slug": "dua-ma-10-01",
   "category": "dua-azkar-ma-10",
   "sort": 1,
   "type": "dua",
   "title_bn": "পার্শ্ব পরিবর্তন করার সময়",
   "summary": null,
   "arabic_text": "لاَ إِلَهَ إِلاَّ اللّٰهُ الْوَاحِدُ الْقَهّارُ، رَبُّ السَّمَوَاتِ وَالْأَرْضِ وَمَا بَيْنَهُمَا الْعَزِيْزُ الْغَفَّارُ",
   "transliteration": "লা ইলা-হা ইল্লাল্লা-হুল ওয়াহিদুল কাহ্‌হারু রব্বুস্ সামা-ওয়া-তি ওয়াল-আরদ্বি ওয়ামা বাইনাহুমাল-‘আযীযুল গাফ্‌ফার",
   "translation": "মহাপ্রতাপশালী এক আল্লাহ ছাড়া আর কোনো হক্ব ইলাহ নেই। (তিনি) আসমানসমূহ, যমীন এবং এ দু’য়ের মধ্যস্থিত সবকিছুর রব্ব, প্রবলপরাক্রমশালী, পরম ক্ষমাশীল।",
   "reference_text": "হাকিম ১/৫৪০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_108.mp3"
  },
  {
   "slug": "dua-ma-10-02",
   "category": "dua-azkar-ma-10",
   "sort": 2,
   "type": "dua",
   "title_bn": "ঘুমের সময় ভয় পেলে এবং যেকোন সময়ে অস্বস্তি লাগলে",
   "summary": null,
   "arabic_text": "أَعُوْذُ بِكَلِمَاتِ اللّٰهِ التَّامَّةِ، مِنْ غَضَبِهٖ وَعِقَابِهٖ وَشَرِّ عِبَادِهٖ وَمِنْ هَمَزَاتِ الشَّيَاطِيْنِ وَأَنْ يَّحْضُرُوْنِ",
   "transliteration": "আ‘ঊযু বিকালিমা-তিল্লাহিত্তা-ম্মাতি মিন গাদাবিহি ওয়া ইকা-বিহি ওয়া শাররি ‘ইবা-দিহি ওয়ামিন হামাযা-তিশ শায়া-তিনি ওয়া আই-ইয়াহদুরূন।",
   "translation": "আমি আল্লাহর পরিপূর্ণ কালামসমূহের দ্বারা আশ্রয় চাই তাঁর ক্রোধ থেকে, তাঁর শাস্তি থেকে এবং তাঁর বান্দাদের অনিষ্ট থেকে, আর শয়তানদের কুমন্ত্রণা থেকে এবং তাদের উপস্থিতি থেকে।",
   "reference_text": "আবু দাউদ ৩৮৯৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_109.mp3"
  },
  {
   "slug": "dua-ma-10-03",
   "category": "dua-azkar-ma-10",
   "sort": 3,
   "type": "dua",
   "title_bn": "খারাপ স্বপ্ন দেখলে করণীয়",
   "summary": "খারাপ স্বপ্ন দেখলে করণীয়\n১. তিনবার তার বাম দিকে হাল্কা থুতু ফেলা। ২. তিনবার শয়তান থেকে এবং স্বপ্নে যা দেখেছে তার অনিষ্ট থেকে আল্লাহর কাছে আশ্রয় চাওয়া। ৩. কাউকে এ ব্যাপারে কিছু না বলা। ৪. অতঃপর যে পার্শ্বে সে ঘুমিয়েছিল তা পরিবর্তন করা।\n৫. যদি সম্ভব হয় তবে উঠে কিছু (নফল) সালাত আদায় করা।",
   "arabic_text": null,
   "transliteration": null,
   "translation": null,
   "reference_text": "মুসলিম ২২৬১-২২৬৩",
   "media_url": null
  },
  {
   "slug": "dua-ma-11-01",
   "category": "dua-azkar-ma-11",
   "sort": 1,
   "type": "dua",
   "title_bn": "ঘুম থেকে জাগ্রত হয়ে পড়া",
   "summary": null,
   "arabic_text": "الْحَمْدُ لِلَّهِ الَّذِيْ أَحْيَانَا بَعْدَ مَا أَمَاتَنَا، وَإِلَيْهِ النُّشُوْرُ",
   "transliteration": "আলহামদু লিল্লা-হিল্লাযী আহ্ইয়া-না- বা‘দা মা- আমা-তানা- ওয়া ইলাইহিন্ নুশূর",
   "translation": "হামদ-প্রশংসা আল্লাহ্‌র জন্য, যিনি (নিদ্রারূপ) মৃত্যুর পর আমাদেরকে জীবিত করলেন, আর তাঁরই নিকট সকলের পুনরুত্থান",
   "reference_text": "বুখারি ৬৩১৪",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_1.mp3"
  },
  {
   "slug": "dua-ma-11-02",
   "category": "dua-azkar-ma-11",
   "sort": 2,
   "type": "dua",
   "title_bn": "জাগ্রত হয়ে এই দোয়া পড়া (এরপর প্রয়োজনের কিছু প্রার্থনা করা যায়)",
   "summary": null,
   "arabic_text": "لاَ إِلَهَ إِلاَّ اللّٰهُ وَحْدَهُ لاَ شَرِيْكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيْرٌ، سُبْحَانَ اللّٰهِ، وَالْحَمْدُ لِلّٰهِ، وَلاَ إِلَهَ إِلاَّ اللّٰهُ، وَاللّٰهُ أَكْبَرُ، وَلاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللّٰهِ الْعَلِيِّ الْعَظِيْمِ، رَبِّ اغْفِرْ لِيْ",
   "transliteration": "লা ইলা-হা ইল্লাল্লা-হু ওয়াহ্‌দাহূ লা- শারীকালাহূ, লাহুল মুলকু, ওয়ালাহুল হামদু, ওয়াহুয়া ‘আলা কুল্লি শায়ইন ক্বাদীর। সুবহা-নাল্লাহি, ওয়ালহামদু লিল্লাহি, ওয়া লা ইলা-হা ইল্লাল্লা-হু, ওয়াল্লা-হু আকবার, ওয়া লা- হাওলা ওয়ালা- কুওয়াতা ইল্লা- বিল্লা-হিল ‘আলিয়্যিল ‘আযীম, রাব্বিগফির লী",
   "translation": "একমাত্র আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই, তাঁর কোনো শরীক নেই; রাজত্ব তাঁরই, প্রশংসাও তাঁরই; আর তিনি সকল কিছুর ওপর ক্ষমতাবান। আল্লাহ পবিত্র-মহান। সকল হামদ-প্রশংসা আল্লাহ্‌র। আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই। আল্লাহ সবচেয়ে বড়। সুউচ্চ সুমহান আল্লাহর সাহায্য ছাড়া (পাপ কাজ থেকে দূরে থাকার) কোনো উপায় এবং (সৎকাজ করার) কোনো শক্তি কারো নেই। হে রব্ব ! আমাকে ক্ষমা করুন",
   "reference_text": "বুখারি ১১৫৪",
   "media_url": null
  },
  {
   "slug": "dua-ma-11-03",
   "category": "dua-azkar-ma-11",
   "sort": 3,
   "type": "dua",
   "title_bn": "ঘুম থেকে জাগ্রত হয়ে",
   "summary": null,
   "arabic_text": "اَلْحَمْدُ لِلّٰهِ الَّذِيْ عَافَانِيْ فِيْ جَسَدِي، وَرَدَّ عَلَيَّ رُوْحِي، وَأَذِنَ لِيْ بِذِكْرِهِ",
   "transliteration": "আল্‌হামদু লিল্লা-হিল্লাযী ‘আ-ফা-নী ফী জাসাদী, ওয়ারদ্দা ‘আলাইয়্যা রূহী ওয়া আযিনা লী বিযিকরিহী",
   "translation": "সকল হামদ-প্রশংসা আল্লাহ্‌র জন্য, যিনি আমার দেহকে নিরাপদ করেছেন, আমার রূহকে আমার নিকট ফেরত দিয়েছেন এবং আমাকে তাঁর যিক্‌র করার অনুমতি (সুযোগ) দিয়েছেন",
   "reference_text": "তিরমিযি ৩৪০১",
   "media_url": null
  },
  {
   "slug": "dua-ma-12-01",
   "category": "dua-azkar-ma-12",
   "sort": 1,
   "type": "dua",
   "title_bn": "সূরা আলে ইমরান: ১৯০ থেকে ২০০ আয়াত",
   "summary": null,
   "arabic_text": "اِنَّ فِیۡ خَلْقِ السَّمٰوٰتِ وَالۡاَرْضِ وَاخْتِلَافِ الَّیۡلِ وَالنَّہَارِ لَاٰیٰتٍ لِّاُولِی الۡاَلْبَابِ ﴿۱۹۰﴾ الَّذِیۡنَ یَذْكُرُوۡنَ اللہَ قِیٰمًا وَّقُعُوۡدًا وَّعَلٰی جُنُوۡبِہِمْ وَیَتَفَکَّرُوۡنَ فِیۡ خَلْقِ السَّمٰوٰتِ وَالۡاَرْضِ ۚ رَبَّنَا مَا خَلَقْتَ ہٰذَا بَاطِلًا ۚ سُبْحٰنَکَ فَقِنَا عَذَابَ النَّارِ ﴿۱۹۱﴾ رَبَّنَاۤ اِنَّکَ مَنۡ تُدْخِلِ النَّارَ فَقَدْ اَخْزَیۡتَہٗ ؕ وَمَا لِلظّٰلِمِیۡنَ مِنْ اَنۡصَارٍ ﴿۱۹۲﴾ رَبَّنَاۤ اِنَّنَا سَمِعْنَا مُنَادِیًا یُّنَادِیۡ لِلۡاِیۡمَانِ اَنْ اٰمِنُوۡا بِرَبِّكُمْ فَاٰمَنَّا ٭ۖ رَبَّنَا فَاغْفِرْلَنَا ذُنُوۡبَنَا وَکَفِّرْعَنَّا سَیِّاٰتِنَا وَتَوَفَّنَا مَعَ الۡاَبْرَارِ ﴿۱۹۳﴾ رَبَّنَا وَاٰتِنَا مَا وَعَدۡتَّنَا عَلٰی رُسُلِکَ وَلَا تُخْزِنَا یَوْمَ الْقِیٰمَۃِ ؕ اِنَّکَ لَا تُخْلِفُ الْمِیۡعَادَ ﴿۱۹۴﴾ فَاسْتَجَابَ لَہُمْ رَبُّہُمْ اَنِّیۡ لَاۤ اُضِیۡعُ عَمَلَ عَامِلٍ مِّنۡكُمۡ مِّنۡ ذَکَرٍ اَوْ اُنۡثٰی ۚ بَعْضُكُمۡ مِّنۡۢ بَعْضٍ ۚ فَالَّذِیۡنَ ہَاجَرُوۡا وَاُخْرِجُوۡا مِنۡ دِیَارِہِمْ وَاُوۡذُوۡا فِیۡ سَبِیۡلِیۡ وَقٰتَلُوۡا وَقُتِلُوۡا لَاُکَفِّرَنَّ عَنْہُمْ سَیِّاٰتِہِمْ وَلَاُدْخِلَنَّہُمْ جَنّٰتٍ تَجْرِیۡ مِنۡ تَحْتِہَا الۡاَنْہٰرُ ۚ ثَوَابًا مِّنۡ عِنۡدِ اللہِ ؕ وَاللہُ عِنۡدَہٗ حُسْنُ الثَّوَابِ ﴿۱۹۵﴾ لَا یَغُرَّنَّکَ تَقَلُّبُ الَّذِیۡنَ کَفَرُوۡا فِی الْبِلَادِ ﴿۱۹۶﴾ مَتَاعٌ قَلِیۡلٌ ۟ ثُمَّ مَاۡوٰىہُمْ جَہَنَّمُ ؕ وَبِئْسَ الْمِہَادُ ﴿۱۹۷﴾ لٰکِنِ الَّذِیۡنَ اتَّقَوْا رَبَّہُمْ لَہُمْ جَنّٰتٌ تَجْرِیۡ مِنۡ تَحْتِہَا الۡاَنْہٰرُ خٰلِدِیۡنَ فِیۡہَا نُزُلًا مِّنْ عِنۡدِ اللہِ ؕ وَمَا عِنۡدَ اللہِ خَیۡرٌ لِّلۡاَبْرَارِ ﴿۱۹۸﴾ وَ اِنَّ مِنْ اَہۡلِ الْکِتٰبِ لَمَنۡ یُّؤْمِنُ بِاللہِ وَمَاۤ اُنۡزِلَ اِلَیۡكُمْ وَمَاۤ اُنۡزِلَ اِلَیۡہِمْ خٰشِعِیۡنَ لِلہِ ۙ لَا یَشْتَرُوۡنَ بِاٰیٰتِ اللہِ ثَمَنًا قَلِیۡلًا ؕ اُولٰٓئِکَ لَہُمْ اَجْرُہُمْ عِنۡدَ رَبِّہِمْ ؕ اِنَّ اللہَ سَرِیۡعُ الْحِسَابِ ﴿۱۹۹﴾ یٰۤاَیُّہَا الَّذِیۡنَ اٰمَنُوا اصْبِرُوۡا وَصَابِرُوۡا وَرَابِطُوۡا ۟ وَاتَّقُوا اللہَ لَعَلَّكُمْ تُفْلِحُوۡنَ ﴿۲۰۰﴾",
   "transliteration": null,
   "translation": "নিশ্চয় আসমানসমূহ ও যমীনের সৃষ্টিতে, রাত ও দিনের পরিবর্তনে নিদর্শনাবলী রয়েছে বোধশক্তি সম্পন্ন লোকদের জন্য।\nযারা দাঁড়িয়ে, বসে ও শুয়ে আল্লাহ্‌র স্মরণ করে এবং আসমানসমূহ ও যমীনের সৃষ্টি সম্বন্ধে চিন্তা করে, আর বলে, ‘হে আমাদের রব! আপনি এগুলো অনর্থক সৃষ্টি করেননি, আপনি অত্যন্ত পবিত্র, অতএব আপনি আমাদেরকে আগুনের শাস্তি হতে রক্ষা করুন।\nহে আমাদের রব! আপনি কাউকেও আগুনে নিক্ষেপ করলে তাকে তো আপনি নিশ্চয়ই হেয় করলেন এবং যালেমদের কোন সাহায্যকারী নেই।\nহে আমাদের রব, আমরা এক আহ্বায়ককে ঈমানের দিকে আহ্বান করতে শুনেছি, ‘তোমরা তোমাদের রবের উপর ঈমান আন।’ কাজেই আমরা ঈমান এনেছি। হে আমাদের রব! আপনি আমাদের পাপরাশি ক্ষমা করুন, আমাদের মন্দ কাজগুলো দূরীভূত করুন এবং আমাদেরকে সৎকর্মপরায়ণদের সহগামী করে মৃত্যু দিন।\nহে আমাদের রব! আপনার রাসূলগণের মাধ্যমে আমাদেরকে যা দিতে প্রতিশ্রুতি দিয়েছেন তা আমাদেরকে দান করুন এবং কেয়ামতের দিন আমাদেরকে হেয় করবেন না। নিশ্চয় আপনি প্রতিশ্রুতির ব্যতিক্রম করেন না।\nতারপর তাদের রব তাদের ডাকে সাড়া দিয়ে বলেন, ‘নিশ্চয় আমি তোমাদের মধ্যে আমলকারী কোনো নর বা নারীর আমল বিফল করি না; তোমরা একে অপরের অংশ। কাজেই যারা হিজরত করেছে, নিজ ঘর থেকে উৎখাত হয়েছে, আমার পথে নির্যাতিত হয়েছে এবং যুদ্ধ করেছে ও নিহত হয়েছে আমি তাদের পাপ কাজগুলো অবশ্যই দূর করব এবং অবশ্যই তাদেরকে প্রবেশ করাব জান্নাতে, যার পাদদেশে নদী প্রবাহিত। এটা আল্লাহ্‌র কাছ থেকে পুরস্কার; আর উত্তম পুরস্কার আল্লাহ্‌রই কাছে রয়েছে।\nযারা কুফরী করেছে, দেশে দেশে তাদের অবাধ বিচরণ যেন কিছুতেই আপনাকে বিভ্রান্ত না করে।\nএ তো স্বল্পকালীন ভোগ মাত্র; তারপর জাহান্নাম তাদের আবাস; আর ওটা কত নিকৃষ্ট বিশ্রামস্থল!\n\nকিন্তু যারা তাদের রবকে ভয় করে তাদের জন্য রয়েছে জান্নাত, যার পাদদেশে নদী প্রবাহিত, সেখানে তারা স্থায়ী হবে। এ হচ্ছে আল্লাহ্‌র পক্ষ থেকে আতিথেয়তা; আর আল্লাহ্‌র কাছে যা আছে তা সৎকর্মপরায়ণদের জন্য উত্তম।\nআর নিশ্চয় কিতাবীদের মধ্যে এমন লোকও আছে যারা আল্লাহ্‌র প্রতি বিনয়াবনত হয়ে তাঁর প্রতি এবং তিনি যা তোমাদের ও তাদের প্রতি নাযিল করেছেন তাতে ঈমান আনে। তারা আল্লাহ্‌র আয়াত তুচ্ছ মূল্যে বিক্রি করে না। তারাই, যাদের জন্য আল্লাহ্‌র কাছে পুরস্কার রয়েছে। নিশ্চয়ই আল্লাহ্ দ্রুত হিসাব গ্রহণকারী।\nহে ঈমানদারগণ! তোমরা ধৈর্য ধারণ কর, ধৈর্যে প্রতিযোগিতা কর এবং সবসময় যুদ্ধের জন্য প্রস্তুত থাক, আর আল্লাহ্‌র তাকওয়া অবলম্বন কর; যাতে তোমরা সফলকাম হতে পার।",
   "reference_text": null,
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_21.mp3"
  },
  {
   "slug": "dua-ma-13-01",
   "category": "dua-azkar-ma-13",
   "sort": 1,
   "type": "dua",
   "title_bn": "সব কাজে বিসমিল্লাহ বলা",
   "summary": "সব কাজে বিসমিল্লাহ বলা\nবিশেষতঃ ১. বিসমিল্লাহ বলে ঘর-বাড়িতে প্রবেশ করা। ২. বিসমিল্লাহ বলে দরজা-জানালা বন্ধ করা। ৩. খাওয়ার পূর্বে বিসমিল্লাহ বলা।",
   "arabic_text": null,
   "transliteration": null,
   "translation": null,
   "reference_text": "বুখারি ৩১০৬",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_12.mp3"
  },
  {
   "slug": "dua-ma-13-02",
   "category": "dua-azkar-ma-13",
   "sort": 2,
   "type": "dua",
   "title_bn": "বাড়ি থেকে বের হওয়ার সময় পড়া",
   "summary": null,
   "arabic_text": "بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
   "transliteration": "বিসমিল্লাহি তাওয়াক্কালতু ‘আলাল্লাহি লা-হাওলা ওয়ালা-কুওওয়াতা ইল্লা-বিল্লা-হ।",
   "translation": "আল্লাহ তাআলার নামে। আমি আল্লাহ তাআলার ওপরই ভরসা করলাম। আল্লাহর ব্যতীত কারও সাধ্য বা শক্তি নেই।",
   "reference_text": "তিরমিযি ২৪২৬",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_16.mp3"
  },
  {
   "slug": "dua-ma-13-03",
   "category": "dua-azkar-ma-13",
   "sort": 3,
   "type": "dua",
   "title_bn": "নতুন কোথাও গেলে অথবা গা ছামছমে জায়গায় হাঁটলে পড়া",
   "summary": null,
   "arabic_text": "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ",
   "transliteration": "আ‘ঊযু বিকালিমা-তিল্লা-হিত তা-ম্মাতি মিন শাররি মা খালাক্ব।",
   "translation": "আল্লাহ্‌র পরিপূর্ণ কালেমাসমূহের ওসিলায় আমি তাঁর নিকট তাঁর সৃষ্টির ক্ষতি থেকে আশ্রয় চাই।",
   "reference_text": "মুসলিম ৪৮৮৮",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_93.mp3"
  },
  {
   "slug": "dua-ma-13-04",
   "category": "dua-azkar-ma-13",
   "sort": 4,
   "type": "dua",
   "title_bn": "দৈনিক একবার হলেও মসজিদে প্রবেশের দোয়া পড়া",
   "summary": null,
   "arabic_text": "أَعُوذُ بِاللَّهِ العَظِيمِ، وَبِوَجْهِهِ الْكَرِيمِ، وَسُلْطَانِهِ الْقَدِيمِ، مِنَ الشَّيْطَانِ الرَّجِيمِ",
   "transliteration": "আ‘ঊযু বিল্লা-হিল ‘আযীম, ওয়া বিওয়াজহিহিল কারীম, ওয়াসুলতা-নিহিল ক্বদীম, মিনাশ শাইত্বা-নির রাজীম।",
   "translation": "আমি মহান আল্লাহ্‌র কাছে তাঁর সম্মানিত চেহারা ও প্রাচীন ক্ষমতার ওসীলায় বিতাড়িত শয়তান থেকে আশ্রয় প্রার্থনা করছি।",
   "reference_text": "আবু দাউদ ৩৯৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_20.mp3"
  },
  {
   "slug": "dua-ma-13-05",
   "category": "dua-azkar-ma-13",
   "sort": 5,
   "type": "dua",
   "title_bn": "মসজিদে প্রবেশের অন্যান্য দোয়া",
   "summary": null,
   "arabic_text": "بِسْمِ اللَّهِ\nوَالصَّلَاةُ وَالسَّلَامُ عَلَى رَسُولِ اللَّهِ\nاللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ",
   "transliteration": "বিসমিল্লা-হি\nওয়াসসালাতু ওয়াসসালা-মু ‘আলা রাসূলিল্লা-হি\nআল্লা-হুম্মাফ্‌তাহ লী আবওয়া-বা রাহ্‌মাতিকা",
   "translation": "আল্লাহ্‌র নামে (প্রবেশ করছি)\nসালাত ও সালাম আল্লাহ্‌র রাসূলের উপর।\nহে আল্লাহ! আপনি আমার জন্য আপনার রহমতের দরজাসমূহ খুলে দিন।",
   "reference_text": "আবু দাউদ ৪৬৫, মুসলিম ৭১৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_20.mp3"
  },
  {
   "slug": "dua-ma-13-06",
   "category": "dua-azkar-ma-13",
   "sort": 6,
   "type": "dua",
   "title_bn": "টয়লেটে প্রবেশের পূর্বে পড়া",
   "summary": null,
   "arabic_text": "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبْثِ وَالْخَبَائِثِ",
   "transliteration": "আল্লা-হুম্মা ইন্নী আ‘ঊযু বিকা মিনাল খুব্‌সি ওয়াল খাবা-ইসি",
   "translation": "হে আল্লাহ! আমি আপনার নিকট অপবিত্র নর জিন্ ও নারী জিন্ থেকে আশ্রয় চাই",
   "reference_text": "তিরমিযি ৫",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_10.mp3"
  },
  {
   "slug": "dua-ma-13-07",
   "category": "dua-azkar-ma-13",
   "sort": 7,
   "type": "dua",
   "title_bn": "হঠাৎ অস্বস্তি লাগলে বা অস্বাভাবিক অনুভূতি হলে",
   "summary": null,
   "arabic_text": "أَعُوذُ بِكَلِمَاتِ الله التَّامَّاتِ مِنْ غَضَبِهِ وَعِقَابِهِ وشَرّ عِبَادِهِ ، ومِنْ هَمَزَاتِ الشّيَاطِينِ وأَنْ يَحْضُرُونِ",
   "transliteration": "আ‘ঊযু বিকালিমা-তিল্লা-হিত্তা-ম্মাতি মিন গাদাবিহি ওয়া ইকা-বিহি ওয়া শাররি ‘ইবা-দিহি ওয়ামিন হামাযা-তিশ শায়া-তিনি ওয়া আই-ইয়াহদুরূন।",
   "translation": "আমি আল্লাহর পরিপূর্ণ কালামসমূহের দ্বারা আশ্রয় চাই তাঁর ক্রোধ থেকে, তাঁর শাস্তি থেকে এবং তাঁর বান্দাদের অনিষ্ট থেকে, আর শয়তানদের কুমন্ত্রণা থেকে এবং তাদের উপস্থিতি থেকে।",
   "reference_text": "মুয়াত্তা মালেক ১৭৪১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_109.mp3"
  },
  {
   "slug": "dua-ma-13-08",
   "category": "dua-azkar-ma-13",
   "sort": 8,
   "type": "dua",
   "title_bn": "স্ত্রী সহবাসের পূর্বে দোয়া পড়া",
   "summary": null,
   "arabic_text": "بِسْمِ اللَّهِ، اللَّهُمَّ جَنِّبْنَا الشَّيْطَانَ، وَجَنِّبِ الشَّيْطَانَ مَا رَزَقْتَنَا",
   "transliteration": "বিসমিল্লাহি আল্লা-হুম্মা জান্নিবনাশ্-শাইত্বানা ওয়া জান্নিবিশ্-শাইত্বানা মা রযাকতানা",
   "translation": "আল্লাহ্‌র নামে। হে আল্লাহ! আপনি আমাদের থেকে শয়তানকে দূরে রাখুন এবং আমাদেরকে আপনি যে সন্তান দান করবেন তার থেকেও শয়তানকে দূরে রাখুন।",
   "reference_text": "বুখারি ৪৮৭০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_186.mp3"
  },
  {
   "slug": "dua-ma-13-09",
   "category": "dua-azkar-ma-13",
   "sort": 9,
   "type": "dua",
   "title_bn": "বিয়ের প্রথম রাতে স্ত্রীর মাথায় হাত রেখে পড়া এরপর বরকতের জন্য দোয়া…",
   "summary": "বিয়ের প্রথম রাতে স্ত্রীর মাথায় হাত রেখে পড়া এরপর বরকতের জন্য দোয়া করা",
   "arabic_text": "اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَهَا وَخَيْرَ مَا جَبَلْتَهَا عَلَيْهِ ، وَأَعُوذُ بِكَ مِنْ شَرِّهَا وَشَرِّ مَا جَبَلْتَهَا عَلَيْهِ",
   "transliteration": "আল্লা-হুম্মা ইন্নি আসআলুকা খাইরাহা ওয়া খাইরা মা জাবালতাহা ‘আলাইহি, ওয়া আ‘ঊযু বিকা মিন শাররিহা ওয়া শাররি মা জাবালতাহা ‘আলাইহি",
   "translation": "হে আল্লাহ, আমি এর যত কল্যাণ রয়েছে এবং যত কল্যাণ তার স্বভাবে আপনি দিয়েছেন তা চাই। আর এর যত অকল্যাণ রয়েছে এবং যত অকল্যাণ ওর স্বভাব-চরিত্রে আপনি রেখেছেন তা থেকে আপনার আশ্রয় চাই।",
   "reference_text": "আবু দাউদ ২১৬০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_185.mp3"
  },
  {
   "slug": "dua-ma-13-10",
   "category": "dua-azkar-ma-13",
   "sort": 10,
   "type": "dua",
   "title_bn": "সবসময় বেশি বেশি ইস্তিগফার করা (দিনে অন্তত ১০০বার)",
   "summary": null,
   "arabic_text": "أَسْتَغْفِرُ اللّٰهَ الْعَظيْمَ الَّذِيْ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ القَيُّوْمُ وَأَتُوْبُ إِلَيْهِ\nসংক্ষেপে\nأَسْتَغْفِرُ اللّٰهَ وَأَتُوْبُ إِلَيْهِ",
   "transliteration": "আস্তাগফিরুল্লা-হাল ‘আযীমল্লাযী লা ইলা-হা ইল্লা হুয়াল হাইয়্যুল কায়্যূমু ওয়া আতূবু ইলাইহি\n(অথবা সংক্ষেপে)\nআস্তাগফিরুল্লা-হা ওয়া আতূবু ইলাইহি",
   "translation": "আমি মহামহিম আল্লাহ্‌র নিকট ক্ষমা চাই, যিনি ছাড়া আর কোনো হক্ব ইলাহ নেই, তিনি চিরস্থায়ী, সর্বসত্তার ধারক। আর আমি তাঁরই নিকট তওবা করছি।’\n(সংক্ষেপে) আমি আল্লাহ্‌র নিকট ক্ষমা চাই এবং তাঁরই নিকট তওবা করছি।",
   "reference_text": "বুখারি ৬৩০৭",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_911.mp3"
  },
  {
   "slug": "dua-ma-14-01",
   "category": "dua-azkar-ma-14",
   "sort": 1,
   "type": "dua",
   "title_bn": "শত্রুর সাক্ষাতে ক্ষতির ভয় করলে ১",
   "summary": null,
   "arabic_text": "حَسْبُنَا اللّٰهُ وَنِعْمَ الْوَكِيْلُ",
   "transliteration": "হাসবুনাল্লা-হু ওয়ানি'মাল ওয়াকীল",
   "translation": "আল্লাহই আমাদের জন্য যথেষ্ট, আর তিনি কতই না উত্তম কর্মবিধায়ক",
   "reference_text": "বুখারি ৪৫৬৩",
   "media_url": null
  },
  {
   "slug": "dua-ma-14-02",
   "category": "dua-azkar-ma-14",
   "sort": 2,
   "type": "dua",
   "title_bn": "শত্রুর সাক্ষাতে ক্ষতির ভয় করলে ২",
   "summary": null,
   "arabic_text": "اَللّٰهُمَّ اكْفِنَاهُمْ بِمَا شِئْتَ وَ كَيْفَ شِئْتَ",
   "transliteration": "আল্লা-হুম্মাকফিনা-হুম বিমা শি’তা ওয়া কাইফা শি'তা",
   "translation": "হে আল্লাহ, আপনি তাদের বিরুদ্ধে আমাদের জন্য যথেষ্ট হয়ে যান, যেভাবেই আপনার মর্জি যার মাধ্যমেই আপনার মর্জি।",
   "reference_text": "মুসলিম ৩০০৫",
   "media_url": null
  },
  {
   "slug": "dua-ma-14-03",
   "category": "dua-azkar-ma-14",
   "sort": 3,
   "type": "dua",
   "title_bn": "শত্রুর উপর বদ-দো‘আ ১",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ إِنَّا نَجْعَلُكَ فِيْ نُحُوْرِهِم، وَنَعُوْذُ بِكَ مِنْ شُرُوْرِهِمْ",
   "transliteration": "আল্লা-হুম্মা ইন্না নাজ্‘আলুকা ফী নুহূরিহিম ওয়া না‘উযু বিকা মিন শুরূরিহিম",
   "translation": "হে আল্লাহ! আমরা আপনাকে তাদের গলদেশে রাখছি এবং তাদের অনিষ্ট থেকে আপনার নিকট আশ্রয় প্রার্থনা করছি।",
   "reference_text": "হাকিম ২/১৪২",
   "media_url": null
  },
  {
   "slug": "dua-ma-14-04",
   "category": "dua-azkar-ma-14",
   "sort": 4,
   "type": "dua",
   "title_bn": "শত্রুর উপর বদ-দো‘আ ২",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ مُنْزِلَ الْكِتَابِ، سَرِيْعَ الْحِسَابِ، اهْزِمِ الأَحْزَابَ، اللّٰهُمَّ اهزِمْهُمْ وَزَلْزِلْهُمْ",
   "transliteration": "আল্লা-হুম্মা মুনযিলাল কিতা-বি সারী‘আল হিসা-বি ইহযিমিল আহযা-ব। আল্লা-হুম্মাহযিমহুম ওয়া যালযিলহুম",
   "translation": "হে আল্লাহ, কিতাব নাযিলকারী, দ্রুত হিসাব গ্রহণকারী! আপনি শত্রুবাহিনীকে পরাভূত করুন। হে আল্লাহ! আপনি তাদেরকে পরাজিত করুন এবং তাদের মধ্যে ত্রাস সৃষ্টি করে দিন।",
   "reference_text": "মুসলিম ১৭৪২",
   "media_url": null
  },
  {
   "slug": "dua-ma-15-01",
   "category": "dua-azkar-ma-15",
   "sort": 1,
   "type": "dua",
   "title_bn": "কঠিন কাজের ভার পেলে",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ لاَ سَهْلَ إِلاَّ مَا جَعَلْتَهُ سَهْلاً، وَأَنْتَ تَجْعَلُ الْحَزْنَ إِذَا شِئْتَ سَهْلاً",
   "transliteration": "আল্লা-হুম্মা লা সাহ্‌লা ইল্লা মা জা‘আলতাহু সাহ্‌লান, ওয়া আনতা তাজ্‘আলুল হাযনা ইযা শি’তা সাহ্‌লান",
   "translation": "হে আল্লাহ! আপনি যা সহজ করেছেন তা ছাড়া কোনো কিছুই সহজ নয়। আর যখন আপনি ইচ্ছা করেন তখন কঠিনকেও সহজ করে দেন।",
   "reference_text": "ইবনে হিব্বান ২৪২৭",
   "media_url": null
  },
  {
   "slug": "dua-ma-15-02",
   "category": "dua-azkar-ma-15",
   "sort": 2,
   "type": "dua",
   "title_bn": "দুশ্চিন্তার সময় পড়ুন",
   "summary": null,
   "arabic_text": "اللّٰهُمَّ إِنِّيْ أَعُوْذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ",
   "transliteration": "আল্লা-হুম্মা ইন্নি আ‘ঊযু বিকা মিনাল হাম্মি ওয়াল হাযানি, ওয়াল ‘আজযি ওয়াল কাসালি, ওয়াল বুখলি ওয়াল জুবনি, ওয়া দালা‘ইদ দ্বাইনে ওয়া গালাবাতির রিজা-লি",
   "translation": "হে আল্লাহ! নিশ্চয় আমি আপনার আশ্রয় নিচ্ছি দুশ্চিন্তা ও দুঃখ থেকে, অপারগতা ও অলসতা থেকে, কৃপণতা ও ভীরুতা থেকে, ঋণের ভার ও মানুষদের দমন-পীড়ন থেকে।",
   "reference_text": "বুখারি ২৮৯৩",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_116.mp3"
  },
  {
   "slug": "dua-ma-15-03",
   "category": "dua-azkar-ma-15",
   "sort": 3,
   "type": "dua",
   "title_bn": "কোনো মুসিবতে পড়লে বা কিছু হারিয়ে গেলে",
   "summary": null,
   "arabic_text": "إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ، اللَّهُمَّ أْجُرْنِي فِي مُصِيبَتِي، وَأَخْلِفْ لِي خَيْرًا مِنْهَا",
   "transliteration": "ইন্না-লিল্লা-হি ওয়া ইন্না ইলাইহি রাজি‘উন। আল্লা-হুম্মা'জুরনী ফী মুসীবাতী ওয়াখলুফ লী খাইরাম মিনহা",
   "translation": "আমরা তো আল্লাহ্‌রই। আর নিশ্চয় আমরা তাঁর দিকেই প্রত্যাবর্তনকারী। হে আল্লাহ! আমাকে আমার বিপদে সওয়াব দিন এবং আমার জন্য তার চেয়েও উত্তম কিছু স্থলাভিষিক্ত করে দিন।",
   "reference_text": "মুসলিম ৯১৮",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_146.mp3"
  },
  {
   "slug": "dua-ma-15-04",
   "category": "dua-azkar-ma-15",
   "sort": 4,
   "type": "dua",
   "title_bn": "কোনো বিপদগ্রস্ত লোক দেখলে পড়া",
   "summary": null,
   "arabic_text": "اَلْحَمْدُ لِلّٰهِ الَّذِيْ عَافَانِيْ مِمَّا ابْتَلاَكَ بِهِ، وَفَضَّلَنِيْ عَلَى كَثِيْرٍ مِّمَّنْ خَلَقَ تَفْضِيْلًا",
   "transliteration": "আলহামদুলিল্লা-হিল্লাযী ‘আ-ফা-নী মিম্মাবতালা-কা বিহী, ওয়া ফাদ্দালানী ‘আলা কাসীরিম মিম্মান খলাক্বা তাফদীলা-",
   "translation": "সকল প্রশংসা আল্লাহ্‌র জন্য, যিনি আপনাকে যে পরীক্ষায় ফেলেছেন তা থেকে আমাকে নিরাপদ রেখেছেন এবং তার সৃষ্টির অনেকের উপরে আমাকে অধিক অনুগ্রহ করেছেন।",
   "reference_text": "তিরমিযী ৩৪৩২",
   "media_url": null
  },
  {
   "slug": "dua-ma-16-01",
   "category": "dua-azkar-ma-16",
   "sort": 1,
   "type": "dua",
   "title_bn": "সুরা তাওবা (১২৮-১২৯)",
   "summary": "সুরা তাওবা (১২৮-১২৯)\n[সকাল- সন্ধ্যায় ৩ বার]",
   "arabic_text": "أَعُوْذُ بِاللّٰهِ مِنَ الشَّيْطَانِ الرَّجِيْمِ\nلَقَدۡ جَآءَکُمۡ رَسُوۡلٌ مِّنۡ اَنۡفُسِکُمۡ عَزِیۡزٌ عَلَیۡہِ مَا عَنِتُّمۡ حَرِیۡصٌ عَلَیۡکُمۡ بِالۡمُؤۡمِنِیۡنَ رَءُوۡفٌ رَّحِیۡمٌ ﴿١٢٨﴾ فَاِنۡ تَوَلَّوۡا فَقُلۡ حَسۡبِیَ اللّٰہُ ۫٭ۖ لَاۤ اِلٰہَ اِلَّا ہُوَ ؕ عَلَیۡہِ تَوَکَّلۡتُ وَ ہُوَ رَبُّ الۡعَرۡشِ الۡعَظِیۡمِ ﴿١٢٩﴾",
   "transliteration": null,
   "translation": "তোমাদের কাছে এসেছে তোমাদের মধ্য থেকেই একজন রসূল। তোমাদের দুঃখ-কষ্ট তার পক্ষে দুঃসহ। তিনি তোমাদের মঙ্গলকামী, মুমিনদের প্রতি স্নেহশীল, দয়াময়। এ সত্ত্বেও যদি তারা বিমুখ হয়ে থাকে, তবে বলে দাও, আল্লাহই আমার জন্য যথেষ্ট, তিনি ব্যতীত আর কারো বন্দেগী নেই। আমি তাঁরই ভরসা করি এবং তিনিই মহান আরশের অধিপতি।",
   "reference_text": null,
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_09_128_129.mp3"
  },
  {
   "slug": "dua-ma-16-02",
   "category": "dua-azkar-ma-16",
   "sort": 2,
   "type": "dua",
   "title_bn": "সুরা মু'মিন ১-৩ [একবার]",
   "summary": null,
   "arabic_text": "بِسْمِ اللہِ الرَّحْمٰنِ الرَّحِیۡمِ\nحٰمٓ ۚ﴿۱﴾ تَنۡزِیۡلُ الْکِتٰبِ مِنَ اللہِ الْعَزِیۡزِ الْعَلِیۡمِ ۙ﴿۲﴾ غَافِرِ الذَّنۡۢبِ وَ قَابِلِ التَّوْبِ شَدِیۡدِ الْعِقَابِ ۙ ذِی الطَّوْلِ ؕ لَاۤ اِلٰہَ اِلَّا ہُوَ ؕ اِلَیۡہِ الْمَصِیۡرُ ﴿۳﴾",
   "transliteration": null,
   "translation": "হা-মীম। (১) এই কিতাব আল্লাহর পক্ষ থেকে নাযিল হয়েছে; যিনি পরাক্রমশালী, মহাজ্ঞানী (২) পাপ ক্ষমাকারী ও তওবা কবুলকারী, কঠোর শাস্তিদাতা এবং ক্ষমতাবান। তিনি ছাড়া কোন উপাস্য নেই। তাঁর কাছেই (সকলের) চূড়ান্ত প্রত্যাবর্তন।",
   "reference_text": "তিরমিযি ২৮৭৯",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_43.mp3"
  },
  {
   "slug": "dua-ma-16-03",
   "category": "dua-azkar-ma-16",
   "sort": 3,
   "type": "dua",
   "title_bn": "সুরা হাশরের শেষ ৩ আয়াত",
   "summary": null,
   "arabic_text": "أَعُوذُ بِاللّٰهِ السَّمِيْعِ الْعَلِيْمِ مِنَ الشَّيْطَانِ الرَّجِيْمِ (৩বার)\nہُوَ اللہُ الَّذِیۡ لَاۤ اِلٰہَ اِلَّا ہُوَ ۚ عٰلِمُ الْغَیۡبِ وَ الشَّہَادَۃِ ۚ ہُوَ الرَّحْمٰنُ الرَّحِیۡمُ ﴿۲۲﴾ هُوَ اللّٰهُ الَّذِیْ لَاۤ اِلٰهَ اِلَّا هُوَ ۚاَلْمَلِكُ الْقُدُّوْسُ السَّلٰمُ الْمُؤْمِنُ الْمُهَیْمِنُ الْعَزِیْزُ الْجَبَّارُ الْمُتَکَبِّرُ ؕ سُبْحٰنَ اللّٰهِ عَمَّا یُشْرِكُوْنَ ﴿۲۳﴾ هُوَ اللّٰهُ الْخَالِقُ الْبَارِئُ الْمُصَوِّرُ لَهُ الْاَسْمَآءُ الْحُسْنٰی ؕ یُسَبِّحُ لَہٗ مَا فِی السَّمٰوٰتِ وَ الْاَرْضِ ۚوَ هُوَ الْعَزِیْزُ الْحَكِیْمُ ﴿٪۲۴﴾ (১বার)",
   "transliteration": null,
   "translation": "তিনিই আল্লাহ, যিনি ব্যতীত কোন উপাস্য নেই। তিনি অদৃশ্য ও দৃশ্যমান (সকল) বস্তু সম্বন্ধে জানেন। তিনি পরম করুণাময়, অসীম দয়ালু। (২২) তিনিই আল্লাহ, যিনি ব্যতীত কোন উপাস্য নেই। তিনি মহা অধিপতি, মহাপবিত্র, শান্তিদাতা, নিরাপত্তা-বিধায়ক, সর্বনিয়ন্তা, মহাপরাক্রম-শালী, মহাপ্রতাপশালী, মহামহিম। তারা (তাঁর সাথে) যা কিছু শরীক করে, আল্লাহ তা থেকে পবিত্র। (২৩) তিনিই আল্লাহ, মহান সৃষ্টিকর্তা, মহাউদ্ভাবক, প্রকৃত রূপকার। উত্তম নামসমূহ তাঁরই। আসমান ও জমিনে যা কিছু আছে, (সবই) তাঁর পবিত্রতা ও মহিমা ঘোষণা করে। তিনি পরাক্রমশালী, প্রজ্ঞাবান। (২৪)",
   "reference_text": "তিরমিযি ২৯২২",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_7_3.mp3"
  },
  {
   "slug": "dua-ma-17-01",
   "category": "dua-azkar-ma-17",
   "sort": 1,
   "type": "dua",
   "title_bn": "দোয়া কবুলের দোয়া ১",
   "summary": null,
   "arabic_text": "اللَّهُمَّ إِنِّيْ أَسْأَلُكَ بِأَنَّ لَكَ الْحَمْدَ لَا إِلَهَ إِلَّا أَنْتَ الْمَنَّانُ بَدِيْعُ السَّمَاوَاتِ وَالْأَرْضِ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ يَا حَيُّ يَا قَيُّوْمُ",
   "transliteration": null,
   "translation": "ইয়া আল্লাহ! আমি তোমার নিকট প্রার্থনা করছি। তুমিই সমস্ত প্রশংসার মালিক, তুমি ছাড়া আর কোন দানকারী ইলাহ নাই, তুমিই আসমান ও যমীনসমূহের সৃষ্টিকরী, হে মহান শ্রেষ্ঠত্বের অধিকারী ও মহান দাতা, হে চিরঞ্জীব, হে অবিনশ্বর।",
   "reference_text": "ইবনে মাজাহ ৩৮৫৮",
   "media_url": null
  },
  {
   "slug": "dua-ma-17-02",
   "category": "dua-azkar-ma-17",
   "sort": 2,
   "type": "dua",
   "title_bn": "দোয়া কবুলের দোয়া ২",
   "summary": null,
   "arabic_text": "اللَّهُمَّ إِنِّيْ أَسْأَلُكَ بِأَنِّيْ أَشْهَدُ أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلاَّ أَنْتَ الْأَحَدُ الصَّمَدُ الَّذِيْ لَمْ يَلِدْ وَلَمْ يُوْلَدْ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ ‏",
   "transliteration": null,
   "translation": "হে আল্লাহ! আমি তোমার কাছে প্রার্থনা করছি এবং জানি যে, তুমিই আল্লাহ। তুমি ছাড়া প্রকৃতপক্ষে আর কোন মা’বূদ নেই। তুমি এক ও অদ্বিতীয়। তুমি অমুখাপেক্ষী ও স্বনির্ভর। যিনি কাউকে জন্ম দেননি। কারো থেকে জন্মও নেননি। যার সমকক্ষ কেউ নেই।",
   "reference_text": "ইবনে মাজাহ ৩৮৫৭",
   "media_url": null
  },
  {
   "slug": "dua-ma-17-03",
   "category": "dua-azkar-ma-17",
   "sort": 3,
   "type": "dua",
   "title_bn": "দোয়া কবুলের দোয়া ৩",
   "summary": null,
   "arabic_text": "لَا إِِلَـٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّيْ كُنْتُ مِنَ الظَّالِمِيْنَ",
   "transliteration": null,
   "translation": "তুমি ব্যতীত কোন মা’বূদ নেই, তুমি অতি পবিত্র। আমি নিশ্চয় যালিমদের দলভুক্ত (অপরাধী)।",
   "reference_text": "তিরমিযি ৩৫০৫",
   "media_url": null
  },
  {
   "slug": "dua-ma-17-04",
   "category": "dua-azkar-ma-17",
   "sort": 4,
   "type": "dua",
   "title_bn": "নামাজ শেষ করে (১০ বার করে) পড়ার পরে দোয়া করা",
   "summary": null,
   "arabic_text": "سُبْحَانَ اللّٰهِ\nوَالْحَمْدُ لِلَّهِ\nاَللّٰهُ أَكْبَر‎",
   "transliteration": "সুবহা-নাল্লাহ\nআলহামদুলিল্লা-হ\nআল্লা-হু আকবার",
   "translation": "আল্লাহ অতি-পবিত্র\nসকল প্রশংসা আল্লাহর জন্য\nআল্লাহ অতি-মহান",
   "reference_text": "নাসাঈ ১২৯৯",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_102.mp3"
  },
  {
   "slug": "dua-ma-17-05",
   "category": "dua-azkar-ma-17",
   "sort": 5,
   "type": "dua",
   "title_bn": "রাতে ঘুম ভাঙলে এটি পড়ার পর কোনো দুয়া করলে কবুল হয়",
   "summary": null,
   "arabic_text": "لاَ إِلَهَ إِلاَّ اللّٰهُ وَحْدَهُ لاَ شَرِيْكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيْرٌ، سُبْحَانَ اللّٰهِ، وَالْحَمْدُ لِلّٰهِ، وَلاَ إِلَهَ إِلاَّ اللّٰهُ، وَاللّٰهُ أَكْبَرُ، وَلاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللّٰهِ الْعَلِيِّ الْعَظِيْمِ، رَبِّ اغْفِرْ لِيْ",
   "transliteration": "লা ইলা-হা ইল্লাল্লা-হু ওয়াহ্‌দাহূ লা- শারীকালাহূ, লাহুল মুলকু, ওয়ালাহুল হামদু, ওয়াহুয়া ‘আলা কুল্লি শায়ইন ক্বাদীর। সুবহা-নাল্লাহি, ওয়ালহামদু লিল্লাহি, ওয়া লা ইলা-হা ইল্লাল্লা-হু, ওয়াল্লা-হু আকবার, ওয়া লা- হাওলা ওয়ালা- কুওয়াতা ইল্লা- বিল্লা-হিল ‘আলিয়্যিল ‘আযীম, রাব্বিগফির লী",
   "translation": "একমাত্র আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই, তাঁর কোনো শরীক নেই; রাজত্ব তাঁরই, প্রশংসাও তাঁরই; আর তিনি সকল কিছুর ওপর ক্ষমতাবান। আল্লাহ পবিত্র-মহান। সকল হামদ-প্রশংসা আল্লাহ্‌র। আল্লাহ ছাড়া কোনো হক্ব ইলাহ নেই। আল্লাহ সবচেয়ে বড়। সুউচ্চ সুমহান আল্লাহর সাহায্য ছাড়া (পাপ কাজ থেকে দূরে থাকার) কোনো উপায় এবং (সৎকাজ করার) কোনো শক্তি কারো নেই। হে রব্ব ! আমাকে ক্ষমা করুন",
   "reference_text": "বুখারি ১১৫৪",
   "media_url": null
  },
  {
   "slug": "dua-ma-18-01",
   "category": "dua-azkar-ma-18",
   "sort": 1,
   "type": "dua",
   "title_bn": "প্রতি শুক্রবার সুরা কাহাফের প্রথম ১০ আয়াত পড়া।",
   "summary": null,
   "arabic_text": "اَلۡحَمۡدُ لِلّٰهِ الَّذِیۡۤ اَنۡزَلَ عَلٰی عَبۡدِهِ الۡکِتٰبَ وَ لَمۡ یَجۡعَلۡ لَّهٗ عِوَجًا ؕ﴿ٜ۱﴾ قَیِّمًا لِّیُنۡذِرَ بَاۡسًا شَدِیۡدًا مِّنۡ لَّدُنۡهُ وَ یُبَشِّرَ الۡمُؤۡمِنِیۡنَ الَّذِیۡنَ یَعۡمَلُوۡنَ الصّٰلِحٰتِ اَنَّ لَهُمۡ اَجۡرًا حَسَنًا ۙ﴿۲﴾ مَّاکِثِیۡنَ فِیۡهِ اَبَدًا ۙ﴿۳﴾ وَّ یُنۡذِرَ الَّذِیۡنَ قَالُوا اتَّخَذَ اللّٰهُ وَلَدًا ٭﴿۴﴾ مَا لَهُمۡ بِهٖ مِنۡ عِلۡمٍ وَّ لَا لِاٰبَآئِهِمۡ ؕ کَبُرَتۡ کَلِمَۃً تَخۡرُجُ مِنۡ اَفۡوَاهِهِمۡ ؕ اِنۡ یَّقُوۡلُوۡنَ اِلَّا کَذِبًا ﴿۵﴾ فَلَعَلَّکَ بَاخِعٌ نَّفۡسَکَ عَلٰۤی اٰثَارِهِمۡ اِنۡ لَّمۡ یُؤۡمِنُوۡا بِهٰذَا الۡحَدِیۡثِ اَسَفًا ﴿۶﴾ اِنَّا جَعَلۡنَا مَا عَلَی الۡاَرۡضِ زِیۡنَۃً لَّهَا لِنَبۡلُوَهُمۡ اَیُّهُمۡ اَحۡسَنُ عَمَلًا ﴿۷﴾ وَ اِنَّا لَجٰعِلُوۡنَ مَا عَلَیۡهَا صَعِیۡدًا جُرُزًا ؕ﴿۸﴾ اَمۡ حَسِبۡتَ اَنَّ اَصۡحٰبَ الۡکَهۡفِ وَ الرَّقِیۡمِ ۙ کَانُوۡا مِنۡ اٰیٰتِنَا عَجَبًا ﴿۹﴾ اِذۡ اَوَی الۡفِتۡیَۃُ اِلَی الۡکَهۡفِ فَقَالُوۡا رَبَّنَاۤ اٰتِنَا مِنۡ لَّدُنۡکَ رَحۡمَۃً وَّ هَیِّیٴۡ لَنَا مِنۡ اَمۡرِنَا رَشَدًا ﴿۱۰﴾",
   "transliteration": null,
   "translation": "সকল প্রশংসা আল্লাহর, যিনি তাঁর বান্দার প্রতি এই কিতাব নাযিল করেছেন এবং তাতে কোন বক্রতা রাখেননি। (বরং) একে সরল-সোজা করেছেন, (অবিশ্বাসীদেরকে) তাঁর পক্ষ থেকে কঠিন শাস্তির (জাহান্নামের) ভয় দেখানোর জন্য; সৎকর্মশীল মুমিনদেরকে উত্তম প্রতিদানের (জান্নাতের) সুসংবাদ দেওয়ার জন্য, যাতে তারা চিরকাল অবস্থান করবে এবং যারা বলে, “আল্লাহ সন্তান গ্রহণ করেছেন” তাদেরকে সতর্ক করার জন্য। এ ব্যাপারে তাদের কোন জ্ঞান নেই, তাদের বাপ-দাদাদেরও ছিল না। তাদের মুখ থেকে যে কথা বের হয় তা কী সাংঘাতিক! তারা শুধু মিথ্যাই বলে। তারা এই বাণী (কোরআন) বিশ্বাস না করলে দুঃখে তুমি হয়তো তাদের পেছনে নিজের জীবন শেষ করে দেবে। পৃথিবীর সবকিছু আমি তার শোভায় পরিণত করেছি, যাতে লোকদেরকে পরীক্ষা করতে পারি, কে তাদের মধ্যে কাজে সেরা। আবার তার সবকিছু আমি শূন্য-শুষ্ক মাটি করে দেব। তুমি কি মনে করো যে, গুহা ও ফলকওয়ালারা আমার নিদর্শনসমূহের মধ্যে একটি বিস্ময় ছিল? (স্মরণ করো) যখন যুবকেরা গুহায় আশ্রয় নিয়েছিল; তখন তারা বলেছিল, “হে আমাদের প্রভু! তোমার পক্ষ থেকে আমাদেরকে রহমত দান করো এবং আমাদের সঠিক কাজ আমাদের জন্য সহজ করে দাও।”",
   "reference_text": "তিরমিযি ২২৪০",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_88.mp3"
  },
  {
   "slug": "dua-ma-18-02",
   "category": "dua-azkar-ma-18",
   "sort": 2,
   "type": "dua",
   "title_bn": "কাহাফের শেষ ১০ আয়াতের কথাও এক হাদিসে এসেছে",
   "summary": null,
   "arabic_text": "الَّذِيْنَ كَانَتْ اَعْيُنُهُمْ فِيْ غِطَـآءٍ عَنْ ذِكْرِيْ وَكَانُوْا لَا يَسْتَطِيْعُوْنَ سَمْعًا (101) اَفَحَسِبَ الَّذِيْنَ كَفَرُوْۤا اَنْ يَّتَّخِذُوْا عِبَادِيْ مِنْ دُوْنِيْۤ اَوْلِيَآءَ ؕ اِنَّـاۤ اَعْتَدْنَا جَهَنَّمَ لِلْكٰفِرِيْنَ نُزُلًا (102) قُلْ هَلْ نُنَبِّئُكُمْ بِالْاَخْسَرِيْنَ اَعْمَالًا ؕ (103) اَلَّذِيْنَ ضَلَّ سَعْيُهُمْ فِي الْحَيٰوةِ الدُّنْيَا وَهُمْ يَحْسَبُوْنَ اَنَّهُمْ يُحْسِنُوْنَ صُنْعًا (104) اُولٰٓئِكَ الَّذِيْنَ كَفَرُوْا بِاٰيٰتِ رَبِّهِمْ وَلِقَآئِهٖ فَحَبِطَتْ اَعْمَالُهُمْ فَلَا نُقِيْمُ لَهُمْ يَوْمَ الْقِيٰمَةِ وَزْنًا (105) ذٰلِكَ جَزَآؤُهُمْ جَهَنَّمُ بِمَا كَفَرُوْا وَاتَّخَذُوْۤا اٰيٰتِيْ وَرُسُلِيْ هُزُوًا (106) اِنَّ الَّذِيْنَ اٰمَنُوْا وَعَمِلُوا الصّٰلِحٰتِ كَانَتْ لَهُمْ جَنّٰتُ الْفِرْدَوْسِ نُزُلًا ۙ (107) خٰلِدِيْنَ فِيْهَا لَا يَبْغُوْنَ عَنْهَا حِوَلًا (108) قُلْ لَّوْ كَانَ الْبَحْرُ مِدَادًا لِّكَلِمٰتِ رَبِّيْ لَنَفِدَ الْبَحْرُ قَبْلَ اَنْ تَنْفَدَ كَلِمٰتُ رَبِّيْ وَلَوْ جِئْنَا بِمِثْلِهٖ مَدَدًا (109) قُلْ اِنَّمَاۤ اَنَا بَشَرٌ مِّثْلُكُمْ يُوْحٰۤي اِلَيَّ اَنَّمَاۤ اِلٰـهُكُمْ اِلٰهٌ وَّاحِدٌ ۚ فَمَنْ كَانَ يَرْجُوْا لِقَآءَ رَبِّهٖ فَلْيَعْمَلْ عَمَلًا صَالِحًا وَّلَا يُشْرِكْ بِعِبَادَةِ رَبِّهٖۤ اَحَدًا (110)",
   "transliteration": null,
   "translation": "(দুনিয়ায়) যাদের চোখে আমার নিদর্শন সম্বন্ধে পর্দা পড়ে রয়েছিল এবং যারা শুনতেও সক্ষম ছিল না। যারা কুফর অবলম্বন করেছে, তারা কি এরপরও মনে করে যে, তারা আমার পরিবর্তে আমারই বান্দাদেরকে অভিভাবকরূপে গ্রহণ করবে? নিশ্চয়ই আমি এরূপ কাফেরদের আপ্যায়নের জন্য জাহান্নাম প্রস্তুত রেখেছি। বলে দাও, আমি কি তোমাদেরকে বলে দেব, কর্মে কারা সর্বাপেক্ষা বেশি ক্ষতিগ্রস্ত? তারা সেই সব লোক, পার্থিব জীবনে যাদের সমস্ত দৌড়-ঝাঁপ সরল পথ থেকে বিচ্যুত হয়েছে, অথচ তারা মনে করে তারা খুবই ভালো কাজ করছে। এরাই সেই সব লোক, যারা নিজ প্রতিপালকের আয়াতসমূহ ও তাঁর সামনে উপস্থিতির বিষয়টিকে অস্বীকার করে। ফলে তাদের যাবতীয় কর্ম নিষ্ফল হয়ে গেছে। আমি কিয়ামতের দিন তাদের কোন ওজন গণ্য করব না। জাহান্নামরূপে এটাই তাদের শাস্তি। কেননা তারা কুফরী করেছে এবং আমার আয়াতসমূহ ও আমার রাসূলগণকে পরিহাসের বস্তু বানিয়েছে। (অপর দিকে) যারা ঈমান এনেছে ও সৎকর্ম করেছে তাদের আপ্যায়নের জন্য অবশ্যই ফিরদাউসের উদ্যান রয়েছে। তাতে তারা সর্বদা থাকবে (এবং) তারা সেখান থেকে অন্য কোথাও যেতে চাইবে না। (হে নবী! মানুষকে) বলে দাও, আমার প্রতিপালকের কথা লেখার জন্য যদি সাগর কালি হয়ে যায়, তবে আমার প্রতিপালকের কথা শেষ হওয়ার আগেই সাগর নিঃশেষ হয়ে যাবে, তাতে সাহায্যরূপে অনুরূপ আরও সাগর নিয়ে আসি না কেন! বলে দাও, আমি তো তোমাদের মত একজন মানুষই। (তবে) আমার প্রতি এই ওহী আসে যে, তোমাদের মাবুদ কেবল একই মাবুদ। সুতরাং যে-কেউ নিজ মালিকের সাথে মিলিত হওয়ার আশা রাখে, সে যেন সৎকর্ম করে এবং নিজ মালিকের ইবাদতে অন্য কাউকে শরীক না করে।",
   "reference_text": "সিলসিলায়ে সহিহাহ ২৬৫১",
   "media_url": "https://files.ruqyahbd.org/appfiles/masnun-amal/ma_18_101_110.mp3"
  }
 ],
 "guide": {
  "slug": "self-diagnosis-amulet-guide",
  "category": "self-diagnosis-guide",
  "title_bn": "তাবিজ ও যাদুর জিনিস নষ্ট করার নিয়ম",
  "summary": "রুকইয়াহ শুরু করার আগে অবশ্যই তাবিজ নষ্ট করা জরুরি।",
  "body": "সন্দেহজনক কিছু বা কোন তাবিজ যদি পাওয়া যায় তাহলে সেটা নষ্ট করার জন্য একটি পাত্রে পানি নিন। তারপর সেই পানিতে সিহরের আয়াত পড়ে ফুঁ দিন (সুরা আ’রাফ ১১৭-১২২, ইউনুস ৮১-৮২, সুরা ত্বহা ৬৯), এরপর সূরা ফালাক ৩বার, সূরা নাস ৩বার পড়ে ফুঁ দিন।\n\nলক্ষণীয় বিষয়সমূহ:\n\n• তাবিজ,পুতুল,কাগজ,যাদুকরের দেয়া যেকোনকিছু উপরের আয়াতগুলো পড়া পানিতে ডুবিয়ে রাখবেন কিছুক্ষণ। কাগজে লেখা থাকলে পানিতে রেখেই সেটা ঘষে মুছে ফেলার চেষ্টা করবেন। লেখা মুছার পরে ছিড়ে অনেকগুলো টুকরো করবেন। তারপর শুকিয়ে বা কেরোসিন দিয়ে পুড়িয়ে ফেলবেন। পুড়ানোর সময়ে নিশ্বাসের সাথে সেটার ধোঁয়া নেয়া থেকে বিরত থাকবেন।\n\n• তাবিজ খালি হাতে না ধরে গ্লাভস ব্যবহার করা ভাল। গ্লাভস না পেলে হাতে পলিথিন মুড়িয়ে বা রুকইয়ার আয়াত পড়া তেল হাতে মেখে নিতে পারেন। তাবিজ ধরার পূর্বে এবং নষ্ট করার পুরোটা সময়ে বারবার সুরা ফালাক, নাস পড়বেন।\n\n• তামা বা অন্য ধাতুর তাবিজ বা আংটিতে খোদাই করা তাবিজ লেখা থাকলে লেখাটা ঘষে ঘষে মুছে ফেলবেন। ঘষে মুছতে না পারলে পুড়িয়ে হলেও লেখাটা মুছে ফেলা জরুরী। নিজে করতে না পারলে কোন স্বর্ণকারের কাছে গিয়ে লেখাটা মুছে ফেলবেন।\n\n• তাবিজে গিট দেয়া থাকলে সাবধানে প্রতিটা গিট খুলবেন। কোন পুতুল, মূর্তি, পাখি, মাছ ইত্যাদি পাওয়া গেলে সাবধানে খেয়াল করবেন এদের গায়ে কোন পিন আছে কিনা। থাকলে প্রতিটা পিন খুলবেন। পিনগুলোও পানিতে ডুবিয়ে রাখবেন।\n\n• জীবন্ত কোনকিছু যেমন- পাখি পাওয়া গেলে তার ডানার নিচে এবং শরীরের প্রতিটা জায়গায় খুঁজে দেখবেন কোন তাবিজ,পিন বা সন্দেহজনক কিছু আছে কিনা। থাকলে এগুলো সাবধানে খুলে নিয়ে পাখিকে তাবিজ নষ্টের পানি দিয়ে ভিজিয়ে ছেড়ে দিবেন। তাবিজের ভেতরে কাগজ ছাড়াও অন্যকিছু থাকতে পারে। তাবিজ খুলতে গেলে অনেক সময় খোলস ভেঙ্গে বের করা লাগতে পারে। যাই থাকুক, ভাঙ্গা টুকরোসহ সবটুকুই পানিতে ঢালবেন। একইভাবে যাদুকরের দেয়া তেলপড়া, পানিপড়া ইত্যাদি জিনিসপত্র পানিতে ঢালবেন।\n\n• কারো বাসার দেয়ালে, ফ্লোরে অথবা যেকোন স্থানে তাবিজ আঁকা অথবা খোদাই করা থাকলে লেখাটা ঘষে মুছতে হবে। তারপর তাবিজ নষ্টের পানিটা ওখানে ছিটিয়ে দিতে হবে। অনেক সময় বাসা বানানোর সময়ে প্রতি কোণায় তাবিজ রেখে দেয়া হয়। সেক্ষেত্রে তাবিজ না তুলতে পারলে এসব কোণায় আয়াতগুলো পড়া পানিটা ছিটিয়ে দিবেন পরপর তিনদিন। আর দোয়া করবেন যেন আল্লাহ তাবিজ নষ্ট করে দেন।\n\n• জ্যোতিষীর দেয়া কোন বিশেষ আংটি থাকলে তাবিজ নষ্টের পানিতে ডুবিয়ে রাখবেন। কিছুক্ষণ রেখে পাথরটা ভেঙে তারপর ফেলে দিবেন। জ্যোতিষীরা বিশ্বাস করে পাথরের ক্ষমতা আছে। তাই কোনমতেই এই পাথর রেখে দেয়া যাবেনা।\n\n• তাবিজ নষ্টে ব্যবহৃত পানি ফেলার জন্য এবং তাবিজ পুড়ানোর জন্য, সাধারনত মানুষের যাতায়াত হয়না এমন কোন জায়গা ঠিক করে নিন। জাদুর জিনিসপত্র নষ্ট করার পরেও নিজেদের খাবার, ব্যবহারের জিনিস বা দৈনন্দিনের ময়লার মাঝে এটা ফেলবেন না।\n\n• কোন রাস্তায়, ব্যবসা প্রতিষ্ঠানে, বাড়ির আশেপাশে, ফুলের টবে বা অন্য কোনো সন্দেহজনক জায়গায় তাবিজ রাখা আছে মনে হলে সেখানে পরপর তিনদিন উল্লেখিত আয়াতগুলো পড়ে পানিতে ফু দিয়ে ছিটিয়ে দিন বা পানি ঢেলে দিন। যদি নির্দিষ্ট কোনো যায়গায় জাদুর জিনিস রাখার কথা স্বপ্নে দেখেন, কিন্তু সেখানে খুঁজে না পান, সেক্ষেত্রেও একই নিয়ম।\n\n• আপনি আগে তাবিজ ব্যবহার করলে সেটাও উপরোক্ত নিয়ম অনুযায়ী তাবিজ নষ্ট করবেন। তারপর তাবিজ ব্যবহার করার জন্য তাওবা করবেন।"
 },
 "tests": [
  {
   "slug": "general",
   "title_bn": "সাধারণ সমস্যা (অনির্দিষ্ট) যাচাই",
   "description_bn": "শারীরিক ও মানসিক অস্বস্তির কারণ অনির্দিষ্ট হলে সমন্বিত লক্ষণ যাচাই করুন।",
   "note_bn": "এই টেস্ট শুধু লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।",
   "sort": 1,
   "scoring_mode": "dimensions",
   "questions": [
    {
     "sort": 1,
     "question_bn": "পেটে প্রচুর গ্যাস হওয়া।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 10,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 6,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 2,
     "question_bn": "অতিরিক্ত চুল পড়া। শ্যাম্পুতে কাজ না করা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 10,
        "magic": 8,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 8,
        "magic": 4,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 3,
     "question_bn": "শরীরে জ্বর থাকা কিন্তু থার্মোমিটারে না উঠা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 10,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 10,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 4,
     "question_bn": "কোরআন তেলাওয়াত করলে বারবার হাই আসে, ঘুম পায়।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 10,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 10,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 5,
     "question_bn": "আপনি যে কাজে অভিজ্ঞ সেটা করতে গেলেই ঝামেলা বাধা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 8,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 6,
        "magic": 0,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 6,
     "question_bn": "প্রায়শই শরীর দুর্বল থাকা, ক্ষুধামন্দা, বমি বমি ভাব লাগা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 8,
        "magic": 3,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 6,
        "magic": 3,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 7,
     "question_bn": "নামাজে সিজদার সময় মনের মধ্যে বিভিন্ন অশ্লীল ছবি কিংবা দেবদেবীর মুর্তি ভেসে উঠছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 1,
        "jinn": 6,
        "waswasa": 10
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 1,
        "jinn": 3,
        "waswasa": 9
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 8,
     "question_bn": "আল্লাহ, রাসুল অথবা ইসলামের মৌলিক ব্যাপারে অবমাননাকর চিন্তা মাথায় আসে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 2,
        "jinn": 6,
        "waswasa": 10
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 2,
        "jinn": 4,
        "waswasa": 10
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 9,
     "question_bn": "ওযু-গোসল বা ইস্তিঞ্জার সময় এক অঙ্গ বারবার ধুচ্ছেন, তবুও মনে হয় ধোয়া হয়নি ঠিকমতো?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 2,
        "jinn": 4,
        "waswasa": 10
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 2,
        "magic": 2,
        "jinn": 4,
        "waswasa": 9
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 10,
     "question_bn": "আপনি হঠাৎ পরিবর্তন হয়ে গেছেন? কেমন যেন উদাসীন ভাব চলে এসেছে, কিছুই ভালো লাগছে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 9,
        "magic": 3,
        "jinn": 2,
        "waswasa": 4
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 8,
        "magic": 1,
        "jinn": 2,
        "waswasa": 3
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 11,
     "question_bn": "মাথায় বিক্ষিপ্ত চিন্তা ঘোরাঘুরির কারণে দৈনন্দিনের কাজকর্ম, ইবাদত, যিকির, তিলাওয়াত ইত্যাদিতে মন বসছে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 9,
        "magic": 0,
        "jinn": 0,
        "waswasa": 5
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 8,
        "magic": 0,
        "jinn": 0,
        "waswasa": 2
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 12,
     "question_bn": "কোরআন তেলাওয়াত শুনতে আপনার খারাপ লাগে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 9,
        "jinn": 10,
        "waswasa": 2
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 7,
        "jinn": 9,
        "waswasa": 2
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 13,
     "question_bn": "কোন কারন ছাড়াই হাসাহাসি/কান্নাকাটি করেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 14,
     "question_bn": "ঘন ঘন বোবায় ধরার সমস্যা হয়? মনে হয় যে কেউ চেপে ধরেছে, নড়তে পারছেন না এমন হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 5,
        "magic": 0,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 5,
        "magic": 0,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 15,
     "question_bn": "আপনি ঘুমন্ত অবস্থায় হাটাহাটি করেন? (sleepwalking)",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 7,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 6,
        "jinn": 8,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 16,
     "question_bn": "হঠাৎ আপনার শরীরের কোন অঙ্গ অবশ/বিকল হয়ে গেছে? ডাক্তাররা যেখানে কোন সমস্যা খুঁজে পায় না..",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 17,
     "question_bn": "মেডিকেলীয় কোন ব্যখ্যা ছাড়াই অনেকদিন যাবত শরীরের কোন যায়গায় স্থির ব্যথা আছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 8,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 6,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 18,
     "question_bn": "আপনার শরীরে কোন কারণ ছাড়াই লাল, নীল, হলুদ দাগ অথবা আঘাতের চিহ্ন দেখা যায়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 19,
     "question_bn": "আপনার কি মনে হয়, বিছানায় কেউ আপনার পাশে শুয়ে আছে অথবা কেউ আপনাকে ফলো করছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 3,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 3,
        "jinn": 5,
        "waswasa": 5
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 20,
     "question_bn": "আপনি কি মাঝেমাঝে এমন কিছু জিনিস শোনেন বা দেখেন যা অন্য কেউ দেখে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 6,
        "jinn": 10,
        "waswasa": 3
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 6,
        "jinn": 8,
        "waswasa": 2
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 21,
     "question_bn": "স্বপ্নে নিজেকে অনেক উঁচু কোনো যায়গা থেকে পড়ে যেতে দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 5,
        "magic": 8,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 5,
        "jinn": 8,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 22,
     "question_bn": "স্বপ্নে কোনো প্রাণিকে আক্রমণ করতে বা ধাওয়া করতে দেখেন?। বিশেষতঃ কুকুর, বিড়াল, গরু, সিংহ, সাপ।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 8,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 23,
     "question_bn": "ঘুমের মাঝে প্রায়শই চিৎকার, গোঙানো, হাসি-কান্নাকাটি করেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 6,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 24,
     "question_bn": "ঘুম থেকে ওঠার পর অনেক ক্লান্ত লাগে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 8,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 6,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 25,
     "question_bn": "মৃগীরোগ আছে আপনার?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 8,
        "jinn": 10,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 6,
        "jinn": 8,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 26,
     "question_bn": "ব্যাকপেইন। বিশেষত মেরুদণ্ডের নিচের দিকে ব্যথা করা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 27,
     "question_bn": "(মহিলাদের ক্ষেত্রে) অনিয়মিত মাসিক (পুরুষদের ক্ষেত্রে) প্রসাবে ইনফেকশন এর সমস্যা আছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 6,
        "magic": 8,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 6,
        "magic": 6,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 28,
     "question_bn": "দীর্ঘদিন চিকিৎসা করেও কোন রোগ ভালো হচ্ছে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 6,
        "magic": 10,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 6,
        "magic": 6,
        "jinn": 0,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 29,
     "question_bn": "তীব্র মাথা ব্যথা, ঔষধ খেয়েও তেমন লাভ হয়না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 6,
        "magic": 10,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 4,
        "magic": 8,
        "jinn": 3,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 30,
     "question_bn": "হঠাৎ করে কারো প্রতি তীব্র ঘৃণা বা তীব্র ভালোলাগা অনুভব হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 31,
     "question_bn": "বিকেল থেকে রাত পর্যন্ত খুব অস্বস্তি লাগে বা মেজাজ খারাপ থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 5,
        "magic": 5,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 32,
     "question_bn": "কোন কারণ ছাড়াই বাড়ি থেকে দৌড় দিয়ে বের হয়ে যেতে ইচ্ছা হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "scores": {
        "evil_eye": 0,
        "magic": 10,
        "jinn": 8,
        "waswasa": 0
       }
      },
      {
       "label": "মাঝে মধ্যে",
       "scores": {
        "evil_eye": 5,
        "magic": 10,
        "jinn": 5,
        "waswasa": 0
       }
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    }
   ],
   "bands": [],
   "dimensions": [
    {
     "key": "evil_eye",
     "label_bn": "বদনজর"
    },
    {
     "key": "magic",
     "label_bn": "যাদু"
    },
    {
     "key": "jinn",
     "label_bn": "জিন"
    },
    {
     "key": "waswasa",
     "label_bn": "ওয়াসওয়াসা"
    }
   ],
   "rules": [
    {
     "when": {
      "evil_eye": {
       "min": 97,
       "max": 97
      },
      "magic": {
       "min": 192,
       "max": 192
      },
      "jinn": {
       "min": 177,
       "max": 177
      },
      "waswasa": {
       "min": 44,
       "max": 44
      }
     },
     "flags": [
      "evil_eye",
      "magic",
      "jinn",
      "waswasa"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "max": 0
      },
      "magic": {
       "max": 0
      },
      "jinn": {
       "max": 0
      },
      "waswasa": {
       "max": 0
      }
     },
     "flags": []
    },
    {
     "when": {
      "evil_eye": {
       "min": 90
      },
      "magic": {
       "max": 100
      },
      "jinn": {
       "max": 100
      },
      "waswasa": {
       "max": 20
      }
     },
     "flags": [
      "evil_eye"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "min": 70
      },
      "magic": {
       "max": 90
      },
      "jinn": {
       "max": 90
      },
      "waswasa": {
       "max": 20
      }
     },
     "flags": [
      "evil_eye"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "min": 70
      },
      "magic": {
       "max": 90
      },
      "jinn": {
       "max": 90
      },
      "waswasa": {
       "min": 25
      }
     },
     "flags": [
      "evil_eye",
      "waswasa"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "min": 50
      },
      "magic": {
       "max": 50
      },
      "jinn": {
       "min": 80
      },
      "waswasa": {
       "max": 25
      }
     },
     "flags": [
      "evil_eye",
      "jinn"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "min": 25
      },
      "magic": {
       "max": 40
      },
      "jinn": {
       "max": 40
      },
      "waswasa": {
       "max": 20
      }
     },
     "flags": [
      "evil_eye"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "max": 40
      },
      "magic": {
       "max": 80
      },
      "jinn": {
       "max": 80
      },
      "waswasa": {
       "min": 20
      }
     },
     "flags": [
      "waswasa"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "max": 50
      },
      "magic": {
       "max": 80
      },
      "jinn": {
       "min": 80,
       "max": 120
      },
      "waswasa": {
       "min": 20
      }
     },
     "flags": [
      "waswasa",
      "jinn"
     ]
    },
    {
     "when": {
      "magic": {
       "min": 120
      },
      "jinn": {
       "min": 120
      }
     },
     "flags": [
      "magic",
      "jinn"
     ]
    },
    {
     "when": {
      "magic": {
       "min": 110
      },
      "jinn": {
       "max": 99
      }
     },
     "flags": [
      "magic"
     ]
    },
    {
     "when": {
      "magic": {
       "min": 25
      },
      "jinn": {
       "max": 19
      }
     },
     "flags": [
      "magic"
     ]
    },
    {
     "when": {
      "magic": {
       "min": 25
      },
      "jinn": {
       "min": 25
      }
     },
     "flags": [
      "magic",
      "jinn"
     ]
    },
    {
     "when": {
      "magic": {
       "min": 20
      },
      "jinn": {
       "min": 25
      }
     },
     "flags": [
      "jinn"
     ]
    },
    {
     "when": {
      "magic": {
       "min": 20
      }
     },
     "flags": [
      "magic"
     ]
    },
    {
     "when": {
      "jinn": {
       "min": 20
      }
     },
     "flags": [
      "jinn"
     ]
    },
    {
     "when": {
      "evil_eye": {
       "min": 20
      }
     },
     "flags": [
      "evil_eye"
     ]
    },
    {
     "when": {
      "waswasa": {
       "min": 20
      }
     },
     "flags": [
      "waswasa"
     ]
    }
   ],
   "outcomes": [
    {
     "flags": [
      "evil_eye",
      "magic",
      "jinn",
      "waswasa"
     ],
     "message_bn": "আপনার তো দেখি সব লক্ষণই মিলে! আপনি জীন, যাদু, বদনজর, ওয়াসওয়াসা সবগুলোতেই আক্রান্ত।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "magic",
      "jinn"
     ],
     "message_bn": "আপনার জীন এবং যাদুতে আক্রান্ত হওয়ার অনেক বেশি সম্ভাবনা।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "magic"
     ],
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার সম্ভাবনা অনেক বেশি।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "jinn"
     ],
     "message_bn": "আপনার জীন আক্রান্ত হওয়ার সম্ভাবনা আছে।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "evil_eye"
     ],
     "message_bn": "সম্ভবত আপনি বদনজরে আক্রান্ত।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "evil_eye",
      "waswasa"
     ],
     "message_bn": "সম্ভবত আপনি বদনজরে আক্রান্ত। পাশাপাশি ওয়াসওয়াসার সমস্যাও আছে।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "evil_eye",
      "jinn"
     ],
     "message_bn": "সম্ভবত আপনি বদনজরে আক্রান্ত। পাশাপাশি জীন সংক্রান্ত কিছু লক্ষণও পাওয়া গেছে।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "waswasa",
      "jinn"
     ],
     "message_bn": "আপনার ওয়াসওয়াসা আছে এবং কিছু জীন সংক্রান্ত সমস্যা মিলে যায়।",
     "needs_ruqyah": true
    },
    {
     "flags": [
      "waswasa"
     ],
     "message_bn": "সম্ভবত আপনি ওয়াসওয়াসায় আক্রান্ত।",
     "needs_ruqyah": true
    },
    {
     "flags": [],
     "message_bn": "আলহামদুলিল্লাহ। আপনার রুকইয়াহ সংক্রান্ত কোন সমস্যা নেই।",
     "needs_ruqyah": false
    }
   ],
   "fallback_bn": "একাধিক ধরনের কিছু লক্ষণ পাওয়া গেছে। প্রতিটি বিষয়ের আলাদা টেস্ট দিয়ে মিলিয়ে দেখুন এবং প্রয়োজনে অভিজ্ঞ রাকির পরামর্শ নিন।"
  },
  {
   "slug": "evil-eye",
   "title_bn": "বদনজরের সমস্যা যাচাই",
   "description_bn": "লক্ষণ মিলিয়ে দেখুন আপনি বা আপনার পরিবার বদনজরের প্রভাবে আছেন কিনা।",
   "note_bn": "এই টেস্ট শুধু লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।",
   "sort": 2,
   "scoring_mode": "total",
   "questions": [
    {
     "sort": 1,
     "question_bn": "প্রায়সময় কাজ, নামায, যিকর, ক্লাসে মন না বসা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 2,
     "question_bn": "আত্মীয়-স্বজন বা বন্ধুদের সাথে দেখা হলেই ভালো না লাগা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 3,
     "question_bn": "অহেতুক মেজাজ বিগড়ে থাকা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 4,
     "question_bn": "পেটে প্রচুর গ্যাস হওয়া।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 5,
     "question_bn": "চেহারা ধুসর/হলুদ হয়ে যাওয়া।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 6,
     "question_bn": "কোনো কারণ ছাড়াই কান্না আসা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 7,
     "question_bn": "প্রায়শই শরীর দুর্বল থাকা, ক্ষুধামন্দা, বমি বমি ভাব লাগা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 8,
     "question_bn": "অতিরিক্ত চুল পড়া। শ্যাম্পুতে কাজ না করা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 9,
     "question_bn": "কোন কারণ ছাড়া প্রায়ই দীর্ঘশ্বাস ফেলা, অতিরিক্ত হাই উঠা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 10,
     "question_bn": "হাত-পায়ে মাঝেমধ্যেই ব্যাথা করা, পুরো শরীরে ব্যাথা দৌড়ে বেড়ানো।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 11,
     "question_bn": "মাথাব্যথা হওয়া। তবে ঔষধ খেলে উপকার হওয়া।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 12,
     "question_bn": "শরীরে জ্বর থাকা কিন্তু থার্মোমিটারে না উঠা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 13,
     "question_bn": "কোরআন তেলাওয়াত করলে বারবার হাই আসে, ঘুম পায়।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 14,
     "question_bn": "আপনি যে কাজে অভিজ্ঞ সেটা করতে গেলেই ঝামেলা বাধা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 15,
     "question_bn": "বুক ধড়ফড় করা, দমবন্ধ, অস্বস্তি লাগা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    }
   ],
   "bands": [
    {
     "min_score": 111,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ১০০% (শতকরা একশত ভাগ) সম্ভাবনা আছে। আপনার বদনজরের রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 81,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ৯০% (শতকরা নব্বই ভাগ) সম্ভাবনা আছে। আপনার বদনজরের রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 61,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ৮০% (শতকরা আশি ভাগ) সম্ভাবনা আছে। আপনার বদনজরের রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 51,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ৬০% (শতকরা ষাট ভাগ) সম্ভাবনা আছে। আপনি ৭ দিন বদনজরের রুকইয়া করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 31,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ৫০% (শতকরা পঞ্চাশ ভাগ) সম্ভাবনা আছে। আপনি ৭ দিন বদনজরের রুকইয়া করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 21,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ৩০% (শতকরা ত্রিশ ভাগ) সম্ভাবনা আছে। আপনি ৭ দিন বদনজরের রুকইয়া করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 11,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ২০% (শতকরা বিশ ভাগ) সম্ভাবনা আছে। এত কম সম্ভাবনার জন্য রুকইয়াহ না করলেও হবে।",
     "needs_ruqyah": false
    },
    {
     "min_score": 1,
     "message_bn": "আপনার বদনজরে আক্রান্ত হওয়ার ১০% (শতকরা দশ ভাগ) সম্ভাবনা আছে। এত কম সম্ভাবনার জন্য রুকইয়াহ না করলেও হবে।",
     "needs_ruqyah": false
    },
    {
     "min_score": 0,
     "message_bn": "আপনি বদনজরে আক্রান্ত নন।",
     "needs_ruqyah": false
    }
   ]
  },
  {
   "slug": "magic",
   "title_bn": "যাদুর সমস্যা যাচাই",
   "description_bn": "সিহর বা যাদুর সম্ভাব্য লক্ষণ শনাক্ত করতে নিচের প্রশ্নগুলোর উত্তর দিন।",
   "note_bn": "এই টেস্ট শুধু লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।",
   "sort": 3,
   "scoring_mode": "total",
   "questions": [
    {
     "sort": 1,
     "question_bn": "চোখের অবস্থা অস্বাভাবিক বা অসুন্দর লাগা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 2,
     "question_bn": "কোন কারণ ছাড়াই আপনার শরীর গরম থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 3,
     "question_bn": "ব্যাকপেইন। বিশেষত মেরুদণ্ডের নিচের দিকে ব্যথা করা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 4,
     "question_bn": "(মহিলাদের ক্ষেত্রে) অনিয়মিত মাসিক (পুরুষদের ক্ষেত্রে) প্রসাবে ইনফেকশন এর সমস্যা আছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 5,
     "question_bn": "প্রায়সময় পেট ব্যথা থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 6,
     "question_bn": "দীর্ঘদিন চিকিৎসা করেও কোন রোগ ভালো হচ্ছে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 7,
     "question_bn": "তীব্র মাথা ব্যথা, ঔষধ খেয়েও তেমন লাভ হয়না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 8,
     "question_bn": "হঠাৎ করে কারো প্রতি তীব্র ঘৃণা বা তীব্র ভালোলাগা অনুভব হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 9,
     "question_bn": "পরিবার, বাসা, সমাজের প্রতি আপনার তীব্র বিতৃষ্ণা আছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 10,
     "question_bn": "বিকেল থেকে রাত পর্যন্ত খুব অস্বস্তিতে ভুগেন অথবা মেজাজ খারাপ থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 11,
     "question_bn": "কোন কারণ ছাড়াই বাড়ি থেকে দৌড় দিয়ে বের হয়ে যেতে ইচ্ছা হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 12,
     "question_bn": "শরীরের বিভিন্ন জয়েন্টে অতিরিক্ত ব্যথা হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 13,
     "question_bn": "ঠিকমত ঘুমাতে না পারা। ঘুমালেও ভয়ংকর স্বপ্ন দেখা।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 14,
     "question_bn": "স্বপ্নে কোনো গাড়ি বা প্রাণিকে আক্রমণ করতে বা ধাওয়া করতে দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 15,
     "question_bn": "স্বপ্নে কোন ফাঁকা বাড়ি, মরুভূমি বা গোরস্থানে হাঁটাচলা করতে দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 16,
     "question_bn": "স্বপ্নে বিভিন্ন জায়গায় পানি দেখেন? (যেমন সাগর, নদী, পুকুর, ইত্যাদি)",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 17,
     "question_bn": "স্বপ্নে ঘনঘন কোথাও আগুন জ্বলতে বা কিছু পোড়াতে দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 18,
     "question_bn": "স্বপ্নে নিজেকে উড়তে দেখেন? বা কোন পাখি অথবা বড়বড় গাছ দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    }
   ],
   "bands": [
    {
     "min_score": 150,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ১০০% (শতকরা একশত ভাগ) সম্ভাবনা আছে। আপনার যাদুর রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 130,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৯০% (শতকরা নব্বই ভাগ) সম্ভাবনা আছে। আপনার যাদুর রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 110,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৮০% (শতকরা আশি ভাগ) সম্ভাবনা আছে। আপনার যাদুর রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 90,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৭০% (শতকরা সত্তর ভাগ) সম্ভাবনা আছে। আপনার যাদুর রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 80,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৬০% (শতকরা ষাট ভাগ) সম্ভাবনা আছে। আপনার যাদুর রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 60,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৫০% (শতকরা পঞ্চাশ ভাগ) সম্ভাবনা আছে। আপনি যাদু আক্রান্তের রুকইয়াহ করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 40,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৪০% (শতকরা চল্লিশ ভাগ) সম্ভাবনা আছে। আপনি যাদু আক্রান্তের রুকইয়াহ করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 30,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৩০% (শতকরা ত্রিশ ভাগ) সম্ভাবনা আছে। আপনি যাদু আক্রান্তের রুকইয়াহ করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 20,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ২০% (শতকরা বিশ ভাগ) সম্ভাবনা আছে। রুকইয়াহ না করলেও সমস্যা নাই।",
     "needs_ruqyah": true
    },
    {
     "min_score": 11,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ১০% (শতকরা দশ ভাগ) সম্ভাবনা আছে। রুকইয়াহ না করলেও সমস্যা নাই।",
     "needs_ruqyah": true
    },
    {
     "min_score": 10,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ১০% (শতকরা দশ ভাগ) সম্ভাবনা আছে। রুকইয়াহ না করলেও সমস্যা নাই।",
     "needs_ruqyah": false
    },
    {
     "min_score": 7,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার ৫% (শতকরা পাঁচ ভাগ) সম্ভাবনা আছে। আপনার রুকইয়াহ করা লাগবেনা।",
     "needs_ruqyah": false
    },
    {
     "min_score": 1,
     "message_bn": "আপনার যাদুতে আক্রান্ত হওয়ার সম্ভাবনা কম। আপনার রুকইয়াহ করা লাগবেনা।",
     "needs_ruqyah": false
    },
    {
     "min_score": 0,
     "message_bn": "আপনি যাদুতে আক্রান্ত নন।",
     "needs_ruqyah": false
    }
   ]
  },
  {
   "slug": "jinn",
   "title_bn": "জিন সংক্রান্ত সমস্যা যাচাই",
   "description_bn": "কুরআন ও সুন্নাহ ভিত্তিক লক্ষণ মিলিয়ে জিন সংক্রান্ত সমস্যা যাচাই করুন।",
   "note_bn": "এই টেস্ট শুধু লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।",
   "sort": 4,
   "scoring_mode": "total",
   "questions": [
    {
     "sort": 1,
     "question_bn": "ইবাদত বিমুখতা আছে আপনার? যেমন, নামাজ পড়তে ইচ্ছা হয় না।",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 2,
     "question_bn": "রাতে ঘুমাতে গেলে সারারাত ঘুমে না ধরা এমন সমস্যা হয় আপনার?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 3,
     "question_bn": "কোরআন তেলাওয়াত শুনতে আপনার খারাপ লাগে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 4,
     "question_bn": "আপনি অতিরিক্ত গান শুনেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 5,
     "question_bn": "আপনি সবসময় দুঃশ্চিন্তা করেন, উদ্বিগ্ন থাকেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 6,
     "question_bn": "প্রায়ই আপনার মেজাজ বিক্ষিপ্ত হয়ে থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 7,
     "question_bn": "আপনি অতিরিক্ত ঘুমান? ব্যাপক অলসতা হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 8,
     "question_bn": "অন্ধকারে থাকতে আপনার ভালো লাগে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 9,
     "question_bn": "কোন কারন ছাড়াই হাসাহাসি/কান্নাকাটি করেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 10,
     "question_bn": "ঘন ঘন বোবায় ধরার সমস্যা হয়? মনে হয় যে কেউ চেপে ধরেছে, নড়তে পারছেন না এমন হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 11,
     "question_bn": "আপনি ঘুমন্ত অবস্থায় হাটাহাটি করেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 12,
     "question_bn": "হঠাৎ আপনার শরীরের কোন অঙ্গ অবশ/বিকল হয়ে গেছে? ডাক্তাররা যেখানে কোন সমস্যা খুঁজে পায় না, এমন হয়েছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 13,
     "question_bn": "মেডিকেলীয় কোন ব্যখ্যা ছাড়াই আপনার শরীরের কোন যায়গায় স্থির ব্যথা থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 14,
     "question_bn": "আপনার শরীরের বিশেষতঃ হাতে পায়ে লাল অথবা নীল অথবা হলুদ দাগ দেখা যায়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 15,
     "question_bn": "আপনার কি মনে হয় যে কেউ বিছানায় আপনার পাশে শুয়ে আছে অথবা কেউ আপনাকে ফলো করছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 16,
     "question_bn": "বিছানায় কেউ আপনাকে জড়িয়ে ধরেছে এমন অনুভুতি হয়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 17,
     "question_bn": "আপনি এমন কোন আওয়াজ শুনতে পান যে কে কথা বলছে বুঝতে পারছেন না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 18,
     "question_bn": "জেগে থাকা অবস্থায় স্বপ্নের মত বিভিন্ন অদ্ভুত কল্পনা ভাসতে দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 19,
     "question_bn": "স্বপ্নে নিজেকে অনেক উঁচু কোনো যায়গা থেকে পড়ে যেতে দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 20,
     "question_bn": "স্বপ্নে কোনো প্রাণিকে আক্রমণ করতে বা ধাওয়া করতে দেখেন?। বিশেষতঃ কুকুর বিড়াল ইঁদুর উট সিংহ শিয়াল সাপ",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 21,
     "question_bn": "ঘুমের মাঝে প্রায়শই চিৎকার গোঙানো হাসি-কান্নাকাটি করেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 22,
     "question_bn": "ঘুম থেকে উঠার পর অনেক ক্লান্ত লাগে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 23,
     "question_bn": "স্বপ্নে নিজেকে উড়তে দেখেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 24,
     "question_bn": "মৃগীরোগ আছে আপনার?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    }
   ],
   "bands": [
    {
     "min_score": 190,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার সম্ভাবনা অনেক বেশি। সরাসরি রাকীর কাছে রুকইয়াহ করানো উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 120,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার ৮০% (শতকরা আশি ভাগ) সম্ভাবনা আছে। রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 100,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার ৬০% (শতকরা ষাট ভাগ) সম্ভাবনা আছে। রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 80,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার ৫০% (শতকরা পঞ্চাশ ভাগ) সম্ভাবনা আছে। রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 50,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার ৪০% (শতকরা চল্লিশ ভাগ) সম্ভাবনা আছে। রুকইয়াহ করা উচিত।",
     "needs_ruqyah": true
    },
    {
     "min_score": 30,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার মোটামুটি সম্ভাবনা আছে।",
     "needs_ruqyah": true
    },
    {
     "min_score": 10,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার কিছু সম্ভাবনা আছে। অথবা হতে পারে আপনি বদনজরে আক্রান্ত। আগে বদনজরের রুকইয়াহ করে দেখুন।",
     "needs_ruqyah": false
    },
    {
     "min_score": 1,
     "message_bn": "আপনার জ্বীন আক্রান্ত হওয়ার সম্ভাবনা কম।",
     "needs_ruqyah": false
    },
    {
     "min_score": 0,
     "message_bn": "আপনি জীন আক্রান্ত নন।",
     "needs_ruqyah": false
    }
   ]
  },
  {
   "slug": "waswasa",
   "title_bn": "ওয়াসওয়াসার সমস্যা যাচাই",
   "description_bn": "কুচিন্তা, অযৌক্তিক সন্দেহ ও অবসেসিভ চিন্তা যাচাই করার সেলফ টেস্ট।",
   "note_bn": "এই টেস্ট শুধু লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।",
   "sort": 5,
   "scoring_mode": "total",
   "questions": [
    {
     "sort": 1,
     "question_bn": "আপনি ইদানীং কারণে-অকারণে চিন্তিত থাকছেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 2,
     "question_bn": "আপনি হঠাৎ পরিবর্তন হয়ে গেছেন? কেমন যেন উদাসীন ভাব চলে এসেছে, কিছুই ভালো লাগছে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 3,
     "question_bn": "সালাত বা ওযু নিয়ে বেশি দ্বিধাদ্বন্দ্বে আছেন? বারবার মনে হচ্ছে ঠিকমতো ওযু হচ্ছে না, নামাজের এই অংশটা ঠিকমত হল না এরকম হচ্ছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 4,
     "question_bn": "পরিষ্কার পরিচ্ছন্নতা অথবা পরনের কাপড় নিয়ে আপনি কি অতিরিক্ত চিন্তা করছেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 5,
     "question_bn": "আপনি কি অপ্রয়োজনে টয়লেট বা বাথরুমে অতিরিক্ত সময় ব্যয় করছেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 6,
     "question_bn": "আপনি কি আপনার প্রিয় মানুষটিকে নিয়ে বাজে স্বপ্ন দেখছেন? যা আপনাকে ভীত করছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 8
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 7,
     "question_bn": "আপনার কানে কি ফিস ফিস করে শোনা যাচ্ছে আপনি কুফরের দিকে ধাবিত হচ্ছেন (কুফরি করছেন)?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 8,
     "question_bn": "আপনি কি ওযু-গোসল বা ইস্তিঞ্জার সময় এক অঙ্গ বারবার ধুচ্ছেন? তবুও মনে হচ্ছে ধোয়া হয়নি ঠিকমতো..",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 7
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 9,
     "question_bn": "আপনার বারবার মনে হচ্ছে যে, ওযু ভেঙ্গে যাচ্ছে? প্রসাবের ফোঁটা পড়ছে, অথবা সবসময় মনে হচ্ছে বায়ু বের হয়ে যাচ্ছে? কিন্তু আপনি নিশ্চিত হতে পারছেন না..",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 10,
     "question_bn": "আল্লাহ, রাসুল অথবা ঈমানের ব্যাপারে, ইসলামের মৌলিক ব্যাপারে অবমাননাকর চিন্তা মাথায় আসে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 9
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 11,
     "question_bn": "মুরব্বি, উস্তায বা বয়োজ্যেষ্ঠদের সামনে বসলে, তাদের সাথে কথা বলতে লাগলে কি আপনার ভেতর থেকে কেউ বারবার বেয়াদবির জন্য উস্কে দিতে চায়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 12,
     "question_bn": "আপনি কি কোন অদ্ভুত শব্দ কণ্ঠ শুনতে পাচ্ছেন? কারো সাথে এটা নিয়ে আলোচনা করলে ভাবছে, আপনি প্যারানয়েড বা পাগল হয়ে যাচ্ছেন?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 9
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 8
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 13,
     "question_bn": "নামাজে সিজদা করতে গেলে মনের মধ্যে বিভিন্ন অশ্লীল ছবি কিংবা দেবদেবীর মুর্তি ভেসে উঠছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 14,
     "question_bn": "মাথায় বিক্ষিপ্ত চিন্তা ঘোরাঘুরি করার কারণে দৈনন্দিনের কাজ, সালাত, ইবাদত, যিকির, তিলাওয়াত ইত্যাদিতে মন বসছে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 7
      },
      {
       "label": "মাঝে মধ্যে",
       "score": 6
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    }
   ],
   "bands": [
    {
     "min_score": 90,
     "message_bn": "আপনি ওয়াসওয়াসায় আক্রান্ত। আপনার উচিত ওয়াসওয়াসার রুকইয়াহ শুরু করা।",
     "needs_ruqyah": true
    },
    {
     "min_score": 50,
     "message_bn": "আপনি ওয়াসওয়াসায় আক্রান্ত হওয়ার অনেক বেশি সম্ভাবনা আছে। কিছুদিন ওয়াসওয়াসার রুকইয়াহ করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 30,
     "message_bn": "আপনি ওয়াসওয়াসায় আক্রান্ত হওয়ার সম্ভাবনা আছে। কিছুদিন ওয়াসওয়াসার রুকইয়াহ করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 11,
     "message_bn": "আপনি ওয়াসওয়াসায় আক্রান্ত হওয়ার অল্প সম্ভাবনা আছে। কিছুদিন ওয়াসওয়াসার রুকইয়াহ করতে পারেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 10,
     "message_bn": "আপনি ওয়াসওয়াসায় আক্রান্ত হওয়ার অল্প সম্ভাবনা আছে। কিছুদিন ওয়াসওয়াসার রুকইয়াহ করতে পারেন।",
     "needs_ruqyah": false
    },
    {
     "min_score": 1,
     "message_bn": "আপনি ওয়াসওয়াসায় আক্রান্ত হওয়ার সম্ভাবনা কম। সকাল সন্ধ্যার আমল করলেই যথেষ্ট।",
     "needs_ruqyah": false
    },
    {
     "min_score": 0,
     "message_bn": "আপনি ওয়াসওয়াসায় আক্রান্ত নন।",
     "needs_ruqyah": false
    }
   ]
  },
  {
   "slug": "kids-infant",
   "title_bn": "বাচ্চাদের সমস্যা যাচাই (০ থেকে ২ বছর)",
   "description_bn": "শিশুর অস্বাভাবিক কান্না, ঘুমে চমকে ওঠা ও বদনজরের লক্ষণ যাচাই করুন।",
   "note_bn": "এই টেস্ট শুধু লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।",
   "sort": 6,
   "scoring_mode": "total",
   "questions": [
    {
     "sort": 1,
     "question_bn": "বুকের দুধ ঠিকমত খায় না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 2,
     "question_bn": "রাতে ঘুমের সমস্যা আছে? (কিংবা ঘুমালেও খুব সামান্য)?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 3,
     "question_bn": "অনেক বেশি কান্না-কাটি করে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 4,
     "question_bn": "গায়ের রঙ পরিবর্তন হয়ে যায় হুট করে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 5,
     "question_bn": "মায়ের কোলে গেলেই কান্না করে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 6,
     "question_bn": "অসুখ-বিসুখ লেগেই থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    }
   ],
   "bands": [
    {
     "min_score": 11,
     "message_bn": "সম্ভবত শিশুটি বদনজরে আক্রান্ত। ইনশাআল্লাহ বদনজরের রুকইয়াহ করলে সুস্থ হয়ে যাবে।",
     "needs_ruqyah": true
    },
    {
     "min_score": 1,
     "message_bn": "বিবরণ অনুযায়ী এটা রুকইয়াহ সংক্রান্ত কোনও সমস্যা হবার সম্ভাবনা কম। আপনার বাবুকে ভাল কোনো শিশুরোগ বিশেষজ্ঞ দেখান।",
     "needs_ruqyah": false
    },
    {
     "min_score": 0,
     "message_bn": "আলহামদুলিল্লাহ। আপনার বাচ্চার কোন রুকইয়া সংক্রান্ত সমস্যা নেই।",
     "needs_ruqyah": false
    }
   ]
  },
  {
   "slug": "kids-child",
   "title_bn": "বাচ্চাদের সমস্যা যাচাই (২ থেকে ১২ বছর)",
   "description_bn": "শিশুর আচরণ পরিবর্তন, অতিরিক্ত ভয় ও বদনজরের লক্ষণ যাচাই করুন।",
   "note_bn": "এই টেস্ট শুধু লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।",
   "sort": 7,
   "scoring_mode": "total",
   "questions": [
    {
     "sort": 1,
     "question_bn": "খাওয়া-দাওয়া ঠিকঠাক করে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 2,
     "question_bn": "সবসময় অসুস্থতা লেগেই থাকে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 3,
     "question_bn": "মোটেই কথা শোনে না, বেয়াদবি করে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 4,
     "question_bn": "হুট করে অনেক অসুস্থ হয়ে যায়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 5,
     "question_bn": "বয়সের তুলনায় কথা বলতে পারে না?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 6,
     "question_bn": "আগে ভালোভাবে কথা বললেও এখন তোতলায় বা কথা জড়িয়ে যায়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 7,
     "question_bn": "অকারনে ভয় পায়, দুঃস্বপ্ন দেখে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 8,
     "question_bn": "ঘরের কোণায় বা দেয়ালের দিকে তাকিয়ে থাকে? একা একা কথা বলে, হাসে, খেলে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 9,
     "question_bn": "রাগ-জিদ খুব বেশি?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 10,
     "question_bn": "মাত্রাতিরিক্ত দুষ্টুমি করে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 5
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 11,
     "question_bn": "অটিজমে আক্রান্ত?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 12,
     "question_bn": "রেগে গেলে শরীরে অস্বাভাবিক শক্তি চলে আসে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 15
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 13,
     "question_bn": "বাচ্চার বাবা অথবা মায়ের জিন-জাদু সংক্রান্ত সমস্যা আছে/ছিল?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 15
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 14,
     "question_bn": "মাঝেমাঝে চিন্তা-ভাবনা পূর্ণ বয়স্কদের মত করে (বা হঠাৎ বয়স্কদের কণ্ঠে কথা বলে)?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 15
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 15,
     "question_bn": "কুরুচিপূর্ণ কথা বলা অভ্যাস আছে?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 10
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 16,
     "question_bn": "আযান শুনলে ভয় পায়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 15
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 17,
     "question_bn": "মাঝেমাঝে চোখের মনি অস্বাভাবিক/বড় হয়ে যায়?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 15
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 18,
     "question_bn": "একই ভুল বার বার করে (যেন কেউ উস্কে দিচ্ছে)?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 15
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    },
    {
     "sort": 19,
     "question_bn": "যৌনতা সম্পর্কে চিন্তা-ভাবনা বা আচরণ, এমনকি মা/বাবার গায়ে হাত দেয়া?",
     "options": [
      {
       "label": "হ্যাঁ",
       "score": 15
      },
      {
       "label": "না",
       "score": 0
      }
     ]
    }
   ],
   "bands": [
    {
     "min_score": 36,
     "message_bn": "আপনার বাচ্চার জ্বিন-জাদু সংক্রান্ত সমস্যা থাকতে পারে। আল্লাহ ভাল জানেন। দ্রুত নির্ভরযোগ্য কোনও রাকির পরামর্শ নিন। সম্ভবত এটাই উত্তম হবে। আর চাইলে নিজেরা প্রাথমিকভাবে ৭ দিনের ডিটক্স রুকইয়াহ করাতে পারেন। ইনশাআল্লাহ উপকার হবে।",
     "needs_ruqyah": true
    },
    {
     "min_score": 16,
     "message_bn": "উক্ত শিশুটি একাধিক সমস্যায় আক্রান্ত হতে পারে। কাজেই ডিটক্স করান। এরপর আবার লক্ষণ মিলিয়ে দেখুন এবং পরামর্শ ফলো করুন। ৭ দিনের ডিটক্স রুকইয়াহ করাতে পারেন। ইনশাআল্লাহ উপকার পাবেন।",
     "needs_ruqyah": true
    },
    {
     "min_score": 0,
     "message_bn": "বাচ্চার ক্ষেত্রে উল্লেখিত বিষয়গুলো স্বাভাবিক। এসব এমনিতেও হতে পারে। তবে রুকইয়াহ করতে অসুবিধা নেই। কিছুদিন বদনজরের রুকইয়াহ করুন।",
     "needs_ruqyah": false
    }
   ]
  }
 ]
}
$library$::jsonb;
$library_fn$;

revoke execute on function private.resource_library_payload()
  from public, anon, authenticated;

create or replace function private.install_resource_library(p_actor uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  payload jsonb := private.resource_library_payload();
  entry jsonb;
  question jsonb;
  band jsonb;
  parent_id_value uuid;
  category_id_value uuid;
  test_id_value uuid;
  root record;
  added_items integer := 0;
  moved_items integer := 0;
  added_tests integer := 0;
  affected integer;
begin
  if p_actor is null or not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_actor and ur.role = 'super_admin'
  ) then
    raise exception 'The resource library must be installed for a Super Admin.'
      using errcode = '42501';
  end if;

  -- Root categories (no-ops where the standard taxonomy already exists).
  for root in
    select * from (values
      ('ruqyah', 'Ruqyah', 'রুকইয়াহ', 2),
      ('dua-azkar', 'Dua & Azkar', 'দোয়া ও যিকর', 1),
      ('pdf', 'PDF', 'পিডিএফ', 4),
      ('self-diagnosis', 'Self-diagnosis', 'সেলফ ডায়াগনোসিস', 5)
    ) as r(slug, name, name_bn, sort_order)
  loop
    insert into public.content_categories (
      name, name_bn, slug, sort_order, is_active, created_by, updated_by
    ) values (
      root.name, root.name_bn, root.slug, root.sort_order, true,
      p_actor, p_actor
    ) on conflict (slug) do nothing;
  end loop;

  for entry in select * from jsonb_array_elements(payload -> 'categories')
  loop
    select id into parent_id_value
    from public.content_categories
    where slug = entry ->> 'parent';
    insert into public.content_categories (
      parent_id, name, name_bn, slug, sort_order, is_active,
      created_by, updated_by
    ) values (
      parent_id_value, entry ->> 'name', entry ->> 'name_bn',
      entry ->> 'slug', (entry ->> 'sort')::integer, true, p_actor, p_actor
    ) on conflict (slug) do nothing;
  end loop;

  -- Audio: reuse an existing record with the same link, otherwise add one.
  for entry in select * from jsonb_array_elements(payload -> 'audio')
  loop
    select id into category_id_value
    from public.content_categories where slug = entry ->> 'category';

    update public.content_items ci
    set category_id = category_id_value,
        sort_order = (entry ->> 'sort')::integer,
        updated_by = p_actor
    where ci.type = 'audio'
      and ci.status <> 'archived'
      and ci.media_url = entry ->> 'media_url'
      and ci.slug not like 'ruqyah-lib-%'
      and not exists (
        select 1 from public.content_categories current_category
        where current_category.id = ci.category_id
          and current_category.slug like 'ruqyah-lib-%'
      )
      and not exists (
        select 1 from public.content_items library_row
        where library_row.slug = entry ->> 'slug'
      );
    get diagnostics affected = row_count;
    moved_items := moved_items + affected;
    if exists (
      select 1 from public.content_items ci
      where ci.type = 'audio'
        and ci.status <> 'archived'
        and ci.media_url = entry ->> 'media_url'
    ) then
      continue;
    end if;

    insert into public.content_items (
      type, category_id, title, title_bn, slug, summary,
      media_source_type, media_url, visibility, status, published_at,
      sort_order, language_code, created_by, updated_by
    ) values (
      'audio', category_id_value, entry ->> 'title_bn', entry ->> 'title_bn',
      entry ->> 'slug', entry ->> 'summary', 'direct_audio_url',
      entry ->> 'media_url', 'public', 'published', now(),
      (entry ->> 'sort')::integer, 'bn', p_actor, p_actor
    ) on conflict (slug) do nothing;
    get diagnostics affected = row_count;
    added_items := added_items + affected;
  end loop;

  for entry in select * from jsonb_array_elements(payload -> 'pdf')
  loop
    select id into category_id_value
    from public.content_categories where slug = entry ->> 'category';
    insert into public.content_items (
      type, category_id, title, title_bn, slug, summary,
      media_source_type, media_url, visibility, status, published_at,
      sort_order, language_code, created_by, updated_by
    ) values (
      'pdf', category_id_value, entry ->> 'title_bn', entry ->> 'title_bn',
      entry ->> 'slug', entry ->> 'summary', 'external_pdf',
      entry ->> 'media_url', 'public', 'published', now(),
      (entry ->> 'sort')::integer, 'bn', p_actor, p_actor
    ) on conflict (slug) do nothing;
    get diagnostics affected = row_count;
    added_items := added_items + affected;
  end loop;

  for entry in select * from jsonb_array_elements(payload -> 'dua')
  loop
    select id into category_id_value
    from public.content_categories where slug = entry ->> 'category';
    insert into public.content_items (
      type, category_id, title, title_bn, slug, summary, arabic_text,
      transliteration, bangla_text, reference_text, media_source_type,
      media_url, visibility, status, published_at, sort_order,
      language_code, created_by, updated_by
    ) values (
      'dua', category_id_value, entry ->> 'title_bn', entry ->> 'title_bn',
      entry ->> 'slug', entry ->> 'summary', entry ->> 'arabic_text',
      entry ->> 'transliteration', entry ->> 'translation',
      entry ->> 'reference_text',
      case when entry ->> 'media_url' is null then null
           else 'direct_audio_url'::public.media_source_type end,
      entry ->> 'media_url', 'public', 'published', now(),
      (entry ->> 'sort')::integer, 'bn', p_actor, p_actor
    ) on conflict (slug) do nothing;
    get diagnostics affected = row_count;
    added_items := added_items + affected;
  end loop;

  entry := payload -> 'guide';
  select id into category_id_value
  from public.content_categories where slug = entry ->> 'category';
  insert into public.content_items (
    type, category_id, title, title_bn, slug, summary, body, visibility,
    status, published_at, sort_order, language_code, created_by, updated_by
  ) values (
    'guide', category_id_value, entry ->> 'title_bn', entry ->> 'title_bn',
    entry ->> 'slug', entry ->> 'summary', entry ->> 'body', 'public',
    'published', now(), 1, 'bn', p_actor, p_actor
  ) on conflict (slug) do nothing;
  get diagnostics affected = row_count;
  added_items := added_items + affected;

  -- Self-assessment tests: a test that already exists is left as edited.
  for entry in select * from jsonb_array_elements(payload -> 'tests')
  loop
    insert into public.self_assessment_tests (
      slug, title_bn, description_bn, note_bn, scoring_mode, dimensions,
      rules, outcomes, fallback_bn, sort_order, is_published, updated_by
    ) values (
      entry ->> 'slug', entry ->> 'title_bn', entry ->> 'description_bn',
      entry ->> 'note_bn', entry ->> 'scoring_mode',
      coalesce(entry -> 'dimensions', '[]'::jsonb),
      coalesce(entry -> 'rules', '[]'::jsonb),
      coalesce(entry -> 'outcomes', '[]'::jsonb),
      entry ->> 'fallback_bn', (entry ->> 'sort')::integer, true, p_actor
    ) on conflict (slug) do nothing
    returning id into test_id_value;
    if test_id_value is null then
      continue;
    end if;
    added_tests := added_tests + 1;
    for question in select * from jsonb_array_elements(entry -> 'questions')
    loop
      insert into public.self_assessment_questions (
        test_id, sort_order, question_bn, options
      ) values (
        test_id_value, (question ->> 'sort')::integer,
        question ->> 'question_bn', question -> 'options'
      );
    end loop;
    for band in select * from jsonb_array_elements(entry -> 'bands')
    loop
      insert into public.self_assessment_result_bands (
        test_id, min_score, message_bn, needs_ruqyah
      ) values (
        test_id_value, (band ->> 'min_score')::integer,
        band ->> 'message_bn', (band ->> 'needs_ruqyah')::boolean
      );
    end loop;
    test_id_value := null;
  end loop;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, metadata
  ) values (
    p_actor, 'resource_library_installed', 'content_item',
    jsonb_build_object(
      'added_items', added_items,
      'moved_items', moved_items,
      'added_tests', added_tests
    )
  );

  return jsonb_build_object(
    'added_items', added_items,
    'moved_items', moved_items,
    'added_tests', added_tests
  );
end;
$$;

revoke execute on function private.install_resource_library(uuid)
  from public, anon, authenticated;

do $$
declare
  actor uuid;
  result jsonb;
begin
  select ur.user_id into actor
  from public.user_roles ur
  join auth.users u on u.id = ur.user_id
  where ur.role = 'super_admin'
  order by u.created_at, ur.user_id
  limit 1;

  if actor is null then
    raise notice 'No Super Admin found; resource library content not installed.';
    return;
  end if;

  result := private.install_resource_library(actor);
  raise notice 'Resource library installed: %', result;
end;
$$;
