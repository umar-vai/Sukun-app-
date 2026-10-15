# Sukun Life Production web — Quran, Dua and Google recovery (2026-10-15)

## Evidence from live Production

- Existing GitHub Pages runs the **single real Flutter app** against Supabase `vydfafumxptanpkmtrpr`; the main site `sukunlife.com` and old dashboard remain untouched.
- Production `quran-content` v1 gave HTTP **503** for chapter requests: Quran Foundation Production credentials are not configured; the previous handler explicitly forbade use of the attributed public 114-surah source in Production.
- Production content database retains **23 published/public duas and 8 published/public amals**, all without `category_id`. Flutter mistakenly required Dua category prefixes, filtering those records out.
- An authenticated **read-only CI probe of Production GoTrue public Auth settings** reported **`external.google=false`**. Prior `preview-build.json` deliberately had `google_oauth:false`. Do not claim that Google sign-in is already functional.

## Changes

- Stream Quran 114 surahs, Arabic, dynamically credited Bengali edition and recitation from [Al Quran Cloud](https://alquran.cloud/terms-and-conditions) when the complete authorized Quran Foundation Production integration is not configured; maintain no mirrored Quran corpus and preserve source attribution. Respect free API fair use and audio copyrights. Use Quran Foundation when approved credentials exist.
- Match approved, public `dua` / `amal` records with null categories within the **Dua & Azkar section only**; other categories and RLS unchanged. Original source/rights metadata and status unchanged.
- Fail the latest Pages build if production Quran live smoke cannot obtain exactly **114 chapters**, 7 verses of Al-Fatiha and 6 of An-Nas with Arabic/Bengali/audio fields.
- Google sign-in UI shows an explicit disabled provider-setup notice when Production is unconfigured. Never offer a misleading active login button; Google cannot be fixed by Flutter alone.

## User/authorized operator task required for real Google OAuth

1. In [Production Supabase](https://supabase.com/dashboard/project/vydfafumxptanpkmtrpr/auth/providers), enable Google with a valid Google Cloud OAuth 2.0 **Web Client ID & Client Secret** via Supabase Auth provider settings. Do not paste client secrets in GitHub, Flutter, chat or code.
2. In the Google Cloud OAuth client, authorized redirect: `https://vydfafumxptanpkmtrpr.supabase.co/auth/v1/callback`. Authorized origin `https://umar-vai.github.io`. Configure consent-screen audience and test users if in Testing mode.
3. In Production Supabase Auth URL settings, allow Site URL/redirect `https://umar-vai.github.io/Sukun-app-/` (not `sukunlife.com`). Future dedicated app subdomain requires explicit DNS approval and updated allowlist.
4. In GitHub repository Actions **Variables**, set `SUKUN_PRODUCTION_ENABLE_GOOGLE_OAUTH=true` only after the provider is active and redirects verified. This is a public feature flag, **not** an OAuth secret. Existing Pages build must be rebuilt through approved `main` CI and deployed before button becomes functional.
5. Verify one real Google OAuth browser redirect/session via a **dedicated synthetic Member account**. Confirm role provisioning is `member` only; no Patient/Admin grant. Test unauthorized Patient A → Patient B access denied; do not skip Admin approval/patient privacy gates.
6. Keep email/password member signup, phone/email OTP toggles off until their own verification. Never use real clinical data or share passwords.

## Backend release gate

After CI + PR merged, deploy compatible `quran-content` Edge source to **Production only**, then verify Edge ACTIVE version, Pages build SHA and a real GET/POST provider smoke. CI build or successful deployment alone is not equivalent to authenticated Browser E2E.

## Privacy boundaries

Supabase publishable key may be browser-visible; **never** expose service-role/Gemini, OAuth client secret, private patient info or production credentials. No changes to existing `sukunlife.com`, legacy Admin dashboard, patient records or APK/AAB packaging.
