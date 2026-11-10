-- Admin-editable prescription templates (owner request 2026-11-10).
--
-- The 51 official Sukun templates used to live in app code, so every text,
-- time or content-link change needed a full web deploy. They now live here
-- and a Super Admin edits them in the app; the change shows at once.
--
-- * Super Admin only: templates are reviewer material, never patient data.
--   Reads go through RLS; writes only through admin_save_care_template
--   (validated, audited with before/after). No delete: is_active = false.
-- * Imported plans copy the text, so editing a template never rewrites an
--   existing plan (clinical history stays intact).
-- * The app keeps its built-in copy as an offline fallback.

create table if not exists public.care_templates (
  id text primary key,
  category text not null,
  title text not null,
  instruction text not null,
  action_type text not null,
  default_times time[] not null default '{}',
  resource_refs text[] not null default '{}',
  requires_resource boolean not null default false,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  constraint care_templates_id_format check (id ~ '^[a-z][0-9]{2}$'),
  constraint care_templates_category check (
    category in ('amal', 'supplement', 'bath', 'audio', 'special')
  ),
  constraint care_templates_action_type check (
    action_type in ('amal', 'supplement', 'bath', 'audio')
  ),
  constraint care_templates_title_length check (
    char_length(btrim(title)) between 1 and 120
  ),
  constraint care_templates_instruction_length check (
    char_length(btrim(instruction)) between 1 and 2000
  ),
  constraint care_templates_times_count check (cardinality(default_times) <= 8),
  constraint care_templates_refs_count check (cardinality(resource_refs) <= 16),
  constraint care_templates_sort_order check (sort_order between 0 and 100000)
);

comment on table public.care_templates is
  'Super Admin editable prescription templates for bulk import. Not patient data.';

alter table public.care_templates enable row level security;

drop policy if exists care_templates_select_super_admin on public.care_templates;
create policy care_templates_select_super_admin
  on public.care_templates
  for select
  to authenticated
  using ((select private.is_super_admin()));

revoke all on table public.care_templates from public, anon, authenticated;
grant select on table public.care_templates to authenticated;

create index if not exists care_templates_category_order_idx
  on public.care_templates (category, sort_order);

-- Create (p_template->>'id' empty) or update one template.
create or replace function public.admin_save_care_template(p_template jsonb)
returns public.care_templates
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_id text := nullif(btrim(coalesce(p_template->>'id', '')), '');
  v_category text := btrim(coalesce(p_template->>'category', ''));
  v_title text := btrim(coalesce(p_template->>'title', ''));
  v_instruction text := btrim(coalesce(p_template->>'instruction', ''));
  v_action_type text;
  v_times time[] := '{}';
  v_refs text[] := '{}';
  v_value text;
  v_prefix text;
  v_next integer;
  v_before public.care_templates;
  v_saved public.care_templates;
begin
  if v_actor is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_template is null or jsonb_typeof(p_template) <> 'object' then
    raise exception 'Invalid template.' using errcode = '22023';
  end if;

  v_prefix := case v_category
    when 'amal' then 'a' when 'supplement' then 's' when 'bath' then 'b'
    when 'audio' then 'u' when 'special' then 'x' end;
  if v_prefix is null then
    raise exception 'Invalid template category.' using errcode = '22023';
  end if;
  v_action_type := coalesce(
    nullif(btrim(coalesce(p_template->>'action_type', '')), ''),
    case v_category when 'special' then 'amal' else v_category end
  );

  if jsonb_typeof(coalesce(p_template->'default_times', '[]')) <> 'array'
     or jsonb_typeof(coalesce(p_template->'resource_refs', '[]')) <> 'array' then
    raise exception 'Invalid template lists.' using errcode = '22023';
  end if;
  for v_value in
    select value from jsonb_array_elements_text(coalesce(p_template->'default_times', '[]'))
  loop
    if v_value !~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' then
      raise exception 'Invalid reminder time.' using errcode = '22023';
    end if;
    if not (v_value::time = any(v_times)) then
      v_times := array_append(v_times, v_value::time);
    end if;
  end loop;
  select coalesce(array_agg(t order by t), '{}') into v_times from unnest(v_times) t;
  for v_value in
    select value from jsonb_array_elements_text(coalesce(p_template->'resource_refs', '[]'))
  loop
    if v_value !~ '^(quran:[0-9]{1,3}|[a-z0-9][a-z0-9-]{0,119})$'
       or (v_value ~ '^quran:' and split_part(v_value, ':', 2)::integer not between 1 and 114) then
      raise exception 'Invalid content link.' using errcode = '22023';
    end if;
    if not (v_value = any(v_refs)) then
      v_refs := array_append(v_refs, v_value);
    end if;
  end loop;

  if v_id is null then
    -- New template: next free number for its category letter.
    perform pg_advisory_xact_lock(hashtextextended('care_templates:' || v_prefix, 0));
    select coalesce(max(substring(ct.id from 2)::integer), 0) + 1 into v_next
    from public.care_templates ct
    where ct.id like v_prefix || '%';
    if v_next > 99 then
      raise exception 'No free template number in this category.' using errcode = '22023';
    end if;
    v_id := v_prefix || lpad(v_next::text, 2, '0');
  else
    select ct.* into v_before from public.care_templates ct where ct.id = v_id for update;
    if not found then
      raise exception 'Template was not found.' using errcode = 'P0002';
    end if;
  end if;

  insert into public.care_templates as ct (
    id, category, title, instruction, action_type, default_times,
    resource_refs, requires_resource, sort_order, is_active, updated_by
  ) values (
    v_id, v_category, v_title, v_instruction, v_action_type, v_times, v_refs,
    coalesce((p_template->>'requires_resource')::boolean, false),
    coalesce(
      (p_template->>'sort_order')::integer,
      (select coalesce(max(o.sort_order), 0) + 10 from public.care_templates o
       where o.category = v_category)
    ),
    coalesce((p_template->>'is_active')::boolean, true),
    v_actor
  )
  on conflict (id) do update set
    category = excluded.category,
    title = excluded.title,
    instruction = excluded.instruction,
    action_type = excluded.action_type,
    default_times = excluded.default_times,
    resource_refs = excluded.resource_refs,
    requires_resource = excluded.requires_resource,
    sort_order = coalesce((p_template->>'sort_order')::integer, ct.sort_order),
    is_active = excluded.is_active,
    updated_at = now(),
    updated_by = v_actor
  returning * into v_saved;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, metadata
  ) values (
    v_actor,
    case when v_before.id is null then 'care_template.created' else 'care_template.updated' end,
    'care_template',
    null,
    jsonb_build_object(
      'template_id', v_saved.id,
      'before', case when v_before.id is null then null else to_jsonb(v_before) end,
      'after', to_jsonb(v_saved)
    )
  );
  return v_saved;
end;
$$;

revoke all on function public.admin_save_care_template(jsonb) from public, anon;
grant execute on function public.admin_save_care_template(jsonb) to authenticated;

-- The 51 official templates as they were in app code on 2026-11-10.
insert into public.care_templates (
  id, category, title, instruction, action_type, default_times,
  resource_refs, requires_resource, sort_order
) values
  ('a01', 'amal', 'সকাল–সন্ধ্যার মাসনুন আমল', 'সকাল ও সন্ধ্যার মাসনুন আমল গুরুত্ব দিয়ে করবেন।', 'amal', array['06:30:00'::time, '17:30:00'::time]::time[], array['srg2024-c04-t033', 'srg2024-aml-001', 'srg2024-aml-002', 'srg2024-qur-005', 'sukun-ruqyahbd-ayatul-kursi', 'quran:112', 'quran:113', 'quran:114', 'sukun-ruqyahbd-three-kul', 'srg2024-dua-009', 'srg2024-dua-010', 'srg2024-dua-011', 'srg2024-dua-012']::text[], false, 10),
  ('a02', 'amal', 'ঘুমের পূর্বের আমল', 'প্রতিদিন ঘুমানোর আগে নির্ধারিত মাসনুন আমল করবেন।', 'amal', array['22:00:00'::time]::time[], array['srg2024-c04-t034', 'srg2024-aml-003', 'srg2024-aml-004', 'srg2024-aml-005', 'srg2024-qur-005', 'sukun-ruqyahbd-ayatul-kursi', 'srg2024-aml-006', 'srg2024-qur-006', 'srg2024-aml-007', 'quran:112', 'quran:113', 'quran:114', 'sukun-ruqyahbd-three-kul', 'srg2024-dua-013']::text[], false, 20),
  ('a03', 'amal', 'কাজের শুরুতে বিসমিল্লাহ', 'সব কাজের শুরুতে বিসমিল্লাহ বলার অভ্যাস করবেন।', 'amal', array['07:00:00'::time]::time[], array['srg2024-c04-t036', 'srg2024-dua-022']::text[], false, 30),
  ('a04', 'amal', 'নামাজের পর তাসবীহে ফাতেমী', 'প্রতি নামাজের পরে তাসবীহে ফাতেমী পড়বেন।', 'amal', array['05:15:00'::time, '13:30:00'::time, '16:45:00'::time, '18:15:00'::time, '20:00:00'::time]::time[], array[]::text[], false, 40),
  ('a05', 'amal', 'আয়াতুল কুরসি ও ফালাক–নাস', 'সকাল ও সন্ধ্যায় মাথায়/বুকে হাত রেখে আয়াতুল কুরসি ও সূরা ফালাক–নাস {বার} বার পড়বেন।', 'amal', array['06:30:00'::time, '17:30:00'::time]::time[], array['srg2024-aml-005', 'srg2024-qur-005', 'sukun-ruqyahbd-ayatul-kursi', 'quran:113', 'quran:114', 'sukun-ruqyahbd-three-kul']::text[], true, 50),
  ('a06', 'amal', 'সূরা বাকারা খতম', 'প্রতি {দিন} দিনে সূরা বাকারা এক খতম করার নির্দেশনা—পাঠ/শ্রবণ পদ্ধতি অ্যাডমিন যাচাই করবেন।', 'amal', array['20:30:00'::time]::time[], array['quran:2', 'sukun-ruqyahbd-baqara']::text[], true, 60),
  ('a07', 'amal', 'প্রতিদিন সূরা বাকারা শ্রবণ', 'নির্ধারিত সূরা বাকারা তিলাওয়াত শুনবেন; কতদিন/কতবার হবে তা অ্যাডমিন লিখবেন।', 'amal', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-baqara', 'quran:2']::text[], true, 70),
  ('a08', 'amal', 'দরূদ শরীফ', 'দৈনিক দরূদ শরীফ {বার} বার পড়বেন।', 'amal', array['09:00:00'::time]::time[], array[]::text[], false, 80),
  ('a09', 'amal', 'ইস্তিগফার', 'দৈনিক ইস্তিগফার {বার} বার পড়বেন।', 'amal', array['16:30:00'::time]::time[], array[]::text[], false, 90),
  ('a10', 'amal', 'সকালের শুরু দোয়া', 'সকালে নির্ধারিত শুরু দোয়া {বার} বার পড়বেন।', 'amal', array['06:45:00'::time]::time[], array[]::text[], false, 100),
  ('a11', 'amal', 'সন্ধ্যা ও ঘুমের শেষ দোয়া', 'সকাল, সন্ধ্যা ও ঘুমের পূর্বে নির্ধারিত শেষ দোয়া {বার} বার পড়বেন।', 'amal', array['22:15:00'::time]::time[], array[]::text[], false, 110),
  ('s01', 'supplement', 'রুকইয়াহ পাঠ দিয়ে পানি প্রস্তুত', 'পানি প্রস্তুতের জন্য সূরা ফাতিহা, আয়াতুল কুরসি, তিন কুল এবং নির্বাচিত আয়াত পড়ার নির্দেশনা; সুনির্দিষ্ট আয়াত/পুনরাবৃত্তি প্রেসক্রিপশন অনুযায়ী যাচাই করুন।', 'supplement', array['08:00:00'::time]::time[], array['srg2024-c03-t004', 'srg2024-sup-001', 'quran:1', 'sukun-ruqyahbd-fatiha', 'srg2024-qur-005', 'sukun-ruqyahbd-ayatul-kursi', 'quran:112', 'quran:113', 'quran:114', 'sukun-ruqyahbd-three-kul', 'srg2024-c04-t011', 'sukun-ruqyahbd-common-bangla']::text[], false, 120),
  ('s02', 'supplement', 'নির্বাচিত সিহর/শিফা আয়াত', 'অনুমোদিত সিহর, শিফা, হারক ও কিতাল আয়াতের তালিকা যাচাই করে তেল/পানি/মধু/আতরে ফুঁ দেওয়ার খসড়া নির্দেশনা।', 'supplement', array['08:15:00'::time]::time[], array['srg2024-c03-t003', 'srg2024-c04-t015', 'sukun-ruqyahbd-sihr-hibshi', 'srg2024-c04-t021', 'sukun-ruqyahbd-shifa', 'sukun-ruqyahbd-shifa-sakina', 'srg2024-c04-t013', 'sukun-ruqyahbd-harq', 'srg2024-c04-t022', 'sukun-ruqyahbd-qital-tadmir']::text[], false, 130),
  ('s03', 'supplement', 'রুকইয়াহ পানি দুই বেলা', 'নির্ধারিত রুকইয়াহ পানি দিনে {বার} বেলা পান করার নির্দেশনা; পরিমাণ ও স্বাস্থ্যগত উপযোগিতা দায়িত্বপ্রাপ্ত ব্যক্তি যাচাই করবেন।', 'supplement', array['07:30:00'::time, '19:30:00'::time]::time[], array['srg2024-sup-001', 'srg2024-c03-t004']::text[], false, 140),
  ('s04', 'supplement', 'বাসায় পানি স্প্রে', 'নির্ধারিত পানি বাসায় স্প্রে করার নির্দেশনা; সময় ও নিয়ম অ্যাডমিন নিশ্চিত করবেন।', 'supplement', array['18:00:00'::time]::time[], array['srg2024-sup-001', 'srg2024-c03-t004']::text[], false, 150),
  ('s05', 'supplement', 'গোসলের পানিতে মেশানো', 'গোসলের পানির সঙ্গে অনুমোদিত রুকইয়াহ পানি মেশানোর নির্দেশনা।', 'supplement', array['09:00:00'::time]::time[], array['srg2024-sup-001', 'srg2024-c03-t027']::text[], false, 160),
  ('s06', 'supplement', 'সকালের পানিতে মধু', 'সকালের পানির সঙ্গে মধু মেশানোর নির্দেশনা; অ্যালার্জি ও স্বাস্থ্যগত বিষয় যাচাই করতে হবে।', 'supplement', array['07:00:00'::time]::time[], array['srg2024-sup-002', 'srg2024-c03-t005']::text[], false, 170),
  ('s07', 'supplement', 'নির্ধারিত তেল মালিশ', 'নির্বাচিত জায়গায় (পিঠ, ঘাড়, কোমর, মাথা বা ব্যথার স্থান) তেল ব্যবহারের খসড়া; প্রয়োগের স্থান ও ত্বকের উপযোগিতা নিশ্চিত করুন।', 'supplement', array['21:30:00'::time]::time[], array['srg2024-sup-003', 'srg2024-c03-t006']::text[], false, 180),
  ('s08', 'supplement', 'বিছানার আশপাশে আতর', 'প্রয়োজনে ও ঘুমের পূর্বে বিছানার আশপাশে আতর ব্যবহারের নির্দেশনা; সংবেদনশীলতা যাচাই করুন।', 'supplement', array['22:00:00'::time]::time[], array['srg2024-sup-010', 'srg2024-c03-t013']::text[], false, 190),
  ('s09', 'supplement', 'মেহেদী ব্যবহারের নির্দেশনা', 'প্রেসক্রিপশন অনুযায়ী মেহেদী ব্যবহার; প্রস্তুতি ও প্রয়োগ যাচাই করতে হবে।', 'supplement', array['20:00:00'::time]::time[], array['srg2024-sup-013', 'srg2024-c03-t016']::text[], false, 200),
  ('s10', 'supplement', 'প্রতি নির্ধারিত দিনে পুনঃপ্রস্তুত', 'রুকইয়াহ পানি/অন্যান্য উপকরণ প্রতি {দিন} দিন পর নতুন করে প্রস্তুত করার নির্দেশনা।', 'supplement', array['08:00:00'::time]::time[], array['srg2024-c03-t003', 'srg2024-sup-001']::text[], false, 210),
  ('b01', 'bath', 'বদনজরের গোসল', '{দিন} দিন নজর/বদনজরের গোসল করবেন। সময় ও পদ্ধতি অ্যাডমিন যাচাই করবেন।', 'bath', array['10:00:00'::time]::time[], array['srg2024-ghs-002', 'srg2024-c03-t028', 'srg2024-c04-t014', 'sukun-ruqyahbd-evil-eye']::text[], false, 220),
  ('b02', 'bath', 'বরই পাতার গোসল', '{দিন} দিন বরই পাতার গোসল করবেন।', 'bath', array['10:00:00'::time]::time[], array['srg2024-ghs-003', 'srg2024-c03-t029', 'srg2024-sup-007', 'srg2024-c04-t015', 'sukun-ruqyahbd-sihr-hibshi']::text[], false, 230),
  ('b03', 'bath', 'ডিটক্স গোসল', '{দিন} দিন ডিটক্স গোসল করবেন। গোসলের পদ্ধতি ও উপযোগিতা যাচাই করুন।', 'bath', array['10:00:00'::time]::time[], array['srg2024-ghs-004', 'srg2024-c03-t030']::text[], false, 240),
  ('b04', 'bath', 'সাপ্তাহিক নজরের গোসল', 'সপ্তাহে {বার} দিন নজরের গোসল করবেন।', 'bath', array['10:00:00'::time]::time[], array['srg2024-ghs-002', 'srg2024-c03-t028', 'srg2024-c04-t014', 'sukun-ruqyahbd-evil-eye']::text[], false, 250),
  ('b05', 'bath', 'নজর → বরই পাতা → ডিটক্স', 'প্রথম {দিন} দিন নজরের গোসল; পরবর্তী পর্যায়ে বরই পাতার ও ডিটক্স গোসলের দিন অ্যাডমিন পৃথকভাবে নির্ধারণ করবেন।', 'bath', array['10:00:00'::time]::time[], array['srg2024-ghs-002', 'srg2024-ghs-003', 'srg2024-ghs-004']::text[], false, 260),
  ('b06', 'bath', 'বরই পাতা → ডিটক্স → নজর', 'প্রথম {দিন} দিন বরই পাতার গোসল; তারপর ডিটক্স ও নজরের গোসলের পর্যায় অ্যাডমিন পৃথকভাবে নির্ধারণ করবেন।', 'bath', array['10:00:00'::time]::time[], array['srg2024-ghs-003', 'srg2024-ghs-004', 'srg2024-ghs-002']::text[], false, 270),
  ('b07', 'bath', 'নজরের গোসলের অডিও', 'নজরের গোসলের আগে/পরে যাচাইকৃত বদনজরের অডিও অন্তত {মিনিট} মিনিট শুনবেন। অডিওটি আলাদাভাবে লিংক করুন।', 'bath', array['10:00:00'::time]::time[], array['sukun-ruqyahbd-evil-eye', 'srg2024-c04-t014', 'srg2024-ghs-002']::text[], false, 280),
  ('b08', 'bath', 'বরই পাতার গোসলের অডিও', 'বরই পাতার গোসলের আগে/পরে যাচাইকৃত সিহর হিবশী অডিও {মিনিট} মিনিট শুনবেন। অডিওটি আলাদাভাবে লিংক করুন।', 'bath', array['10:00:00'::time]::time[], array['sukun-ruqyahbd-sihr-hibshi', 'srg2024-c04-t015', 'srg2024-ghs-003']::text[], false, 290),
  ('b09', 'bath', 'আরবি মাসের মাঝামাঝি গোসল', 'আরবি মাসের মাঝামাঝি গোসলের নির্দেশনা; নির্দিষ্ট তারিখ অ্যাডমিন নিশ্চিত করবেন।', 'bath', array['10:00:00'::time]::time[], array['srg2024-c03-t027', 'srg2024-c03-t031']::text[], false, 300),
  ('u01', 'audio', 'জিনের আছর রুকইয়াহ', 'অনুমোদিত জিনের আছরের রুকইয়াহ অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-jinn', 'srg2024-c04-t012']::text[], true, 310),
  ('u02', 'audio', 'আয়াতুল হারক অডিও', 'অনুমোদিত আয়াতুল হারক অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-harq', 'srg2024-c04-t013']::text[], true, 320),
  ('u03', 'audio', 'কিতাল অডিও', 'অনুমোদিত কিতাল অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-qital-tadmir', 'srg2024-c04-t022']::text[], true, 330),
  ('u04', 'audio', 'শিফা–সাকিনা অডিও', 'অনুমোদিত শিফা–সাকিনা অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-shifa-sakina', 'sukun-ruqyahbd-shifa', 'srg2024-c04-t021', 'srg2024-c04-t026']::text[], true, 340),
  ('u05', 'audio', 'খুরুজ অডিও', 'অনুমোদিত খুরুজ অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-khuruj', 'srg2024-c04-t024']::text[], true, 350),
  ('u06', 'audio', 'বদনজর Evil Eye অডিও', 'অনুমোদিত বদনজরের অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-evil-eye', 'srg2024-c04-t014']::text[], true, 360),
  ('u07', 'audio', 'সিহর হিবশী অডিও', 'অনুমোদিত Sihr Hibshi অডিও {মিনিট} মিনিট শুনবেন। প্রকাশিত অডিও লিংক করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-sihr-hibshi', 'srg2024-c04-t015', 'srg2024-c04-t016']::text[], true, 370),
  ('u08', 'audio', 'আট সূরার রুকইয়াহ', 'নির্ধারিত আট সূরার রুকইয়াহ শুনবেন; প্রকাশিত রেকর্ডিং নির্বাচন করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-eight-surah']::text[], true, 380),
  ('u09', 'audio', 'তিন কুল রুকইয়াহ', 'প্রকাশিত তিন কুলের রুকইয়াহ অডিও শুনবেন; পাঠক/লাইসেন্স যাচাই করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-three-kul', 'quran:112', 'quran:113', 'quran:114']::text[], true, 390),
  ('u10', 'audio', 'আয়াতুল কুরসির রুকইয়াহ', 'প্রকাশিত আয়াতুল কুরসির রুকইয়াহ শুনবেন; পাঠক/লাইসেন্স যাচাই করুন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-ayatul-kursi', 'srg2024-qur-005', 'srg2024-aml-005']::text[], true, 400),
  ('u11', 'audio', 'ইদরিস আবকার তিলাওয়াত', 'নির্দিষ্ট সূরা/আয়াতের অনুমোদিত তিলাওয়াত প্রকাশিত লাইব্রেরি থেকে বেছে নিন।', 'audio', array['21:00:00'::time]::time[], array[]::text[], true, 410),
  ('u12', 'audio', 'আহমাদ আল আজমী তিলাওয়াত', 'নির্দিষ্ট তিন কুল/আয়াতুল কুরসির অনুমোদিত তিলাওয়াত প্রকাশিত লাইব্রেরি থেকে বেছে নিন।', 'audio', array['21:00:00'::time]::time[], array['sukun-ruqyahbd-ajmy', 'quran:112', 'quran:113', 'quran:114', 'srg2024-qur-005']::text[], true, 420),
  ('u13', 'audio', 'সিরিয়াল অডিও সেশন', 'নির্বাচিত অডিওগুলো ধারাবাহিকভাবে প্রতিটি {মিনিট} মিনিট করে, দিনে {বার} বার শুনবেন; প্রতিটি প্রকাশিত অডিও যুক্ত করুন।', 'audio', array['09:00:00'::time, '21:00:00'::time]::time[], array[]::text[], true, 430),
  ('x01', 'special', 'বিয়ের জন্য বিশেষ আমল', 'সূরা মুমতাহিনা, সূরা কাসাসের ২৪ নং আয়াত ও সূরা ফুরকানের ৭৪ নং আয়াতের প্রেসক্রিপশনে উল্লেখিত ব্যবহার যাচাই করুন।', 'amal', array['21:00:00'::time]::time[], array['quran:60', 'quran:28', 'quran:25']::text[], false, 440),
  ('x02', 'special', 'ইয়া ফাত্তাহু তাসবীহ', 'প্রতি নামাজের পরে নির্ধারিত তাসবীহ {বার} বার পাঠ; মূল নির্দেশনা যাচাই করুন।', 'amal', array['05:15:00'::time, '13:30:00'::time, '16:45:00'::time, '18:15:00'::time, '20:00:00'::time]::time[], array[]::text[], false, 450),
  ('x03', 'special', 'শিশুর হেফাজতের আমল', 'শিশুর জন্য নির্বাচিত আয়াতের পাঠ/ফুঁ দেওয়ার খসড়া; নির্দিষ্ট আয়াত ও সংখ্যা দায়িত্বপ্রাপ্ত ব্যক্তি যাচাই করবেন।', 'amal', array['20:30:00'::time]::time[], array['srg2024-c02-t005', 'srg2024-c04-t008']::text[], false, 460),
  ('x04', 'special', 'স্বামী/স্ত্রীর সহায়ক আমল', 'পরিবারের সদস্যের জন্য ব্যক্তিগতভাবে নির্ধারিত মাসনুন আমল; আসল প্রেসক্রিপশন অনুযায়ী সংশোধন করুন।', 'amal', array['21:00:00'::time]::time[], array[]::text[], false, 470),
  ('x05', 'special', 'মাথায় হাত রেখে আমল', 'মাথায়/ব্যথার স্থানে হাত রেখে নির্দিষ্ট আয়াত পাঠের খসড়া; প্রয়োগ, সংখ্যা ও সময় যাচাই করুন।', 'amal', array['21:30:00'::time]::time[], array[]::text[], false, 480),
  ('x06', 'special', 'পানিতে ফুঁ দিয়ে পান', 'নির্দিষ্ট যাচাইকৃত আয়াত পড়ে পানিতে ফুঁ দিয়ে পান করার খসড়া; স্বাস্থ্যগত উপযোগিতা ও পরিমাণ যাচাই করুন।', 'amal', array['07:30:00'::time]::time[], array['srg2024-sup-001', 'srg2024-c03-t004']::text[], false, 490),
  ('x07', 'special', 'হিজামা/কাউন্সেলিং পরামর্শ', 'হিজামা বা কাউন্সেলিং সম্পর্কিত অ্যাডমিন পরামর্শ; চিকিৎসা-সংশ্লিষ্ট সিদ্ধান্ত কেবল যোগ্য ব্যক্তির অনুমোদনে।', 'amal', array['11:00:00'::time]::time[], array['srg2024-sup-006', 'srg2024-c03-t009']::text[], false, 500),
  ('x08', 'special', 'পুনরায় পরামর্শ ও ফলোআপ', '{দিন} দিন পর অগ্রগতি জানিয়ে দায়িত্বপ্রাপ্ত পরামর্শদাতার সঙ্গে যোগাযোগ করুন।', 'amal', array['11:00:00'::time]::time[], array[]::text[], false, 510)
on conflict (id) do nothing;
