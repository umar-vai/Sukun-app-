# Home & Settings Delivery Tracker — 19 October 2026

Scope: approved Ruqyah-reference gap plan v1.1 and later explicit request for extensive Settings and multiple selectable Bangla fonts. Source: one existing Flutter app. No parallel preview, APK/AAB/IPA, or public-website changes.

## Status conventions
- [x] Implemented in proposed code (not automatically deployed)
- [ ] Pending implementation or release gate
- CI / Pages / browser verification must be reported independently.

## Work Package H1 — Compact five-prayer chart & eight resources
- [x] Replace large Home prayer and Qibla cards with compact Fajr/Dhuhr/Asr/Maghrib/Isha strip, using existing prayer calculation and location/method preferences.
- [x] Keep Qibla and complete prayer schedule as compact actions.
- [x] Safe location-missing setup CTA; no made-up prayer times.
- [x] Render all eight categories directly from canonical `resourceSections`, including previously missing Quran and Hadith.
- [x] Add widget regression expectations for compact chart and eight sections.
- [ ] CI green; Web build green; exact-SHA Pages deployment; browser QA 360/430/desktop and role flows.

## Work Package H2 — Unified next tasks
- [ ] Patient-approved clinical next task(s) and owner-only personal routine next task(s), separately attributed and sorted by real next scheduled occurrence.
- [ ] Make task state refresh correctly on Done/Skip/Snooze and on plan changes, including empty/complete status.
- [ ] Guest sees no private tasks. Member sees only own routines. Patient sees only own plans and routines.
- [ ] RLS and cross-user negative tests.

## Work Package H3 — Remove redundant public Resources tab
- [ ] Remove public/Member/Patient `উপকরণ` from primary bottom navigation **only after** Home routes/search are tested.
- [ ] Keep all `/resources/*` and `/patient/resources/*` routes, search, PDF/audio reader, resource links and deep links.
- [ ] Do not change Super Admin resource CMS navigation/workspace.

## Work Package S1 — Complete Settings
- [ ] Group Appearance (Auto/Light/Dark, color-safe contrast), Reader (Arabic and Bengali independent text size), Language/Fonts, Prayer times, Notifications/diagnostics, Audio and offline-storage preferences.
- [ ] Add user-selectable Bengali fonts (at minimum approved Li Ador Noirrit as branded default, plus appropriately licensed accessible Bengali alternatives); persist per-user/per-device preferences with safe guest behavior.
- [ ] Bundle/check the provided Li Ador Noirrit font assets through the authorized project source. The current GitHub tree has no checked-in TTF/OTF; **do not falsely declare the font shipped until its approved bytes are present**.
- [ ] Preserve verified Arabic Naskh typography for Quran text and never regenerate canonical text.
- [ ] Five-prayer independent notification opt-ins, notification-permission diagnostics and safe web/native platform fallbacks.

## Work Package A1 — Audio & offline
- [ ] Sleep timer, saved Favorites and personalized playlists; reuse global audio controller, resume/speed/repeat.
- [ ] Verify rights for streaming/offline before implementing private in-app download.
- [ ] Validate browser/native differences and avoid promises of browser-closed reminders.

## Gates
- **GitHub**: a pull request is not a merged change.
- **Backend**: SQL committed != applied migration; Edge Function code committed != live deployment.
- **Preview**: CI passed != Web built != Pages deployed != role-based browser QA.
- **Production**: do not change `https://sukunlife.com`, legacy dashboard, production patient records, or DNS as part of this work.
- No native packages without explicit authorization.
