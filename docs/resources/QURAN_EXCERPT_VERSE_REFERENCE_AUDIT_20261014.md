# Quran excerpt reference mapping — 14 October 2026

## Scope and origin

The staging Content CMS contains 101 editorial excerpts under `srg2024-qur-001` through `srg2024-qur-101`: 100 in Review, and `015` Staff-only Published. They were transcribed from **সেলফ রুকইয়াহ গাইড** and retain their original source references, scripts, status, and visibility.

Research cross-checked the excerpts against:
- Quran.com ayah pages: https://quran.com/2/255, https://quran.com/23/115, https://quran.com/37/1, https://quran.com/27/54, https://quran.com/84/1, https://quran.com/99/2, https://quran.com/17/49, https://quran.com/17/81.
- An indexed full 6,236-verse Hafs corpus, `ara-quranuthmanihaf1.txt` (Arabic without diacritics), from the public `fawazahmed0/quran-api` GitHub repository, originally credited to King Fahad Quran Complex.
- Text-specific first/last Arabic phrase matching, explicit end-of-ayah number markers from the source booklet, and targeted Quran.com cross-checks for boundary exceptions.

This procedure identifies **referenced verses**, not proof that a third-party editorial Arabic excerpt is a fully correct canonical Quran edition.

A first staging deployment attempt was correctly blocked by the existing `content_items_ayah_range` CHECK constraint: `ayah_end_number` is only permitted on `type=quran`. The migration was amended without weakening the constraint or relabeling editorial articles. No records were changed by the rejected transaction. Some records are partial ayahs, not complete canonical verses.

## Verse-boundary cross-check

Cross-checked end-of-ayah number markers in all 101 source excerpts against the proposed reference ranges. This caught and corrected two cases a phrase matcher had shortened: `027` is **14:49–50** (not merely 49), and `095` is **36:78–79** (not merely 79). The source booklet numbers the opening Al-Fatihah excerpt differently: it begins with *Alhamdulillah* marked as 1, whereas Quran.com counts Basmala as 1 and *Alhamdulillah* as 1:2; the applicable standardized mapping for `002` is **1:2–7**. All other present source end-of-ayah markers fit their mapped range.

## Safeguarded staging change

Migration `20261014093000_quran_ayat_reference_mapping.sql` supplies **99** exact editorial-reference mappings. It changes only `surah_number`, `ayah_number`, the annotated `reference_text` (preserving its original book citation and adding the explicit full ayah range), `source_url`, `verification_status='pending'`, and `updated_at`. It deliberately leaves `ayah_end_number` **NULL**: the existing `content_items_ayah_range` constraint correctly reserves that structured field for verified-type canonical `quran` items, not these `article` excerpts. It:
- Checks MD5 of each original Arabic text, the original staff-only visibility, expected editorial title, and existing Review/Staff-only Published status before touching a row.
- Leaves raw Arabic, title, original book source, rights, content type, publication status, role visibility, audio, Bengali translation/pronunciation, and patient plans entirely unchanged.
- Does **not** mark any excerpt `verified`, publish any text, or create canonical `quran` records.
- Is staging-only until further release approval and QA. A GitHub commit is not a live database migration.

## Explicit exclusions

- `srg2024-qur-001`: begins with Isti'adhah followed by Basmala. Neither is an unambiguous single canonical ayah reference *for this editorial record*. Treat as preparation text, not a matched Quran passage.
- `srg2024-qur-047`: isolated incomplete Basmala excerpt within a section. Do not infer that this excerpt represents a complete surah/ayah merely from the phrase.
- `srg2024-qur-015` (Ar-Rahman 55:33–36) is **already staff-only published**, not a new Review draft. Matching its reference does not change its publication state.

## Canonical Quran and AI gates still outstanding

1. An authorized Quran editor must confirm each excerpt's complete and accurate Arabic against the edition, not just its verse range.
2. Create distinct, appropriately licensed canonical Quran records with verified text and scoped collections; do not relabel booklet `article` fragments as `quran`.
3. Validate recitation coverage and permissions; the current Staging audio recordings have no verse range metadata.
4. Test explicit prescription citation → exact approved resource → Admin Review → Plan → Patient playback and reminder in the real Flutter Web app.
5. Do not automatically publish or assign any patient action from this source lookup.

## License boundary

Tanzil Arabic text is CC BY 3.0 with attribution/unchanged-text conditions: https://tanzil.net/docs/Text_License . Quran.com displays third-party authored translations and recitations subject to separate conditions. This metadata lookup does **not** copy those translations, recordings, or site UI; all links are references.
