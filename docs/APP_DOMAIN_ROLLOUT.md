# `app.sukunlife.com` rollout

The existing Flutter Web application remains the only app. `app.sukunlife.com`
is a custom domain for this repository's existing GitHub Pages deployment; it
does not alter the public `sukunlife.com` site or the legacy internal dashboard.

## Changes and ordering

1. Merge the guest welcome screen and domain-safe OAuth callback while the
   existing Pages URL remains live. The GitHub Pages workflow gets its build
   base path from `actions/configure-pages`; a project URL uses
   `/Sukun-app-/`, and a root custom domain uses `/`.
2. In GitHub Pages settings, set **Custom domain** to `app.sukunlife.com`.
   Keep HTTPS enforced after GitHub provisions a certificate. GitHub Actions
   publishing does not require a committed `CNAME` file.
3. In Cloudflare DNS, add only `CNAME app → umar-vai.github.io`, initially
   **DNS only**. Do not change apex, `www`, mail, or other subdomains.
4. Redeploy the green main commit after the Pages custom domain setting
   changes, so Flutter's `<base href>` becomes `/` before public traffic uses
   the new domain. Verify `preview-build.json` serves that exact commit.
5. Add the exact `https://app.sukunlife.com/` redirect URL to the existing
   Production Supabase Auth allow list, retaining the existing GitHub Pages
   callback for older sessions. Do not use a wildcard redirect. Test Google
   login, member login and patient login on the new origin with synthetic
   accounts. Set `SUKUN_APP_GOOGLE_REDIRECT_READY=true` only after that live
   Google callback succeeds; until then the production Web build hides Google
   login even if the provider is enabled. Supabase project, RLS, and patient
   records are unchanged.
6. Test guest resource routes, admin/patient deep links, browser refresh,
   mobile layout, and HTTPS on the new domain. GitHub may redirect the former
   Pages URL to the custom domain, so use the new origin for all new links.

## Android download gate

The landing reads `ANDROID_APK_URL` at web build time from the GitHub variable
`SUKUN_ANDROID_APK_URL`. Until there is an explicitly approved, signed,
versioned release APK at an HTTPS URL, leave this variable empty; the page
honestly shows that Android download is not yet available. Never publish the
CI debug APK as a release or point the button at a placeholder file. The
native APK/AAB packaging gate remains separate.

## Rollback

If the custom domain or root-path bundle fails, remove the custom domain in
GitHub Pages, redeploy the last green main commit so its base path returns to
`/Sukun-app-/`, then remove only the `app` CNAME. Preserve existing Supabase
data and all other Cloudflare records.
