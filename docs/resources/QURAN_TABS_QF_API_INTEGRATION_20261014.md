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

## 14 October implementation update — 114-surah staged fallback

- The existing two-tab Flutter UI remains the only implementation; `/resources/quran` is Quran first, Ruqyah Ayat second.
- The dedicated Quran Foundation server proxy remains the only transport. If `QF_ENV=production` and approved Quran Foundation credentials are configured, the official API is used exclusively. In development/staging mode (default/prelive), the Edge Function reads the public **Al Quran Cloud** REST API for all 114 surah names and fetches Uthmani Arabic, the `bn.bengali` (Muhiuddin Khan) translation, and `ar.alafasy` recitation on demand.
- The fallback is explicitly identified as `provider: Al Quran Cloud`, never presented as Quran Foundation content. The UI shows the provider and the returned translation/recitation edition credits. Existing source-book 101 article records stay separate and are excluded from generic Articles & Guides browsing without deletion.
- No full Quran copy or recitation bundle is stored in Flutter, Supabase, or GitHub; playback uses constrained HTTPS audio hosts. The 101 previously imported editorial cards remain in staging.
- Quran Foundation's prelive includes only Al-Fatihah and Al-Baqarah; full official QF access still requires their separate production approval. See https://api-docs.quran.foundation/docs/quickstart/ .
- Fallback API and content terms: https://alquran.cloud/terms-and-conditions . Translators and reciters retain their rights. The public provider has soft rate limits and must be reviewed for large-scale/commercial traffic before production. Do not use the fallback as unreviewed permanent production infrastructure.
- **Bengali-script pronunciation** remains intentionally unavailable until a genuine editor-approved, appropriately licensed source is identified.
- CI checks, staging Edge deployment, hosted Web deployment and browser / guest / patient smoke checks are separate milestones. Production Supabase, `sukunlife.com` and Android/iOS packages must remain unchanged.
