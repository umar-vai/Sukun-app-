# Staging reconciliation — 101 editorial Qur'an resources (2026-10-14)

## Scope & findings

- Source dataset: 6,236 Uthmani ayah lines from `nuqayah/quran-text`, Git blob `fcc214311897921d08bbc56879b82aa38328a5f3`; 114 surah offsets independently checked against `semarketir/quranjson/source/surah.json`.
- Staging-only editorial target: 101 `srg2024-qur-*` items, originally from the owner-authorized *Self Ruqyah Guide* (2024). The original Arabic strings are not replaced or copied to GitHub.
- 99 items already have proposed Qur'an references; all 99 are aligned to the referenced surah/ayah or subset using Unicode-normalized character alignment. 96 reach similarity ≥0.95; two reach 0.9444/0.9479 and have Quran.com crosschecks at 17:81 and 4:76; one (17:49) is 0.8667 due to source-script spelling/hamza encoding and is independently crosschecked at Quran.com/17/49.
- 21 items encode multi-ayah ranges in `reference_text` but omit `ayah_end_number`. The migration sets exact end numbers on these 21 only.
- 15 are ayah **excerpts**, not whole Arabic verse strings. Their metadata may name the containing ayah, but the reader must not imply the visible excerpt is a verbatim, complete ayah.
- `srg2024-qur-001` is an Isti'adhah+Basmala introduction, and `srg2024-qur-047` is an isolated Basmala; neither is assigned a false unique surah/ayah number.
- All 101 titles are updated to communicate reference reconciliation or non-ayah introduction. Full Arabic, translations, media and rights metadata remain unchanged.
- A versioned audit table stores reference, normalized similarity score, excerpt status, source blob SHA and original Arabic MD5, not patient information.

## Critical distinction

**This is reference-metadata reconciliation, NOT a canonical Qur'an text certification.**

Indo-Pak orthography, verse dividers, diacritics and excerpt segmentation differ from Tanzil Uthmani text. The audit comparison deliberately removes search-only punctuation/diacritics, but the actual Arabic text remains verbatim. `verification_status` stays `pending` on the 99 matched items and `not_required` on the two introductions; the CMS `review`/`published` statuses and visibility remain unchanged. This prevents an automated script from claiming verse-perfect canonical Arabic or publishing unsafe content.

A later canonical-content workflow must source a licensed, verbatim Qur'an text edition (with attribution), independently review Arabic rendering, and ensure Quran AI/audio matching resolves the correct surah/start/end and exact excerpt/full-verse semantics before patient use.

## Guardrails

- Migration runs only in a Staging DB with **exactly 101 matching records**, otherwise aborts (except on a clean disposable CI database with zero items).
- It compares each original Arabic MD5, original surah and first ayah before changing metadata; concurrent edits cause rollback.
- It never changes `status`, `visibility`, `verification_status`, `arabic_text`, assigned patient plans or the app's production backend.
- Audit data is inaccessible to `anon` and unprivileged `authenticated` roles by default. All changes are versioned in GitHub and deployed separately to staging.
- Source references: https://quran.com/17/49, https://quran.com/17/81, https://quran.com/4/76, https://tanzil.net/docs/Text_License.
