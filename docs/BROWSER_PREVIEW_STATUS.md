# Sukun Life — Functional Flutter Web Preview (web-first)

## Current verified state — 10 October 2026 (supersedes historical notes below)

- Main commit `354eeb92` passed GitHub CI (Flutter, local RLS/pgTAP, Edge Functions, Web build and Chrome regressions). The subsequent Pages deployment reported success and confirmed the exact HTTP commit marker.
- Its deployed preview manifest used `backend_mode: local`; **authenticated** staging Patient/Admin/Member testing is **not yet complete**.
- PR #27 merged the role-aware Flutter source and existing Member auth code into `main`. PRs #28–#32 delivered subsequent browser and Patient offline reliability fixes. Legacy stacked PRs #19/#20/#23 remain open but their historical open state alone does not mean that all code is absent from main.
- The Sukun Supabase account has **one active production project and no staging branches**. Staging Member schema/provider activation is **not deployed**; production must stay isolated.
- The next change adds opt-in **staging-only** feature flags for Member Signup, Email OTP, Phone OTP and Google OAuth in the existing Pages pipeline. They remain **off** until clean staging, providers, RLS and synthetic-role/browser QA are approved. See [Staging Preview Activation](STAGING_PREVIEW_ACTIVATION_2026_10_10.md).
- Browser UI and authenticated transaction success are distinct: CI and HTTP smoke checks do not prove a real authenticated end-to-end interaction.

> Below this update, older sections reflect the 9 October planning baseline and should be read as historical, not live deploy evidence.


## Deployment target and separation

- Source: `umar-vai/Sukun-app-` (the **existing application repository**, not a new demo repository).
- This repository reports GitHub Pages support (`has_pages=true`). The current `gh-pages` branch's HTML sets `/Sukun-app-/` as the base href, and the workflow reads GitHub's Pages `base_path` via `actions/configure-pages@v5` for the merge-triggered build. The live URL and hosting source must still be confirmed through Settings → Pages and a successful deployment; never treat a guessed `github.io` address as verified.
- `umar-vai/Sukun-landing-` is a separate campaign landing page; do not overwrite it.
- `sukunlife.com`, the existing dashboard, and `app.sukunlife.com` are NOT deployment targets.
- There is no automatic Android APK/AAB/IPA build.

## What runs

The actual `SukunLifeApp` and `app_router.dart` run from `app/lib/main_web.dart`. That is not a separate mock application.

- **Without staging settings:** guest resources/navigation render where locally supported; login remains disabled; no production backend connection.
- **With isolated staging settings:** the existing Supabase-backed Patient ID/phone sign-in, admin email sign-in, patient routes, and admin routes can be exercised with **synthetic staging users only**. This enables the real feature code; it does not automatically prove that browser interactions or RLS work.
- General User registration UI and role code are implemented in current source, but staging member migrations, provider setup and feature activation are NOT yet deployed or verified. Do not present member sign-up as operational until the staging end-to-end gate passes.
- Browser-native plugins (background audio, push, orientation/compass, offline and platform storage) need independent fallback/QA; the web bootstrap deliberately skips native background services.

## CI and deploy gate

1. Pull request: regular CI checks plus this workflow compiles and uploads the actual Flutter Web bundle as an artifact; never deploys PR source.
2. On approved changes merged/pushed to `main`, `CI` must **pass**. The Web workflow's `workflow_run` only accepts a successful **push** run to main and checks that the tested SHA is still the current main HEAD.
3. The Web workflow rebuilds the actual Flutter Web entrypoint, uploads its artifact, and then uploads an official **GitHub Pages artifact** and deploys it using `actions/deploy-pages@v4` to the **same existing Pages URL**. The artifact retains the `/prelaunch/` subtree from the old `gh-pages` branch; the old branch itself is no longer updated by this new workflow. No parallel website or repository is created. Set Settings → Pages → Build and deployment → Source to **GitHub Actions** once; then the post-deploy HTTP commit smoke check must pass.
4. HTTP smoke checks request `index.html`, `flutter_bootstrap.js`, and `preview-build.json` from the deployed URL, requiring the **exact commit SHA** in the marker. This is NOT equivalent to browser role testing.
5. Inspect Actions logs and actual `page_url` before reporting that the preview is live or browser verified. In Settings → Pages, GitHub Actions must be the configured build/deploy source.

**Do not merge while checks fail or while Pages points at content that must not be overwritten.**

## GitHub Actions repository variables (optional until staging ready)

Create *only after a separate, isolated Supabase staging project is approved and provisioned*:

| Variable | Value |
|---|---|
| `SUKUN_PREVIEW_SUPABASE_PROJECT_REF` | Verified **staging** Supabase project ref, never production |
| `SUKUN_PREVIEW_SUPABASE_URL` | `https://<staging-ref>.supabase.co` |
| `SUKUN_PREVIEW_SUPABASE_PUBLISHABLE_KEY` | Public staging `sb_publishable_...` key, **not** service role |
| `SUKUN_PREVIEW_PUBLIC_URL` | Optional validated, existing Pages URL; otherwise smoke-checks `https://umar-vai.github.io/Sukun-app-/` (not independently browser verified yet) |

Do **not** add service-role keys, JWT secrets, Gemini credentials, patient passwords, or production access tokens as Web build variables. The release workflow checks variable completeness and exact ref/URL matching and rejects the known production project ref `vydfafumxptanpkmtrpr`. Never use live patient accounts or data on public Pages.

## Staging and auth acceptance gate

Before calling the full authenticated preview ready:

1. Staging project/branch with clean synthetic patients, verified same-version migrations, functions, proper rate limiting, and RLS.
2. Browser-origin/CORS checks, auth redirects, session persistence, sign-out, expired sessions, credential change, and cross-patient negative tests.
3. Admin creates a synthetic patient → approved plan → patient completes a task → progress updates. Verify isolation by logging into two distinct patient identities.
4. Fix browser-native plugin gaps and mobile/desktop accessibility. Verify sensitive data is not in public HTML/JS/analytics.
5. Record the exact commit, Actions checks, deployed URL and manual browser QA separately.

## Current restrictions

The linked Supabase project `vydfafumxptanpkmtrpr` is **production**; no Supabase staging branches were discovered in the October 9 check. We must not use that environment as the preview backend, and must not apply the staged patient login limiter there without its release gates. The previous `web-preview` branch contained a production-connected public publishing workflow, which was changed on 9 October 2026 to checks/artifact-only (commit `3ac6e2c`). The `gh-pages` branch may still contain **older production-connected JavaScript** until a reviewed safe update is successfully published and verified. Treat it as untrusted for patient testing. Until staging is available, subsequent hosted Pages releases can only display the safely unconfigured guest portion of the **same real app**.

## Functional integration branch (9 October 2026)

Branch `integration/functional-flutter-web-20261009` builds on the *existing* `feat/otp-google-auth-gates-20261009` branch. The latter already includes the General Member account role, registration UI, and **disabled-by-default** email/phone OTP and Google OAuth; it is dependent on the open member foundation PR #19 and OTP PR #20.

The integration branch adds the same guarded `main_web.dart` entrypoint, strictly staging-only backend guard, local/negative tests, replacement of inherited production-connected Web/CI pipelines, and a green-CI-gated `gh-pages` deployment that preserves the existing `/prelaunch/` subtree. The parent features are **not merged to main**, their database migrations are **not deployed**, and public member sign-up and OTP/OAuth are **not enabled** until separate QA/release gates pass.

Review this branch as a **dependent PR** rather than shipping the older guest-limited `main` implementation over the feature-rich existing Pages app without reconciling differences.

### One-time GitHub Pages switch needed

GitHub explicitly documents that pushes made using `GITHUB_TOKEN` **do not trigger GitHub Pages builds** when Pages is publishing from a branch. Consequently the new deployment workflow uses the supported `upload-pages-artifact` + `deploy-pages` actions rather than pushing built files to `gh-pages`. A repository administrator must set the existing Sukun-app- repository **Settings → Pages → Source = GitHub Actions** once. This does not create a new site, change its URL, or touch the Sukun landing page. Until that setting and a successful deploy/HTTP verification are confirmed, the latest Web build is **CI-ready, not live**.
