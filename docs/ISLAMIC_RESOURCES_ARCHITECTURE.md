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
- AI may assist with non-canonical metadata only when the Super Admin checks it before choosing Publish Now; this check is not a separate approval state.

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

## 12. Direct publication workflow

Required normal CMS lifecycle:

```text
draft
→ Publish Now
→ published
```

Published content may be unpublished back to draft or archived. This direct
workflow applies to every content type, including Qur'an and Hadith. The
server-verified Super Admin is the final publisher; there is no self-approval
or mandatory verification step in the normal admin UX.

Implemented workflow constraints:

- Flutter requests audited `save_content_item` and `transition_content_item`
  database functions; RLS and a server-verified Super Admin role remain
  authoritative.
- Content is saved as `draft`, then an authorized Super Admin may publish it
  directly. Legacy `review` / `verified` rows remain valid and may also move
  directly to `published`.
- Published content is immutable until it is explicitly unpublished. Editing
  a published resource first unpublishes it to draft so history is preserved.
- Historical verification fields and records remain for backward compatibility,
  but verification state no longer blocks publication.
- `content_reviews` and `admin_audit_logs` store admin-only lifecycle history
  separately from patient-readable content. Publish, unpublish, and archive
  events record the responsible Super Admin and timestamp.
- Canonical Qur'an/Hadith rejects `generative_ai` as a source even in draft form.
  Publication still requires approved source reference and edition metadata;
  Qur'an requires sourced Arabic text, Bangla text requires its translation
  source, and Hadith requires collection, book, and number. These are source
  integrity validations, not an approval workflow.

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

- Create resource
- Select content type
- Assign category/subcategory
- Add Arabic/Bangla/translation/reference fields
- Add external media/PDF URL
- Set visibility
- Save draft
- Preview
- Publish Now
- Unpublish
- Archive
- Search/filter existing resources
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

**Qur'an/Hadith content must never be treated as generic AI-generated copy. Canonical text and references must come from approved, traceable sources with complete metadata. The authorized Super Admin publishes directly and remains accountable through audit history.**
