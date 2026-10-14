# Quran / Ruqyah Ayat tabs — Web-first staging integration (14 October 2026)

## Navigation
- /resources/quran opens a two-tab screen: **কুরআন** first, **রুকইয়াহ আয়াত** second.
- Canonical Quran: 114 chapters and paginated Arabic verses fetched on demand, no bulk Quran copies stored in Supabase or bundled in Flutter.
- Selected Ruqyah Ayat: exact staging `srg2024-qur-001`–`101` published editorial articles, read with existing anonymous RLS. These are **not** full canonical verses: 99 annotated ayah ranges/excerpts and 2 introductions.
- Generic Articles & Guides search/list excludes this slug group. Admin CMS and direct item links remain intact, preserving audit/provenance and plan links.

## Quran Foundation Content API
- One Supabase Edge Function `quran-content` handles `chapters` and paginated `verses`; the Flutter client must not know the client secret.
- Configure **Edge Function secrets** in *staging*: `QF_CLIENT_ID`, `QF_CLIENT_SECRET`, `QF_ENV=prelive`. Do **not** put them in GitHub Pages build-time dart-defines or any public source.
- After obtaining Quran Foundation **production approval**, configure production credentials in **staging** and `QF_ENV=production` to access all 114 surahs. Their prelive dataset contains only Surahs 1 and 2.
- Arabic `text_uthmani`, a Bengali translation selected from `resources/translations?language=bn`, recitation ID from `resources/recitations`, optional Latin-script transliteration, and audio URLs come from the official API. API resources and audio can differ by environment. Bengali *script* pronunciation remains deliberately absent until a licensed/editor-reviewed transliteration source is available; never auto-transliterate holy text and label it authoritative.
- The function should be used as a public read-only service only with appropriate proxy rate limits, Quran Foundation usage permission, and monitoring before large-scale access. No permanently cached copyrighted audio/translation.
- Run Deno checks, Flutter formatter/analyzer/tests, staging function smoke with Quran Foundation credentials, and both Guest/Patient role checks before merging.
- Browser staging preview route: `https://umar-vai.github.io/Sukun-app-/#/resources/quran` (hash routing needs independent verification).

## Not performed automatically
- No production Supabase content changes. Production currently has **zero** of these 101 imported items.
- No changes to `sukunlife.com`, legacy dashboard, native packages, DNS, or app subdomain.
- CI green, Pages deployed, and browser verified are separate gates.
