# Sukun Life — activating verified in-app Android updates (owner-controlled)

## What changes without an APK?
- Flutter web page edits deployed to app.sukunlife.com are visible in the browser without reinstalling the Android app. Native UI Flutter code remains the installed snapshot, **not a web wrapper**.
- Published CMS resources, routine records, and compatible Supabase/Edge API responses can refresh in the installed app without a new APK. Backend schema/API changes must stay compatible.
- Native Flutter UI, plugin, notification code, auth deep-link handler, app assets and compiled code **always require a new versioned signed APK**. The updater merely removes manual ZIP hunting and file transfers.

## Current state (2026-10-31)
- The installed Android app checks https://app.sukunlife.com/updates/android.json when opened/resumed (limited to 6-hour checks) and on Account > Check Updates.
- Source app/web/updates/android.json remains disabled and no published GitHub Releases currently exist. **Checking for updates does not download an Actions artifact.**
- Signed APK 1.0.2 (versionCode 3) successfully built in Actions run 41113778188, but its short-lived artifact is not a public permanent release.
- Existing on-device APK is the bootstrap: no fresh bootstrap package is required to use the updater once the valid public feed is activated.

## Safe first activation (separate approvals)
1. Complete real Android QA: account login, audio, notification in foreground/background/locked mode, permission requests, app update in place with same signer, low-memory device, network retry and support readiness.
2. After reviewing/merging the new owner-gated workflow, Actions > Prepare Draft Android Update — Manual Only: select main, enter the **successful signed Sideload run ID**, exact versionName/versionCode, and affirm the draft-only gate. This workflow downloads the exact ephemeral artifact and verifies run origin, ancestry, APK checksum, version/package, and approved owner certificate. It creates a **DRAFT** GitHub Release and separately stores a manifest-candidate JSON; it never publishes the APK, updates web production, or switches on user prompts.
3. Review the draft SukunLife.apk and its checksum. Have an owner explicitly publish the GitHub Release **only after device QA**. Publishing a GitHub Release makes its APK generally downloadable; it is not an internal-only channel.
4. Review a *separate PR* that copies the actual reviewed manifest candidate into app/web/updates/android.json. Require exact release URL, package com.sukunlife.app, versionCode, signature identity, size, SHA-256, and bangla notes. Once merged and deployed to the production host, verify the live URL is public HTTPS and contains the right values. This action enables user update prompts.
5. In an installed older signed APK, tap Account > Check Updates. Download through Android DownloadManager, verify size+digest+package+version, tap Install, approve Android OS installer. Preserve app data and verify rollback/kill switch (enabled:false) before a public campaign.
6. Every future **native** code update repeats: signed APK build -> device QA -> draft release -> reviewed publish -> manifest PR. End users do not manually find a ZIP; they still approve Android installation. Backend/content changes do not require this.
7. Keep the same app signing key; never upload a keystore to the repo or chat. Never use an expired Actions artifact for permanent update downloads.

## Release-safety notes
- GitHub Actions build artifacts expire and cannot be used as a stable update URL. Native code only accepts official GitHub Release assets or the preapproved custom download host.
- The manifest can be disabled without affecting existing installed apps; it only stops showing new update prompts.
- Downloading a verified APK does not bypass Google's Play Protect and Android installation prompts.
- For future **Google Play** publication, this custom APK self-updater and REQUEST_INSTALL_PACKAGES permission need separate Play-policy compliance review; Play restricts self-update uses of this permission. Plan Play App Signing continuity carefully.
- An Android background auto-update without user approval is neither implemented nor promised. The app may check on launch/resume; the Account button checks on demand.

## What is intentionally NOT done by this documentation/workflow
- Does not publish the owner APK to public users.
- Does not change app/web/updates/android.json or production website.
- Does not install or update Android packages without user approval.
- Does not add any patient-specific data, tokens or long-term signing keys to an APK.
