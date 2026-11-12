# Bulk template import and reminders (2026-11-09)

Owner request: an admin or raqi must be able to add many amal and supplement
items for a patient in one click and switch on reminders, using the 51 official
Sukun templates as the main resource. The old one-action-at-a-time path is
replaced.

## Where it lives

| Screen | Button | What happens |
| --- | --- | --- |
| Admin → patient detail (bottom bar) | "আমল ও রিমাইন্ডার যোগ করুন" | Bulk picker → patient care plan updated, approved and published with reminders |
| Admin → plan builder (draft) | "টেমপ্লেট থেকে আমল যোগ করুন" | Same importer, adds into the open draft |
| Admin → user and routine | "আমল ও রিমাইন্ডার যোগ করুন" | Bulk picker → active user routine with fixed daily times |
| Member/patient → My Routines | "উপকরণ থেকে রিমাইন্ডার চালু করুন" | Library tab only → own routine with reminders, asks for notification permission |

The picker (`app/lib/features/care_plans/presentation/bulk_template_import_screen.dart`)
has two tabs: **Sukun templates** (51, admin only) and **all library
resources** (published, linkable; routines use public items only). Each
category has "সব বাছুন". Selecting a row shows editable reminder times,
quick number chips for `{বার}/{দিন}/{মিনিট}`, an optional "how many days"
duration (care plans only), and an audio/surah link for templates that need one
(a published match is suggested automatically).

## Several content items per reminder (2026-11-09)

One reminder can carry several library items (up to 16, the server limit),
for example "আয়াতুল কুরসি ও ফালাক–নাস" links the Ayatul Kursi text, Surah
Falaq, Surah Nas and both ruqyah audios. Selecting a template pre-links every
item listed for it in `officialTemplateResourceRefs`
(`app/lib/features/care_plans/domain/bulk_template_import.dart`). Each item is
a chip the admin can remove, and "আরও কন্টেন্ট যোগ" adds more from the library.

- Links use stable CMS slugs or canonical `quran:N` chapters. A missing,
  unpublished or staff-only item is skipped, never invented.
- 40 of the 51 templates have curated links (checked against the Production
  library on 2026-11-09). The rest (a04, a08, a09, a10, a11, u11, u13, x02,
  x04, x05, x08) name a dua, recitation or count the paper prescription
  decides, or have no matching library item yet, so the admin picks.
- Every linked item is saved on each reminder time of that row.

## Templates are edited in the app, no deploy (2026-11-10)

Owner request: content changes must show at once instead of waiting 10 to 25
minutes for a web deploy.

- The 51 templates now live in `care_templates` (Super Admin only RLS). The
  picker loads them on open; the code list in
  `official_prescription_template_catalog.dart` is only the offline fallback
  and can not be edited.
- In the picker each template has a pencil button and there is a "নতুন
  টেমপ্লেট যোগ করুন" button. The editor changes category (new only), title,
  instruction (with `{বার}`/`{দিন}`/`{মিনিট}` buttons), default times,
  ordered content links (CMS slugs or `quran:N`, never UUIDs), "needs
  content" and "show in list" (hide instead of delete).
- Saves go through `admin_save_care_template` (validated, audited with the
  old and new row). New ids take the next number of the category letter
  (a, s, b, u, x). Imported plans keep their own copy, so editing a template
  never rewrites an existing plan.
- Migration `supabase/migrations/20261110120000_care_templates_admin_editable.sql`,
  tests `supabase/tests/care_templates_admin_editable_test.sql`.
- Deploy time: the post-merge web deploy no longer repeats the tests that the
  PR and main CI already ran on the same commit (about 9 minutes saved).

## Full content, review step and live switches (2026-11-10)

Owner request: every template must carry the content it names, in both forms
when both exist; the admin must check and edit everything in one place before
importing; and running reminders must be switchable from the person's account.

- **Text and audio together.** `officialTemplateResourceRefs` now links, for
  each recitation a template names, the text (Arabic ayat or canonical surah)
  and the audio of the same recitation. Examples: s01 (water) links the water
  guide, Fatiha text and audio, Ayatul Kursi text (`srg2024-qur-005`) and
  audio, the three Quls as surahs and audio, and the primary ruqyah ayat
  section with the common ruqyah audio. s02 links the Sihr, Shifa, Harq and
  Qital ayat sections each with its audio.
- **Three audios unlocked for patients.** Owner decision: Qital-Tadmir, Khuruj
  and Ayatush Shifa audios moved from `staff_only` to `assigned_only`. They
  stay out of public Resources; a patient can play them only when they are on
  that patient's approved plan. Routines (public items only) still skip them.
- **Dhikr templates wait for the dhikr counter.** a04 Tasbih-e-Fatemi, a08
  Durood, a09 Istighfar and x02 Ya Fattahu get no library link. They are
  listed in `officialTemplateDhikrRefs`; the planned dhikr counter will open
  the matching dhikr from the reminder. a10, a11, u11, u13, x04, x05 and x08
  still need the admin to pick, because the paper prescription decides.
- **Rows ticked before the library loads** now receive their content when it
  arrives (previously they could stay empty).
- **Review step.** "দেখে নিন ও এডিট" opens one list with every chosen row:
  times (edit/add/remove), counts, duration, linked content, a
  **notification name** box and (care plans) a reminder on/off switch. The
  final button imports and turns reminders on.
- **Notification name.** Stored as `plan_actions.notification_title` (care
  plans) and the existing `personal_routine_actions.notification_title`
  (routines). Owner decision: the phone shows this name. Blank uses the row
  title. Web push stays generic because the server never sends patient text.
- **Name box everywhere a reminder is set (2026-11-10).** The same box is in
  the template editor (`care_templates.notification_title`, the default for
  every import of that template; blank uses the template title) and in the
  care plan action editor (saved through `set_draft_action_notification_title`).
  Import fills each row's box with the template's name; the admin can still
  change it for one person.
- **Live switches.** Patient detail → "চলমান রিমাইন্ডার" and Admin → user and
  routine → "চলমান রিমাইন্ডার (অ্যাডমিনের দেওয়া)" list running reminders with a
  switch each. A switch saves at once through
  `admin_set_plan_action_reminder` / `admin_set_user_routine_action_reminder`
  (Super Admin checked in the database, audited, no new plan version). The
  published-action guard trigger allows only the `reminder_enabled` flag to
  change, and only inside that function. Times, names and instructions still
  change through a new plan version. A user's self-added routines are refused.
- Migration: `supabase/migrations/20261110090000_reminder_names_and_live_toggles.sql`,
  tests: `supabase/tests/reminder_names_and_live_toggles_test.sql`.

## Decisions (owner, 2026-11-09)

- **Default times, editable.** Each template carries suggested times
  (`officialTemplateDefaultTimes` in
  `app/lib/features/care_plans/domain/bulk_template_import.dart`). The admin sees
  and can change every time before importing. Times after prayers are fixed
  approximations, not calculated prayer times.
- **Import is the approval.** Pressing import saves rows as `approved` with
  `reminder_enabled = true` and publishes the plan. This is not an AI path, so
  the AI no-auto-publish rule is unaffected.
- **Counts are never guessed.** Templates with `{বার}/{দিন}/{মিনিট}` block
  the import until the admin picks a number. The server also rejects unfilled
  placeholders.
- **Existing work is kept.** If a live plan exists, a new version is copied
  from it and the copied rows (already live and approved) are re-approved. If
  an open draft holds unreviewed rows (for example AI suggestions), they are
  not approved silently: the new rows are saved and the admin is taken to the
  builder to finish review and publish.
- **User routines start active.** `admin_import_user_routine_reminders`
  creates an active routine with `schedule_kind = 'fixed'`, unlike
  `admin_create_user_routine` (inactive until the owner opts in). The user
  still controls device notifications and can pause or delete the routine.
  Each import is audited as `personal_routine.delegated_reminders_imported`.

## Backend

- Patient path: existing audited RPCs only (`create_draft_care_plan`,
  `save_plan_action`, `replace_draft_action_resources`,
  `replace_draft_action_quran_surahs`, `publish_care_plan`).
- Routine path: new migration
  `supabase/migrations/20261109090000_admin_bulk_import_user_routine_reminders.sql`
  (additive SECURITY DEFINER function, Super Admin checked in the database,
  up to 120 rows per import). Tests:
  `supabase/tests/admin_bulk_import_user_routine_reminders_test.sql`.

**Production:** both migrations were applied to Production on 2026-11-09
(see `docs/PRODUCTION_ENVIRONMENT.md`). The patient path needs no migration.

## Prescription PDF and two sections

Patient detail (summary tab) and the admin user/routine screen show a
**prescription card**:

1. **Sukun's amal and supplements**: the active care plan's approved actions
   plus routines an admin set (found through the audit log by
   `admin_get_user_routine_overview`). A **PDF** button downloads it at any
   time, and the success message after a bulk import offers "PDF নিন".
2. **Self-added**: active routines the patient or user created for
   themselves. Shown only when there is at least one, so it takes no space
   otherwise.

The PDF (`app/lib/features/care_plans/data/prescription_pdf.dart`) is A4 with
the official logo, name and date. Items are grouped by section (আমল,
সাপ্লিমেন্ট, গোসল, অডিও ও তিলাওয়াত, বিশেষ আমল, অন্যান্য); under each section
title the items run on as one paragraph, not one per line. Reminder times are
not printed. Repeats of one item at several times print once. Pages are drawn
with Flutter's text engine and the bundled Bangla font, then embedded as
images, because PDF text engines break Bangla conjuncts. The text is therefore
not selectable in the PDF.

## Known limits

- Device reminders for personal routines are scheduled in a rolling window
  (maximum 48 pending), refreshed whenever the app opens. Large imports still
  remind correctly but only a few days ahead at a time.
- Web reminders only fire while the tab is open (existing limitation).

## Permanent template home (2026-11-12)

Owner request: the 51 templates are the "Sukun Life official templates", the
blueprint for every import, and need their own place to edit, add and remove.

- Admin home → পরিচালনা → **সুকুন অফিসিয়াল টেমপ্লেট** (`/admin/care-templates`,
  `app/lib/features/care_plans/presentation/care_templates_admin_screen.dart`).
- Lists every template by category with its default times and content count;
  search and category filter. Tap to edit (same editor as the picker: title,
  instruction, times, reminder name, ordered content links). Example: remove
  `quran:2` from "প্রতিদিন সূরা বাকারা শ্রবণ" and later imports link only the
  Sudais audio.
- "নতুন টেমপ্লেট" (or the + on a category) adds one; ids follow the category
  letter, up to 99 per category.
- "সরান" hides a template (is_active = false, audited) after confirmation; the
  "সরানো" tab shows removed ones with "ফিরিয়ে আনুন". Nothing is hard-deleted.
- The import picker keeps its pencil shortcut; both save through
  `admin_save_care_template`.
