# Qur'an Arabic rendering, Bangla pronunciation, and draft publication gate (2026-10-12)

## Scope
- Full production app continues using the same Flutter codebase and existing GitHub Pages URL.
- Render Arabic verbatim with a normal **Noto Naskh Arabic** font, RTL and readable line spacing. Do not change any Arabic text.
- Place an expandable `বাংলা উচ্চারণ দেখুন` section immediately beneath each Arabic passage across resource detail, canonical Qur'an Surah/collection reading screens, and admin preview.
- Only show transliteration previously supplied by the approved CMS. Missing/transliteration-not-checked displays an explicit unavailable state. Do not automatically invent Bengali transliteration, and treat pronunciation only as an aid to learning, not a substitute for Arabic/tajwid.
- Existing Bangla meaning and translation stay separate from pronunciation.

## Read-only staging content inventory
As inspected 2026-10-12 on staging (`qacklgqvxvjjzsimjoip`): **178 Draft records**:
- 128 staff-only article/editorial items, including 101 extracted source Qur'an fragments still awaiting ayat identification/canonical verification.
- 24 staff-only Dua drafts (15 have an existing transliteration, 9 do not).
- 8 staff-only Amal drafts.
- 17 staff-only publisher audio drafts.
- 1 patient-only **QA-only private article** that must never be bulk published.

None of these are verified published canonical `quran` entries. Production (`vydfafumxptanpkmtrpr`) has a separate `quran` entry in `review` with `pending` verification, not eligible for publication.

## Publication gate
User authorizes publishing drafts on their behalf; this is not proof that drafts have complete source/citation or acceptable audience. Bulk status writes as a database superuser would bypass app audit logs and server-verified Super Admin identity, so **do not** perform them. Every eligible item must follow the existing audited `save_content_item` / `transition_content_item` workflow, and must be appropriate for its designated audience:
- `draft -> review -> verified -> published` for canonical Qur'an/Hadith;
- `draft -> review -> published` for general resources, once evidence, permissions, metadata, linked media and visibility are checked.
- Keep the 101 unverified Qur'an fragments as staff-only editorial drafts until exact Surah/Ayah matches are verified; do not relabel or auto-publish as canonical.
- Keep QA/test and private patient records entirely out of bulk publication.
- Do not mistake `staff_only + published` for public visibility.
- Publisher audio permission/source must be checked for each item, and web-playability tested before publication.

## Quran.com support
Quran Foundation API terms (2026-10-11) permit controlled display with restrictions, original Qur'an text must be preserved, and their translation, media, sync and attribution conditions must be followed. It is **not** a blanket right to copy Quran.com recordings or translation into a permanent dataset. Integrate any Quran.com API using server-held credentials, not GitHub Pages browser secrets. Validate every Bengali pronunciation against an approved and credited source before content publication.

## Verification scope
- Widget tests for Arabic and pronunciation expansion, missing source pronunciations and narrow/mobile viewport.
- Flutter format, analyze, test, Web build, browser/role regressions, staging gate and verified Pages SHA after merge.
- No schema migration, production content publish, internal dashboard changes, sukunlife.com changes, native APK/AAB packaging or auto-generated scriptural text.
