-- Preview-only sample data. Loaded into a throwaway local Postgres that has
-- the repository migrations applied, so every row is checked against the
-- real constraints, then exported to JSON for the in-browser mock backend.
-- Contains NO canonical Qur'an/Hadith text and NO real patient data.

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'admin@preview.sukun'),
  ('00000000-0000-4000-8000-0000000000b1', 'patient@preview.sukun'),
  ('00000000-0000-4000-8000-0000000000c1', 'member@preview.sukun');

insert into public.profiles (id, display_name, locale) values
  ('00000000-0000-4000-8000-0000000000a1', 'প্রিভিউ অ্যাডমিন', 'bn'),
  ('00000000-0000-4000-8000-0000000000b1', 'রাশেদ হাসান', 'bn'),
  ('00000000-0000-4000-8000-0000000000c1', 'নুসরাত জাহান', 'bn')
on conflict (id) do update set display_name = excluded.display_name, locale = excluded.locale;

insert into public.user_roles (user_id, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'super_admin'),
  ('00000000-0000-4000-8000-0000000000b1', 'patient'),
  ('00000000-0000-4000-8000-0000000000c1', 'member')
on conflict do nothing;

insert into public.patients (id, user_id, patient_code, full_name, phone, status, created_by, created_at) values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000b1', 'SL-1001', 'রাশেদ হাসান', '01700000001', 'active', '00000000-0000-4000-8000-0000000000a1', now() - interval '40 days'),
  ('10000000-0000-4000-8000-000000000002', null, 'SL-1002', 'ফারজানা আক্তার', '01700000002', 'active', '00000000-0000-4000-8000-0000000000a1', now() - interval '25 days'),
  ('10000000-0000-4000-8000-000000000003', null, 'SL-1003', 'মাহমুদুল করিম', '01700000003', 'active', '00000000-0000-4000-8000-0000000000a1', now() - interval '12 days'),
  ('10000000-0000-4000-8000-000000000004', null, 'SL-1004', 'সাবরিনা ইসলাম', null, 'inactive', '00000000-0000-4000-8000-0000000000a1', now() - interval '60 days'),
  ('10000000-0000-4000-8000-000000000005', null, 'SL-1005', 'তানভীর আহমেদ', '01700000005', 'active', '00000000-0000-4000-8000-0000000000a1', now() - interval '3 days');

insert into public.prescriptions (id, patient_id, raw_text, session_date, visibility, created_by, created_at) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   E'নমুনা প্রেসক্রিপশন (প্রিভিউ)\n১. প্রতিদিন সকালে নির্ধারিত অডিও শুনবেন।\n২. ঘুমানোর আগে সকাল-সন্ধ্যার আমল করবেন।\n৩. সপ্তাহে তিন দিন হালকা হাঁটা।\n৪. এক সপ্তাহ পর ফলো-আপ সেশন।',
   current_date - 14, 'patient', '00000000-0000-4000-8000-0000000000a1', now() - interval '14 days'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
   E'অভ্যন্তরীণ নোট (শুধু স্টাফ): রোগী রাতে ঘুমের সমস্যার কথা বলেছেন। পরের সেশনে আবার দেখতে হবে।',
   current_date - 14, 'staff_only', '00000000-0000-4000-8000-0000000000a1', now() - interval '14 days'),
  ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002',
   E'নমুনা প্রেসক্রিপশন (প্রিভিউ)\n১. প্রতিদিন সন্ধ্যায় নির্ধারিত অডিও।\n২. রাতে ঘুমের আগে আমল।',
   current_date - 5, 'patient', '00000000-0000-4000-8000-0000000000a1', now() - interval '5 days');

insert into public.content_categories (id, name, name_bn, slug, sort_order, created_by, updated_by) values
  ('30000000-0000-4000-8000-000000000001', 'Ruqyah', 'রুকইয়াহ', 'ruqyah', 1, '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1'),
  ('30000000-0000-4000-8000-000000000002', 'Dua & Azkar', 'দোয়া ও যিকির', 'dua-azkar', 2, '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1'),
  ('30000000-0000-4000-8000-000000000003', 'Articles & Guides', 'প্রবন্ধ ও গাইড', 'articles-guides', 3, '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1');

-- Titles only. Bodies are clearly labelled sample copy, never religious text.
insert into public.content_items (id, type, category_id, title, title_bn, slug, summary, body, visibility, status, published_at, created_by, updated_by, created_at) values
  ('40000000-0000-4000-8000-000000000001', 'guide', '30000000-0000-4000-8000-000000000003', 'Self Ruqyah Guide', 'সেলফ রুকইয়াহ গাইড', 'self-ruqyah-guide',
   'নিজে নিজে রুকইয়াহ করার ধাপগুলো (প্রিভিউ নমুনা)।', E'এটি প্রিভিউয়ের জন্য নমুনা লেখা। আসল অ্যাপে এখানে যাচাই করা গাইড থাকবে।\n\nধাপ ১: নিয়ত ঠিক করা\nধাপ ২: নির্ধারিত সময় বেছে নেওয়া\nধাপ ৩: নিয়মিত থাকা',
   'public', 'published', now() - interval '20 days', '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '20 days'),
  ('40000000-0000-4000-8000-000000000002', 'article', '30000000-0000-4000-8000-000000000003', 'Sleep and Evening Routine', 'ঘুম ও সন্ধ্যার রুটিন', 'sleep-and-evening-routine',
   'ভালো ঘুমের জন্য সন্ধ্যার অভ্যাস (প্রিভিউ নমুনা)।', E'এটি প্রিভিউয়ের জন্য নমুনা লেখা।\n\nসন্ধ্যার পর স্ক্রিন কম ব্যবহার করুন, নির্দিষ্ট সময়ে ঘুমাতে যান।',
   'public', 'published', now() - interval '18 days', '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '18 days'),
  ('40000000-0000-4000-8000-000000000003', 'amal', '30000000-0000-4000-8000-000000000002', 'Morning and Evening Adhkar', 'সকাল-সন্ধ্যার আমল', 'morning-evening-adhkar',
   'প্রতিদিনের আমলের তালিকা (প্রিভিউ নমুনা, মূল টেক্সট নেই)।', E'প্রিভিউতে মূল আরবি টেক্সট দেখানো হচ্ছে না। আসল অ্যাপে যাচাই করা উৎস থেকে আসবে।',
   'public', 'published', now() - interval '16 days', '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '16 days'),
  ('40000000-0000-4000-8000-000000000004', 'article', '30000000-0000-4000-8000-000000000001', 'Understanding Ruqyah', 'রুকইয়াহ কী ও কেন', 'understanding-ruqyah',
   'রুকইয়াহ সম্পর্কে প্রাথমিক ধারণা (প্রিভিউ নমুনা)।', E'এটি প্রিভিউয়ের জন্য নমুনা লেখা।',
   'public', 'published', now() - interval '10 days', '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '10 days'),
  ('40000000-0000-4000-8000-000000000005', 'guide', '30000000-0000-4000-8000-000000000003', 'Patient Follow-up Checklist', 'ফলো-আপ চেকলিস্ট', 'patient-follow-up-checklist',
   'শুধু রোগীদের জন্য (প্রিভিউ নমুনা)।', E'এটি প্রিভিউয়ের জন্য নমুনা লেখা।\n\n১. প্রতিদিনের কাজ চিহ্নিত করুন\n২. সমস্যা হলে নোট রাখুন',
   'patient_only', 'published', now() - interval '9 days', '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '9 days'),
  ('40000000-0000-4000-8000-000000000006', 'article', '30000000-0000-4000-8000-000000000003', 'Draft: Family Support', 'খসড়া: পরিবারের সহায়তা', 'draft-family-support',
   'রিভিউয়ের অপেক্ষায় থাকা খসড়া (প্রিভিউ নমুনা)।', E'খসড়া লেখা।',
   'public', 'draft', null, '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '2 days'),
  ('40000000-0000-4000-8000-000000000007', 'article', '30000000-0000-4000-8000-000000000001', 'In Review: Home Environment', 'রিভিউতে: ঘরের পরিবেশ', 'in-review-home-environment',
   'রিভিউ চলছে (প্রিভিউ নমুনা)।', E'রিভিউ চলছে।',
   'public', 'review', null, '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '1 day');

insert into public.care_plans (id, patient_id, prescription_id, version, name, start_date, status, published_at, published_by, created_by, created_at) values
  ('50000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 1, 'প্রথম মাসের কেয়ার প্ল্যান', current_date - 14, 'active', now() - interval '14 days', '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', now() - interval '14 days');
insert into public.care_plans (id, patient_id, prescription_id, version, name, start_date, status, created_by, created_at) values
  ('50000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000003', 1, 'সন্ধ্যার রুটিন প্ল্যান (খসড়া)', current_date, 'draft', '00000000-0000-4000-8000-0000000000a1', now() - interval '5 days');

-- Insert actions as draft (trigger blocks rewriting non-draft), then approve.
insert into public.plan_actions (id, care_plan_id, type, title, instruction, count_target, duration_minutes, frequency_rule, time_window, exact_time, start_date, sort_order, review_status, reminder_enabled, created_by) values
  ('60000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 'amal', 'সকালের আমল', 'ফজরের পর সকাল-সন্ধ্যার আমল পড়বেন।', null, 15, '{"type":"daily","interval":1}', 'morning', '06:30', current_date - 14, 0, 'approved', true, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000001', 'ruqyah', 'রুকইয়াহ অডিও শোনা', 'মনোযোগ দিয়ে পুরো অডিও শুনবেন।', null, 30, '{"type":"daily","interval":1}', 'afternoon', '14:00', current_date - 14, 1, 'approved', true, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000003', '50000000-0000-4000-8000-000000000001', 'instruction', 'হালকা হাঁটা', '২০ মিনিট খোলা জায়গায় হাঁটবেন।', null, 20, '{"type":"daily","interval":1}', 'evening', '17:30', current_date - 14, 2, 'approved', false, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000001', 'amal', 'সন্ধ্যার আমল', 'মাগরিবের পর আমল করবেন।', 3, null, '{"type":"daily","interval":1}', 'evening', '18:45', current_date - 14, 3, 'approved', true, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000005', '50000000-0000-4000-8000-000000000001', 'instruction', 'ঘুমের আগে নোট লেখা', 'দিনে কেমন লাগল দুই লাইনে লিখে রাখবেন।', null, 5, '{"type":"daily","interval":1}', 'night', '22:00', current_date - 14, 4, 'approved', false, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000011', '50000000-0000-4000-8000-000000000002', 'ruqyah', 'সন্ধ্যার অডিও', 'প্রতিদিন সন্ধ্যায় শুনবেন।', null, 25, '{"type":"daily","interval":1}', 'evening', null, current_date, 0, 'approved', true, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000012', '50000000-0000-4000-8000-000000000002', 'amal', 'ঘুমের আগের আমল', null, null, null, '{"type":"daily","interval":1}', 'night', null, current_date, 1, 'needs_review', false, '00000000-0000-4000-8000-0000000000a1');

-- Clinical-integrity triggers block edits to published plans; the seed
-- inserts the links directly as if they existed before publication.
set session_replication_role = replica;
insert into public.plan_action_resources (plan_action_id, content_item_id, usage_note, sort_order, created_by) values
  ('60000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000003', 'এই তালিকা অনুযায়ী পড়বেন।', 0, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000001', 'শোনার আগে গাইডটা একবার পড়ে নিন।', 0, '00000000-0000-4000-8000-0000000000a1'),
  ('60000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000002', null, 0, '00000000-0000-4000-8000-0000000000a1');
set session_replication_role = origin;

insert into public.universal_announcements (id, title, body, status, created_by, published_at, created_at) values
  ('70000000-0000-4000-8000-000000000001', 'প্রিভিউ নোটিশ', 'এটি প্রিভিউয়ের জন্য একটি নমুনা ঘোষণা। আসল অ্যাপে অ্যাডমিন এখান থেকে সবাইকে নোটিশ পাঠাতে পারবেন।', 'published', '00000000-0000-4000-8000-0000000000a1', now() - interval '1 day', now() - interval '1 day'),
  ('70000000-0000-4000-8000-000000000002', 'খসড়া: রমজান প্রস্তুতি সেশন', 'খসড়া নোটিশ।', 'draft', '00000000-0000-4000-8000-0000000000a1', null, now() - interval '2 hours');

insert into public.personal_routines (id, owner_user_id, title) values
  ('80000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000c1', 'আমার দৈনিক রুটিন'),
  ('80000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000b1', 'আমার রুটিন');

insert into public.personal_routine_actions (id, routine_id, owner_user_id, title, notification_title, notes, resource_provider, content_item_id, schedule_kind, local_time) values
  ('81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000c1', 'সকালের আমল', 'সকালের আমলের সময়', null, 'cms', '40000000-0000-4000-8000-000000000003', 'fixed', '06:15'),
  ('81000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000c1', 'বই পড়া', 'বই পড়ার সময়', '১০ পৃষ্ঠা', 'manual', null, 'fixed', '21:00'),
  ('81000000-0000-4000-8000-000000000003', '80000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000c1', 'ঘুম ও সন্ধ্যার রুটিন', 'সন্ধ্যার রুটিন', null, 'cms', '40000000-0000-4000-8000-000000000002', 'manual', null),
  ('81000000-0000-4000-8000-000000000011', '80000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000b1', 'পানি পান', 'পানি পানের কথা মনে করুন', '৮ গ্লাস', 'manual', null, 'fixed', '11:00');

insert into public.routine_templates (id, title, description, status, created_by) values
  ('90000000-0000-4000-8000-000000000001', 'নতুনদের দৈনিক রুটিন', 'সহজ তিনটি কাজ দিয়ে শুরু (প্রিভিউ নমুনা)।', 'published', '00000000-0000-4000-8000-0000000000a1');
insert into public.routine_template_steps (template_id, title, sort_order) values
  ('90000000-0000-4000-8000-000000000001', 'সকালের আমল', 0),
  ('90000000-0000-4000-8000-000000000001', 'দশ মিনিট হাঁটা', 1),
  ('90000000-0000-4000-8000-000000000001', 'ঘুমের আগে আমল', 2);
