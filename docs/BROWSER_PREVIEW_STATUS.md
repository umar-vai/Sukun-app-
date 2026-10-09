# Sukun Life — Functional Flutter Web Preview (web-first)

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
- General User self-registration is NOT YET IMPLEMENTED. No UI-only replacement is marketed as a real account.
- Browser-native plugins (background audio, push, orientation/compass, offline and platform storage) need independent fallback/QA; the web bootstrap deliberately skips native background services.

## CI and deploy gate

1. Pull request: regular CI checks plus this workflow compiles and uploads the actual Flutter Web bundle as an artifact; never deploys PR source.
2. On approved changes merged/pushed to `main`, `CI` must **pass**. The Web workflow's `workflow_run` only accepts a successful **push** run to main and checks that the tested SHA is still the current main HEAD.
3. The Web workflow rebuilds the actual Flutter Web entrypoint, uploads its artifact, and then updates the **existing `gh-pages` publishing branch's root** while preserving its separate `/prelaunch/` subtree. No parallel website or publishing repository is created. GitHub Pages must be configured to serve that `gh-pages` branch, and the HTTP smoke check must pass.
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
