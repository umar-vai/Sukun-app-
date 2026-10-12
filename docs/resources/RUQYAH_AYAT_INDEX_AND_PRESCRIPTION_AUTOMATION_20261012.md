# Ruqyah Ayat Library and Prescription Listening Integration — 2026-10-12

## Source evidence / editorial limits
- UI section labels below were transcribed from the user's 2026-10-12 screenshot of `ayat.ruqyahbd.org`; the actual site's complete category-to-ayah mapping and audio/license terms were **not** obtainable via the public tool.
- Eight observed headings: বেসিক রুকইয়াহ, রুকইয়াহ আয়াত, রুকইয়াহ দোয়া, বদনজরের আয়াত, সিহরের আয়াত, আয়াতুশ শিফা, আয়াতুল হারক, আয়াতুল সাকিনাহ.
- These headings provide an **index blueprint only**, not source-verified collection content. Do not claim 25 Ayatul Harq verses have been imported, or publish arbitrary ayat or fake audio for an empty collection.
- The canonical Qur'an Arabic text is not a proprietary composition of a website, but a specific Bengali translation, recording, reciter performance, layout, UI assets, and the site's editorial collection may have separate rights. Obtain independently verified source editions and suitable media permission before copying protected material.

## Reuse the existing Flutter and Supabase design
- Keep `content_items` as the authoritative canonical Ayah record with `surah_number`, `ayah_number`, `ayah_end_number`, `source_edition`, `verification_status` and approvals. The current CMS refuses unverified canonical publication.
- Reuse `content_collections` for one-to-many Ruqyah collections and `content_collection_items` to order verified Ayah IDs; preserve all existing public, patient, admin, and RLS boundaries. **Do not store a duplicate copy of the Arabic text in each collection.**
- Public and patient UI shows the eight source-inspired navigation headings; a heading that has no authorized `published` collection is a non-clickable honest empty state. Ruqyah Dua uses the existing Dua/Azkar screen rather than incorrectly labeling dua as Quran.
- Each section needs a **human-reviewed source-to-canonical crosswalk** before publication: collection heading; exact numeric Quran citation/range; canonical edition and text; checked translation attribution; recitation recording and its verified verse coverage; list order; editor reviewer, proof link, and publication status.
- Do not scrape or auto-publish protected translation, publisher artwork, player code, page UI, or third-party recordings.

## AI prescription-to-action workflow (staged, human-approved)
1. Admin uploads a private prescription under the existing secured prescription intake route. Preserve only verbatim extracted instructions and timestamps.
2. Conservative AI parses *explicitly stated* read/recite versus listen actions, requested interval/clock time, duration/frequency and source evidence. It must not manufacture extra prescribed tasks or turn "read" into "listen."
3. Convert any **explicit** numeric Surah/Ayah reference to a stable canonical query like `2:255` or a precisely bounded range `2:255-257`. Bangla digits are accepted. Do not infer verses from ambiguous descriptions.
4. Resource matcher resolves that query only to matching **published, verified** canonical Qur'an content, or an **approved playable audio resource** that explicitly maps to the same Surah/Ayah/range. A Quran text item is **not** evidence that a playable audio exists. No fuzzy fallback for a numeric citation.
5. Time window or HH:mm is copied exactly from prescription. The current `time_window` model cannot represent multiple distinct windows; ambiguous cases remain `needs_review`. **Never invent a precise time based on Fajr/Maghrib or audio length.**
6. Results are candidate draft actions in the existing Admin review UI, not automatically approved patient care tasks. Authorized Admin checks content, audio availability, instruction, recurrence, time, and linkage, then approves the care plan. Existing scheduler/reminders drive patient Today once published.
7. Missing or ambiguous reference, absent approved audio, AI failure, source mismatch, CORS/browser incompatibility and multi-verse stitching **stop automatic linking** and open a review/manual path. No silent substitutions.

## Known current state / remaining work
- This PR adds navigation categories, exact numeric reference metadata/matching, parser instructions and regression tests. It does **not** ingest canonical Arabic text, copy the site's full authored collections, deploy database migrations/functions, or switch on unattended action publishing.
- Next: independently validate official complete section mappings; acquire a reliable canonical Quran source and translation terms; create reviewed staging collections and recitation metadata with RLS; ensure every playable range actually has an approved audio recording; test upload → AI draft → exact linked media → approved schedule in real Flutter Web for guest/patient/admin; confirm in browser and CI before merge/deploy.
- Native APK/AAB build and sukunlife.com updates are out of scope.
