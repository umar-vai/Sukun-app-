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
   accounts. Supabase project, RLS, and patient records are unchanged.
6. Test guest resource routes, admin/patient deep links, browser refresh,
   mobile layout, and HTTPS on the new domain. GitHub may redirect the former
   Pages URL to the custom domain, so use the new origin for all new links.

## Android download gate

The landing now reads the public `/updates/android.json` manifest at runtime
(`ENABLE_PUBLIC_APK_DOWNLOAD` defaults to `true`) and links the `apk_url` of the
latest enabled, approved release. Updating the manifest (see
`docs/release/DIRECT_APK_LINK_AND_UPDATES_20261110.md`) updates the landing
button with no web rebuild. To close the button, set `enabled` to `false` in the
manifest, or set the GitHub variable `SUKUN_PUBLIC_APK_DOWNLOAD_ENABLED` to
`false`. `ANDROID_APK_URL` (`SUKUN_ANDROID_APK_URL`) remains an optional
build-time fallback. Never publish the CI debug APK as a release. When the app
is live on Google Play, replace this button with the Play Store badge/link.

## Rollback

If the custom domain or root-path bundle fails, remove the custom domain in
GitHub Pages, redeploy the last green main commit so its base path returns to
`/Sukun-app-/`, then remove only the `app` CNAME. Preserve existing Supabase
data and all other Cloudflare records.
