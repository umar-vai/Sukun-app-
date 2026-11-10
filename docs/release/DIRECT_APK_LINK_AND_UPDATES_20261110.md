# Direct APK link and in-app updates (2026-11-10)

## The link to share

```
https://github.com/umar-vai/Sukun-app-/releases/latest/download/SukunLife.apk
```

- Downloads the `.apk` file itself (no ZIP, no GitHub page, no sign-in).
- Always points to the newest **published** (not draft, not pre-release)
  GitHub Release, so the same link keeps working for every future version.
- Works only after at least one release is published with an asset named
  exactly `SukunLife.apk`. The "Prepare Draft Android Update" workflow
  already names it that way.

## How users get later updates

1. The installed app checks `https://app.sukunlife.com/updates/android.json`
   when it opens and when it comes back from the background (at most every
   6 hours; "পরে করব" hides the same version for 24 hours; Account → "অ্যাপ আপডেট"
   checks at once).
2. If the feed shows a higher `version_code`, a popup appears: "Sukun Life
   আপডেট পাওয়া গেছে" → "ডাউনলোড করুন" shows a progress bar inside the app →
   "ইনস্টল করুন" opens Android's installer. Data is kept because the same
   signing key is used.
3. The APK is checked for size, SHA-256, package name and version before the
   install button appears. The feed only accepts this repository's GitHub
   Release URLs (with a tag in the path) or `downloads.sukunlife.com/android/`.

## Steps for each new version

1. Merge the code to `main`.
2. Actions → "Official Android Sideload APK — Manual Only" on `main`, a new
   version name and a higher version code.
3. Actions → "Prepare Draft Android Update — Manual Only" with that run ID.
4. Test the draft `SukunLife.apk` on a phone, then on GitHub → Releases edit
   the draft: set a public title and notes, untick pre-release, and press
   **Publish release**. The share link now gives this version.
5. Pull request that copies the reviewed manifest candidate into
   `app/web/updates/android.json` (tagged URL, `enabled: true`). After it is
   merged and the web app deploys, installed apps show the update popup.

To stop the popup at once, set `enabled` to `false` in that file and deploy.
