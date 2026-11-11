# Home, Settings & Resources — verified delivery status (19 October 2026)

This replaces the unchecked planning snapshot with a **source / CI / hosted / manual QA** ledger. One canonical Flutter repository, no separate mock app, no automatic APK/AAB/IPA, and no modifications to `sukunlife.com` or the legacy dashboard.

## Verified release baseline

| Gate | Observed result | Evidence |
|---|---|---|
| Main source | `1ac1b8ee27f7d2f1e18bc04ce3471cbd45f47885` | Main head, merge of #157 |
| GitHub PRs #149–#157 | All merged | GitHub PR metadata |
| Main Flutter / Edge / RLS / Web CI | **PASS** on exact main SHA | [CI 39197574083](https://github.com/umar-vai/Sukun-app-/actions/runs/39197574083) |
| Real Flutter Web build and Chrome automated regressions | **PASS** | [Web run 39197939478](https://github.com/umar-vai/Sukun-app-/actions/runs/39197939478) |
| GitHub Pages deploy | **PASS**, HTTP checks on index/bootstrap/build marker for exact main SHA | Same Web run, deploy job 117886278167 |
| Observed Pages custom-domain URL | `https://app.sukunlife.com/` | Exact URL printed by verified deploy job; this is a *previously configured* destination, not a DNS change made by this task |
| Real authenticated browser role E2E | **NOT VERIFIED** | Requires synthetic Member/Patient A/Patient B/Admin, manual browser interactions and negative access testing |
| Native notification delivery / install QA | **NOT VERIFIED** | Web/Chrome build is not Android device proof |
| Production backend | Project `vydfafumxptanpkmtrpr` ACTIVE_HEALTHY; existing migrations/functions present | Read-only Supabase inspection, 19 Oct. No production backend deployment made by these UI tasks |

**Important:** A successful HTTP SHA smoke check proves deployment, not authenticated role behavior. The old `github.io/Sukun-app-/` path must not be assumed to be the current canonical URL because the Pages deployment uses a root custom domain.

## Home/navigation: implemented in merged source

- [x] **H1 / #149:** Compact location-aware Fajr/Dhuhr/Asr/Maghrib/Isha Home chart; Qibla / full prayer actions; all eight canonical resource categories; missing-location fallback.
- [x] **H2 / #151:** Show owner-scoped personal next actions together with patient-visible approved clinical tasks, attributing their distinct source. Existing test coverage includes timing, active/paused and completed states.
- [x] **H2 bugfix / #155:** Completed prayer-relative action reschedules next **local calendar day**; regression coverage for tomorrow's Fajr.
- [x] **H3 / #152:** No redundant public Resources primary tab; existing resource/deep-link paths retained, Admin CMS unchanged.
- [x] **Resources / #157:** Three collapsible Masnun Dua & Azkar navigation groups preserve the existing seven approved slugs and CMS filters without duplicates.
- [x] Main CI and Web/Chrome build green for final SHA.
- [ ] Browser **visual/manual** checks on 360px, ~430px, tablet and desktop, across Guest, Member, Patient and Admin.
- [ ] Live two-patient owner isolation and authenticated click-through / Done-Skip-Snooze refresh tested with isolated synthetic accounts.

## Settings: delivered vs not delivered

- [x] **S1 / #150:** Device-local Bengali font picker with existing Google Fonts options (Hind Siliguri, Anek Bangla, Tiro Bangla), persistence and safe unknown-value fallback.
- [x] **S1 / #153:** System/Light/Dark setting, separate Arabic and Bengali reader scales, persisted preferences, unified Settings navigation and dark-theme support.
- [x] **S1 / #156:** Real, session-guarded notification health page; browser/native permissions diagnostics; opt-in toggles for *existing* personal routine and approved patient-plan reminders; user-facing browser limitations.
- [ ] **Li Ador Noirrit** as branded default: approved font binaries are **not bundled in public source**. Confirm license/distribution and approved asset delivery first. Do not claim the font is shipped. Keep approved Arabic Quran font independent.
- [ ] **Five independent prayer-alarm opt-ins:** not implemented in #156, which intentionally avoids fake UI toggles; design real prayer-event scheduling, permission/reboot/timezone tests before claiming delivery.
- [ ] Real visual contrast/typography QA for dark mode and small mobile screens.
- [ ] Device-native exact alarm permissions, battery optimization, killed-app/reboot delivery and notification tap-to-action tested physically.
- [ ] Browser-background / closed-tab remote Push delivery independently verified; an open-tab timer is not equivalent.

## Audio/offline

- [x] **A1 / #154:** Shared player has cancellable bounded 5/15/30/60-minute sleep timer, pause on expiry, cancellation on stop/dispose; unit tests included.
- [ ] Saved Favorites and user playlists: not proven complete by this work package.
- [ ] Rights-cleared, app-private offline downloads, integrity/queue/sync/device QA.
- [ ] Real browser playback/seek/pause interaction and long-running timer behavior (especially background throttling).

## Backend/security and release blocks

- Latest Security Advisor still reports **9 callable SECURITY DEFINER functions** for review and **Leaked Password Protection disabled**; these are **warnings, not proof of a data breach**. [Advisor guide](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- **Verified production/staging limiter mismatch:** production `patient-sign-in` Edge Function is ACTIVE **v7** and its deployed handler does **not** call `check_patient_login_rate_limit`, even though the matching limiter table and RPC already exist in production. Staging `patient-sign-in` ACTIVE **v2** contains that limiter call, table and RPC. This is an **open login-abuse hardening gate**, not evidence of a patient-data breach. Do not deploy GitHub handler blindly: independently test trusted IP provenance, synthetic 401/413/429 flow, compatibility and rollback first. Platform `verify_jwt=false` must be evaluated with explicit handler authorization.
- No patient records were read or mutated during this status reconciliation.
- No Supabase migration, Edge deployment, DNS setting, GitHub Pages destination or existing public website was changed by this documentation update.
- Five-prayer alerts, Li Ador license/assets, role-authenticated browser E2E, native device delivery and UI visual sign-off are **OPEN**. Do not label the full S1 work package or a public mobile release “finished”.

## Next acceptance sequence

1. Open the currently observed `https://app.sukunlife.com/` Flutter app in a real browser and test Guest/Home, settings, grouped Dua navigation, eight resource routes, theme, font choice, audio timer at representative screen widths.
2. Using **synthetic, authorized accounts only**, test Member/Patient/Admin and two-patient access-denial, sign-in/callback/session persistence, clinical task completion and notification consent with real backend.
3. Separately obtain the Li Ador redistribution/build permission and branded assets; implement five-prayer opt-ins only with truthful platform-specific scheduling and tests.
4. Perform native QA / APK or release packaging **only on explicit approved gate**, and preserve current public `sukunlife.com` throughout.
