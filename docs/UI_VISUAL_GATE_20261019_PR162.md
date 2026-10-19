# Sukun UI acceptance — Oct 19 responsive/theme gates

> Status: **IN PROGRESS / NOT APPROVED FOR RELEASE**. This report supersedes any interpretation that historical `VISUAL_ACCEPTANCE_GATE.md` checkboxes prove the newly requested UI has been manually re-accepted.

## Source and work under review

- PR #159: Dark-mode Quran playing-ayah legibility and instant Arabic/Bengali reading size.
- PR #161: Optional Calm Teal / Twilight Plum palettes, persistent Settings choice, 900-logical-pixel centered desktop Quran reader. Sukun Blue remains default.
- PR #162: Consolidated resource Back control into the bottom nav, audio dock clearing navigation, theme-aware resource/navigation tokens.
- The user supplied an Al-Baqarah dark-mode screenshot in which the first verse was effectively unreadable and two bottom navigation layers appeared.
- No production patient data, migrations, Edge deployments, DNS, `sukunlife.com`, native APK/AAB/IPA or legacy dashboard changes are in scope.

## Verified code/accessibility finding

Sukun Blue `#0F9BD7` and white `#FFFFFF` have contrast about **3.14:1**, below WCAG 4.5:1 standard-body-text target. Retain the blue background but set its normal button label foreground to Night Navy `#0D2B45` (about **4.62:1**). Alternative palettes use white text on sufficiently dark Teal `#146F63` or Plum `#67418F` (about **6.03:1** and **7.69:1**, respectively).

## Automated acceptance matrix

New source/widget tests check:

- [x] Static formula and code target for palette text/selected-state contrast; require 4.5:1.
- [x] Automated render cases authored: Sukun Blue, Calm Teal, Twilight Plum × Light/Dark × 360/430/768/1280 logical-pixel widths (24 cases). No overflow/exception and semantic Resource icon badge foreground.
- [x] Synthetic Member / Patient / Admin deep-link navigation tests authored at 360/430/1280 widths; one bottom navigation with inline Back instead of a duplicated Back/Home strip.
- [x] Chrome workflow amended to run the above plus existing audio dock/role navigation cases.
- [ ] Re-verified all new source tests and Chrome jobs on **latest** commit after this change.
- [ ] Confirm latest PR Flutter Web build artifact exactly matches final committed revision.

The above is test-source/code evidence; browser tests do not establish full manual pixel-level accessibility review or authenticated production role E2E.

## Manual and operational gates still open

- [ ] Open the PR's compiled Flutter app on mobile and desktop at representative 360, 390, 430, 768, 1280 logical-pixel widths; review screenshots of Guest Home, Al-Baqarah playing/unselected ayat, Resource search/detail, Settings Theme/Font, expanded/collapsed player and navigation.
- [ ] Review all three palettes in both Light and Dark mode for text, controls, icons, dialogs, contrast and long Bangla/Arabic wrapping. Automated token contrast alone cannot validate screenshots.
- [ ] Real browser keyboard, safe-area, portrait/landscape and player overlay clickthrough.
- [ ] With **authorized synthetic staging accounts**, exercise Member, Patient A/B (including access denial), and Admin session, resource and navigation behavior. No real patient credentials in screenshots or public test clients.
- [ ] Reviewer screenshot sign-off for every affected screen. User's prior screenshot contradicts older blanket visual-acceptance checkmarks.
- [ ] PR dependency order: #159 → #161 → #162; each must pass required CI/Chrome/Web build after any retarget or merge.
- [ ] Main Pages deployment only after approved merge and exact SHA HTTP verification at previously configured `https://app.sukunlife.com/`. Do not infer deployment from an artifact or CI.
- [ ] Production patient login hardening warning from earlier backend audit remains an independent security release gate.

## Test environment limitation

An existing GitHub Actions Flutter Web artifact (guest/local backend build from PR #162) was downloaded to an isolated local environment, but the local Chromium policy returned `ERR_BLOCKED_BY_ADMINISTRATOR` for local HTTP and file URLs. **No local visual screenshot or interactive E2E pass is claimed.** The GitHub Actions browser-platform tests are the automated web verification currently available. If a real interactive browser QA environment becomes available, finish the checklist before removing draft/release blockers.

## State legend

`Source changed` != `CI passed` != `Web built` != `Pages deployed` != `Browser manually reviewed`. Leave production `main`, existing `sukunlife.com`, and current Pages site untouched until gates are met.

## Staging-connected Quran browser artifact run — 20 October 2026

- Browser acceptance requires **real Flutter Web**, not separate guest HTML. The PR's existing Web Preview workflow is amended to compile the same Flutter source with isolated staging's **publishable** key on PR builds. Default-branch Pages deployment remains production-backed and unchanged.
- Existing Guest home screenshot captures are retained. Added direct Guest `/resources/quran/2` screenshot capture in **Light and Dark** at 430×932 and 1280×800; artifacts must be inspected before visual approval.
- This capture is public scripture only. It is **not** Patient/Admin browser acceptance and does not prove that the *playing* Ayah, audio controls, keyboard or modal variants pass manual accessibility review.
- PR #162 temporarily targets `main` to trigger isolated PR CI. **Retarget to #161 after verification**; do not merge this stacked feature directly into main.
- Previous Chrome/widget suites for #159/#161/#162 passed on their prior source heads. All modified workflow code is pending new exact-commit CI/Flutter Web verification.
