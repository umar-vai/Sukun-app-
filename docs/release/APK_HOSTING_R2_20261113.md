# APK hosting moved off GitHub Releases (2026-11-13)

The repository is going private, so GitHub Release download links stop working
for the public. The APK is now served from a Sukun domain.

## Layout

- Public link and manifest `apk_url`:
  `https://downloads.sukunlife.com/android/<version>/SukunLife.apk`
- `downloads.sukunlife.com` (Cloudflare zone `sukunlife.com`) has a proxied
  placeholder A record and a single Redirect Rule (302) that sends
  `/android/*.apk` to `https://sukun-files.abdullahfahad.com/<same path>`.
- `sukun-files.abdullahfahad.com` is the public custom domain of the R2 bucket
  `sukun-downloads` (Cloudflare account Muhammadabdullahfahad5).
- The app and installer only accept `downloads.sukunlife.com/android/...`
  (`isApprovedApkUri`, `MainActivity.kt`) and verify size and SHA-256 after the
  download, so redirects are safe.

## Steps for each new version

1. Build and approve the APK as before (Sideload APK + Prepare Draft workflows).
2. Upload `SukunLife.apk` to the R2 bucket at `android/<version>/SukunLife.apk`.
3. Put `https://downloads.sukunlife.com/android/<version>/SukunLife.apk`, the
   SHA-256 and the size in `app/web/updates/android.json` and deploy.

TODO: `prepare-draft-android-update.yml` still writes a GitHub Release URL into
the manifest candidate. Change it (and add an R2 upload step with scoped
credentials) before the next release, or edit the URL by hand.
