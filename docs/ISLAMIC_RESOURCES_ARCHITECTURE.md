# Islamic Resources Architecture — Sukun Life App

This document defines the dedicated Islamic Resources area of the Sukun Life app. Codex and all developers must follow it when implementing public/patient resource features.

## 1. Product separation

The app has two major product areas that must remain conceptually separate:

1. **Patient Care** — prescription, care plan, reminders, completion, progress, adherence.
2. **Islamic Resources** — Qur'an, Hadith, Dua & Azkar, Ruqyah resources, books/PDFs, articles/guides, audio and video.

Do not mix the general Islamic library into the patient's medical/care-plan workflow.

A patient may still receive a resource inside a care-plan task by linking the existing resource to that task. The content itself should not be duplicated.

Example:

```text
Islamic Resources Library
        ↓
"Ayatul Kursi" content item
        ↓ linked by content_id
Patient Plan Action
        ↓
Today's Task
```

## 2. Main Resources hub

The patient/guest app must have a dedicated top-level **Resources / ইসলামিক রিসোর্স** destination.

Recommended sections:

```text
Islamic Resources
├── Qur'an
├── Hadith
├── Dua & Azkar
├── Ruqyah
├── Books & PDFs
├── Articles & Guides
├── Audio
└── Video
```

The exact visual layout may evolve, but the information architecture above must remain clear and easy to browse.

Recommended entry experience:

- Search bar
- Featured/assigned resources
- Category cards
- Recently added / popular / recommended sections where useful
- Filter by type/category/language
- Bookmark/favorite capability when included in scope

## 3. Qur'an section

The Qur'an area may include:

- Surah list
- Surah details
- Ayah list
- Selected ayat collections
- Ruqyah ayat collection
- Arabic text
- Approved Bangla translation
- Reference metadata
- Audio recitation links when approved/licensed

### Qur'an integrity rules

- Canonical Arabic Qur'an text must come from a verified, approved source.
- Never let generative AI create, paraphrase, rewrite, or "correct" canonical Arabic Qur'an text.
- Store surah number, ayah number, and source/version metadata.
- Translation text must identify the approved translation/source where practical.
- Any tafsir/explanation must be clearly separated from Qur'an text.

Suggested metadata:

```text
surah_number
surah_name_ar
surah_name_bn
ayah_number
arabic_text
translation_bn
translation_source
reference_text
verification_status
verified_by
verified_at
```

## 4. Hadith section

The Hadith area may include:

- Topic-wise Hadith
- Daily Hadith
- Search
- Collections/categories
- Arabic text where approved
- Bangla translation
- Source/reference
- Grading/status when available from the approved source

### Hadith integrity rules

- Do not publish unsourced Hadith.
- Store collection/source reference and Hadith number where available.
- Do not let AI invent or fabricate Hadith wording, source, grading, narrator, or numbering.
- AI may assist with non-canonical metadata only when the Super Admin checks it before submitting the resource for review.

Suggested metadata:

```text
collection_name
book_name
hadith_number
arabic_text
translation_bn
narrator
reference_text
grade
source_url
verification_status
verified_by
verified_at
```

## 5. Dua & Azkar

Recommended subcategories:

- Morning Azkar
- Evening Azkar
- Sleep
- Waking
- Travel
- Protection
- Distress/anxiety related authentic duas
- Daily Masnun Dua
- Other approved categories

Each item should support where relevant:

- Arabic text
- Bangla transliteration if approved
- Bangla translation
- Source/reference
- Repeat count only when supported by the approved source/instruction
- Audio link if available

Do not invent a repetition count or religious instruction.

## 6. Ruqyah section

Recommended subcategories:

- Ruqyah Ayat
- Ruqyah Audio
- Self-Ruqyah Guide
- Protection resources
- Evil Eye related approved resources
- Jinn related approved resources
- Sihr/black-magic related approved resources
- General spiritual-wellness resources

Content must remain within Sukun Life's approved editorial/religious guidance.

The resource library is not a substitute for the patient's personalized plan.

## 7. Books & PDFs

Support:

- Sukun Life books
- Approved third-party books/resources where rights permit
- PDF guides
- Book → chapter structure when needed
- External PDF URLs by default

Store metadata rather than uploading large files into the database itself.

Suggested fields:

```text
title
author
publisher
summary
cover_url
pdf_url
language
copyright_or_permission_note
visibility
status
```

## 8. Articles & Guides

Support editorial content such as:

- Islamic wellness
- Ruqyah education
- Self-care guidance
- Spiritual development
- Sukun Life educational articles

Admin must be able to create, edit, preview, publish, unpublish, and archive these from Admin Mode.

## 9. Audio and Video

Audio/video may be browsed through their own filters/categories and may also appear inside Qur'an, Ruqyah, Dua, Guide, or Patient Plan contexts.

Preferred media sources:

- direct audio URL
- approved CDN/object-storage URL
- YouTube via supported official playback
- external MP4 URL where appropriate

Do not extract YouTube audio into raw MP3.

## 10. Reuse resources inside patient plans

The same resource must be reusable across the app.

Example:

```text
content_items.id = ruqyah_audio_123

Public Resources page
        ↓ same content_id
Patient A Plan Action
Patient B Plan Action
Patient C Plan Action
```

Do not create duplicate copies of the same resource for each patient.

Use a relation such as:

```text
plan_action_resources
- plan_action_id
- content_item_id
- usage_note
```

The patient plan may add patient-specific instructions, timing, count, duration, or visibility without modifying the canonical resource itself.

## 11. Content visibility

Supported visibility values should include:

```text
public
patient_only
assigned_only
staff_only
```

Examples:

- Public Hadith article → `public`
- Resource available only after patient login → `patient_only`
- Specific prescribed audio → `assigned_only`
- Practitioner-only reference material → `staff_only`

## 12. One-step publication workflow (owner decision, 2026-11-13)

The Sukun Life owner replaced the earlier draft → review → verify → publish
lifecycle with a single step. Migration
`supabase/migrations/20261113150000_one_step_resource_publishing.sql`.

```text
Add or edit → Publish / Update → published
```

- The editor has one action. A new resource is published on save; an edit of
  a published resource stays published. There is no draft, review queue,
  preview step, source sheet or rights/licensing field in the admin UI.
- For Qur'an and Hadith, the saving Super Admin is recorded as the verifier
  (`verified_by`, `verified_at`) at publication. The owner decided this
  attestation replaces separate source verification; there are no required
  source, edition, translation-source or rights fields any more.
- Still enforced in the database: server-verified Super Admin role, audited and
  idempotent requests, no `generative_ai` canonical source, Qur'an needs a
  valid Surah/Ayah and its Arabic text, Hadith needs collection, book and
  number, HTTPS-only links.
- Existing source/rights values are kept when a resource is edited; they are
  simply no longer asked for.
- A resource can be hidden (unpublished) or archived from the list, and
  published again from there. Legacy `draft`/`review`/`verified` rows show as
  "hidden".
- `content_reviews` and `admin_audit_logs` keep the history of every publish,
  hide and archive.
- A recitation-only item uses the `audio` content type; the `quran` type is
  for Ayah text.

Recommended fields:

```text
status
verification_status
source_type
source_reference
source_url
verified_by
verified_at
created_by
updated_by
published_at
archived_at
```

## 13. Admin Mode requirements

Super Admin must be able to manage the Islamic Resources library from the same Flutter app.

Admin functions:

- Choose a resource type, then Add
- Fill only the fields for that type (text or link) and Publish
- Tap a resource to edit; Update publishes the change
- Hide, publish again or archive from the list
- Search and filter (all, published, hidden, archived)
- Link an existing resource to a patient's plan

The admin UI must clearly distinguish canonical religious text/reference fields from ordinary editorial description fields.

## 14. Search and discovery

Resource search should eventually support:

- title
- Bangla title
- category
- tags
- Surah/Ayah reference
- Hadith collection/reference
- content type

Do not expose staff-only or assigned-only content through public search.

## 15. Security and data access

Supabase RLS/API authorization must enforce resource visibility.

Guest:
- may read only `public` + `published`

Patient:
- may read `public`, allowed `patient_only`, and resources explicitly assigned to that patient

Super Admin:
- may manage content according to server-verified role

Never rely only on hidden UI controls for authorization.

## 16. UI/brand requirements

The Islamic Resources section must use the same official Sukun Life brand system as the rest of the app:

- Sukun Blue `#0F9BD7`
- Deep Tide `#0A70A8`
- Night Navy `#0D2B45`
- Mist `#E8F5FC`
- Saffron `#F2C45A` as a limited accent

Do not turn this section into a separate green/gold generic Islamic theme.

Use:

- Anek Bangla for Bangla display/headline
- Hind Siliguri for Bangla UI/body
- Tiro Bangla only where appropriate for Qur'anic/Hadith display text
- Poppins for English UI

## 17. Implementation priority

The dedicated Islamic Resources hub belongs in the Content CMS/resource phase, after the core patient-care flow is stable.

However, the data model must be designed early enough that patient actions can link to `content_items` without later migration chaos.

Minimum first release of the Resources hub should include:

- Resources home/category hub
- Qur'an category structure
- Hadith category structure
- Dua & Azkar
- Ruqyah
- Books/PDF
- Articles/Guides
- Audio/Video filters
- Search/filter basics
- Source/reference fields
- Admin create/edit/publish/archive
- Resource-to-patient-plan linking

## 18. Non-negotiable rule

**Qur'an/Hadith content must never be treated as generic AI-generated copy. Since 2026-11-13 the publishing Super Admin's one-step save is the verification of record (owner decision), and every publish stays accountable through audit history.**

## 19. Clinical links to the public Quran catalog (2026-10-18)

The public 114-surah reader is sourced through the `quran-content` Edge Function, not through `content_items`. The Admin action picker loads that same chapter catalog and stores only the validated chapter number and display title in `plan_action_quran_surahs`. Patient Today and My Plan open the existing `/resources/quran/{number}` reader. No verse, translation, or recording is copied into a clinical plan.

The 101 reviewed Ruqyah Ayat editorial excerpts already live in `content_items`; they remain linked by their existing IDs. The Admin picker now shows them under Quran and Ruqyah, with their editorial status made explicit. Its chapter catalog must contain all 114 distinct numbers before it offers canonical chapter selection. If the API is unavailable or incomplete, the picker keeps CMS resources available and clearly reports the missing chapter catalog.

`plan_action_quran_surahs` is RLS scoped to a permitted plan action, writable only for a draft by a database-verified Super Admin, immutable after publication, and audited through its replacement RPC. A new draft version copied from an older approved plan retains these links for fresh review. Keep the backend migration ahead of the Flutter web deployment because patient and Admin queries include this relation.

## 20. Structured resource library and Self-diagnosis (2026-11-22)

Migration `20261122090000_structured_resource_library.sql` adds:

- **Ruqyah audio library.** Seven CMS categories under `ruqyah`
  (`ruqyah-lib-topic`, `-reciters`, `-other`, `-special`, `-hibshi`, `-short`,
  `-more-reciters`). The Ruqyah page keeps the Self-Ruqyah Guide (four
  chapters) and Ruqyah Ayat, then lists these groups. Audio that is not in a
  group appears under "আরও অডিও". Older title-based topic links still open.
- **Daily masnun amal.** 90 dua in 18 categories (`dua-azkar-ma-01` to `-18`)
  shown in four navigation groups before the original three. Each dua stores
  Arabic (`arabic_text`), pronunciation (`transliteration`), meaning
  (`bangla_text`), reading rule (`summary`), hadith reference
  (`reference_text`) and, where available, its audio link. The detail page
  shows the reading rule and reference for dua and amal; editor notes are
  still filtered out.
- **PDF shelf.** A `pdf` Resources section lists `type = 'pdf'` items; the
  library PDFs are in `pdf-ruqyah`.
- **Self-diagnosis.** A `self-diagnosis` Resources section shows the published
  self-assessment tests and the guides in `self-diagnosis-guide`. Tests live in
  `self_assessment_tests`, `self_assessment_questions` and
  `self_assessment_result_bands`. A `total` test sums option scores and shows
  the band with the highest `min_score` reached. A `dimensions` test (the
  general test) sums a score per dimension, takes the first rule in `rules`
  whose bounds all hold, and shows the outcome with exactly those flags, or
  `fallback_bn`. Results are guidance only; every test carries a "not a
  medical diagnosis" note.
- **Ordering.** `content_items.sort_order` orders items inside the library
  groups, dua groups and the PDF shelf. A Super Admin sets it from the content
  editor ("তালিকায় ক্রম").
- **Admin editing.** Library items are edited in the existing content editor
  (the dua editor now also edits title, pronunciation, reading rule,
  reference and audio link). Tests are edited at `/admin/self-assessment`:
  text, publish state, questions and option scores, result bands, and the
  rule/outcome JSON for a dimension test.
- Media stays link-based. Source attribution is not shown in the app, per the
  owner's decision of 2026-11-22.

