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
