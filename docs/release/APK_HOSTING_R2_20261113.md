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

1. Run "Official Android Sideload APK — Manual Only" on `main`.
2. Run "Publish Android Update — Manual Only" (`prepare-draft-android-update.yml`)
   with that run ID, the version name and code, and the approval box ticked.
   After the existing package, version, checksum and certificate checks it:
   - uploads the verified APK to R2 at `android/<version>/SukunLife.apk`
     (bucket `sukun-downloads`). It never overwrites: an existing object is
     accepted only if its stored `sha256` metadata and size match, which lets
     a rerun continue after a later step failed;
   - downloads `https://downloads.sukunlife.com/android/<version>/SukunLife.apk`
     and fails unless the SHA-256 matches the verified APK;
   - creates the GitHub Release (an internal archive now that the repository
     is private);
   - writes the `downloads.sukunlife.com` URL, SHA-256 and size into
     `app/web/updates/android.json` and opens a pull request
     `update-feed-v<version>`.
3. Merge that pull request. The workflow does not push to `main` itself:
   a push made with `GITHUB_TOKEN` does not start CI, and the Pages deploy
   (`functional-web-pages.yml`) only runs after CI succeeds on a push to
   `main`, so a bot push would leave the live feed stale. A person merging
   makes a normal push, which runs CI and deploys the feed. Checks do not
   start on the bot's pull request by themselves. If branch protection
   requires them, an admin can review the one-file diff and merge with
   bypass.

## Required environment secrets (owner action)

Add these as **environment secrets** on the `android-sideload-release`
environment (Settings, Environments, android-sideload-release). The workflow
fails before uploading if any is missing.

| Secret | Value |
| --- | --- |
| `R2_ACCOUNT_ID` | Cloudflare account ID that owns `sukun-downloads` (32 hex characters) |
| `R2_ACCESS_KEY_ID` | Access Key ID of an R2 API token |
| `R2_SECRET_ACCESS_KEY` | Secret Access Key of the same token |

Create the token in Cloudflare (R2, Manage R2 API Tokens) with permission
**Object Read & Write**, scoped to the bucket `sukun-downloads` only. Do not
use an account-wide or Admin token. Rotate it by creating a new token, updating the two key secrets and deleting
the old token.
