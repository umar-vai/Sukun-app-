# Ruqyah Ayat Bengali Reference & Meaning Preview — 16 October 2026

## Evidence and scope

- Production `content_items` currently includes 101 published `srg2024-qur-*` editorial passages. 99 have a `surah_number` and `ayah_number` (start only), 2 do not. None has `ayah_end_number` or an approved `bangla_text` / `translation`.
- The Arabic excerpts are source-book editorial passages and can cover more than one canonical ayah. **A start number is not a verified end verse.**
- Formerly the UI displayed a card list index and book paragraph label `আয়াত/অংশ NN`, which could be mistaken for Quran numbering. It now removes these UI-generated indices and shows a Bengali surah / ayah citation **only** when the existing metadata and a curated name both exist.
- Expanding a card first displays any approved stored Bengali meaning, if available. Otherwise, where a start reference is known, Flutter asks the existing `quran-content` Edge Function for the corresponding chapter/page, matches **exactly** `surah:startingAyah`, checks that the translation language is Bengali, and shows **only the first cited verse's Bengali translation**. The translator/edition and provider are visible. A clear notice prevents that meaning from being misrepresented as the translation of the whole source-book excerpt.
- Users may open the existing canonical Quran reader for the complete surah with verse-by-verse Bengali translations.
- No reference => no fabricated surah title or numbered verse. Missing/unavailable API translation => an honest unavailable state; Arabic remains unchanged.
- Quran providers, translation copyrights, caching and fair-use constraints remain as documented in `QURAN_TABS_QF_API_INTEGRATION_20261014.md`. The client retains nothing permanently and does not mutate source content.

## Acceptance

- Tests check that editorial paragraph indices are not shown as ayah numbers and that missing/unknown references do not invent surah names.
- CI must pass Dart formatting, Flutter analyzer/unit/widget tests and Web build.
- Browser QA must check An-Nas (`srg2024-qur-013`), Ayatul Kursi (`srg2024-qur-005`) and non-ayah introduction (`srg2024-qur-001`) in the real guest application.
- Translating all 101 full editorial passages requires separately verified explicit end verse boundaries, Arabic/source alignment and translation permission. This first-ayah preview must not be described as a completed full-excerpt translation import.

## Unchanged

- Production/Staging Supabase data and migrations, auth/RLS, patients, the main `sukunlife.com` website, old dashboard, APK/AAB, DNS and future app subdomain.
