# Sukun Life — Direct Android Distribution and Verified In-app Updates

**Status:** implementation under review in PR #148. **NO official APK has been signed, published or installed by this PR.** Play Console is not required for approved direct Android distribution, but Android's built-in installer requires explicit user approval.

## User experience

### First installation
1. A customer visits the existing Flutter app website at `https://app.sukunlife.com/` (not the unchanged `sukunlife.com` public site).
2. Until an approved signed APK is published, the existing download CTA remains disabled. When the public `/updates/android.json` manifest is enabled with an approved release asset, the Flutter welcome screen can display the verified `Download Android App` link dynamically.
3. Android downloads the APK over HTTPS and asks the user to approve installing from that browser/source. The user confirms the Android system installer.
4. After installation, the app uses the current Supabase Auth and owner-protected database; no patient records or API secrets are packed into the installer.

### Subsequent updates
1. Installed Android APK checks `https://app.sukunlife.com/updates/android.json` on first launch and when the app returns to foreground (rate-limited); Account includes a manual `Check Updates` action. API/feed downtime must not interrupt routines, Quran or care tasks.
2. When a higher Android versionCode appears, the app displays a Bengali modal with release notes, size and `Download Now`.
3. Clicking it queues the **exact reviewed** APK in Android DownloadManager; progress appears within the app and in the system download notification.
4. Before opening the installer, the app **re-verifies the exact file size, SHA-256, package name `com.sukunlife.app`, higher versionCode and APK source URL allowlist**. The installed app's signing certificate is verified by Android at installation time. SHA-256 is supplemental integrity, not a substitute for signing.
5. After download, app invokes the **Android system installer**. On Android 8+, the user may need to allow installs from this app; then they approve installation. It is **not a silent install**. If user declines, their current app remains usable.
6. The same signing key must sign ALL future direct-distribution versions. Never ship a new key without a documented Android migration strategy. Moving these installations to Google Play later can require special Play App Signing planning; upload key and end-user app signing key are not necessarily the same.

## Release metadata

The static public feed source is `app/web/updates/android.json`, which is copied into the SAME Flutter Pages build and served at `https://app.sukunlife.com/updates/android.json`. The initial feed has `enabled: false`; no false download/update CTA. The **web landing's first-install CTA** only starts remote feed checking after the explicitly approved GitHub variable `SUKUN_PUBLIC_APK_DOWNLOAD_ENABLED=true` is configured for the build. Keep that variable absent/false until the very first signed APK has passed QA and is publicly downloadable. Existing installed Android APKs check the release feed independently. A reviewed release PR updates the manifest to exactly the staged artifact URL/checksum/version; CI builds the existing Flutter Pages URL.

Sample after **real** artifact verification only (example hash not publishable):

```json
{
  "schema_version": 1,
  "platform": "android",
  "package_name": "com.sukunlife.app",
  "enabled": true,
  "version_code": 2,
  "version_name": "1.0.1",
  "min_supported_version_code": 0,
  "apk_url": "https://github.com/umar-vai/Sukun-app-/releases/download/v1.0.1/SukunLife.apk",
  "sha256": "<64 hex characters computed from actual signed APK>",
  "size_bytes": 30000000,
  "notes_bn": "ছোট বাগ সংশোধন ও উন্নত অ্যাপ অভিজ্ঞতা।"
}
```

Do **not** copy the sample digest/size. Do not enable the manifest before:
- Uploading the genuinely signed and scanned APK to the verified official release location.
- Recording SHA-256, actual byte size and the matching installed APK versionName/versionCode.
- One full native-device installation and update rehearsal with synthetic accounts.
- Confirming CDN and direct downloads over weak Bangladesh mobile connections.
- Reviewing release channel, support contact, privacy/account deletion and current security gate.

Only approved hosts are: exact GitHub Releases assets in `umar-vai/Sukun-app-`, or optional future approved `downloads.sukunlife.com/android/...` (DNS and CDN require separate operator approval). Arbitrary URL redirects inserted into the manifest or client-provided origin are forbidden. The APK is always a public binary, NEVER a container for backend service-role, Gemini or Firebase server secrets.

## Manual signed APK production (no Play Console)
1. Bring **API36/fail-closed native signing PR #147** through review/merge first. It rejects debug-signed production releases.
2. Set up a protected GitHub Actions environment named `android-sideload-release` with required reviewers. Never commit a keystore or send it in chat. Use a long-term **app-signing** key, not blindly the future Play upload key.
3. GitHub environment encrypted secrets:
   - `SUKUN_SIDELOAD_KEYSTORE_BASE64`
   - `SUKUN_SIDELOAD_STORE_PASSWORD`
   - `SUKUN_SIDELOAD_KEY_ALIAS`
   - `SUKUN_SIDELOAD_KEY_PASSWORD`
   - `SUKUN_PRODUCTION_SUPABASE_URL`
   - `SUKUN_PRODUCTION_SUPABASE_PUBLISHABLE_KEY` (public app key, NEVER service role)
4. GitHub environment variables:
   - `SUKUN_ANDROID_PACKAGE_NAME=com.sukunlife.app`
   - `SUKUN_ANDROID_LAST_VERSION_CODE` (highest already distributed)
   - `SUKUN_SIDELOAD_CERT_SHA256` (owner's certificate, publicly shareable fingerprint)
   - `SUKUN_ANDROID_GOOGLE_OAUTH_TESTED=true` **only after** the release signing fingerprint and `com.sukunlife.app://login-callback` pass real Google OAuth on device.
5. Explicit manual Actions → **Official Android Sideload APK — Manual Only** `workflow_dispatch` with approved version/code, channel `internal` or `public`, and signed build approval. It never runs on push or PR and does not automatically publish. Existing Flutter Web daily CI remains APK-free.
6. Check short-lived GitHub QA artifact, SHA256SUMS, actual signed APK certificate, Google Auth, offline, RLS, notifications/audio and all test accounts. Publish approved APK to a Github Release asset (or approved dedicated CDN) **as a separate reviewed release step**. Then update the public metadata through a protected PR and verify the Pages deployment SHA.
7. Maintain a server-side rollback/kill switch: `enabled: false` disables **new update prompts** without deleting installed apps. Never republish an older versionCode; create a new signed higher version to roll back native changes.

## Safe 5,000–12,000-customer rollout

| Wave | Scope | Exit gate |
|---|---|---|
| 0 | 10–30 internal Android phones | Install/update, owner data isolation, crash, media and permissions |
| 1 | 100–300 invited users | Support load, real carrier/network and update delivery |
| 2 | 1,000 limited users | Stability/Supabase RLS, cost and bandwidth |
| 3 | 5,000, then up to 12,000 | Monitoring + responsive support + signed rollback strategy |

Use Cloudflare R2 or another well-monitored CDN if download traffic/quotas warrant it; the initial GitHub Releases link is a distribution option, not an assumed 12,000-user SLA. A 50 MB APK delivered to 12,000 customers is roughly 600 GB **per version**, before retries. Account activation/backend costs are separate.

Set monitored alert thresholds for download failures, verified update rejection, crashed/ANR sessions, authentication anomalies, Supabase spend and cross-patient access checks. Collect only aggregate update version/status telemetry, not patient activity/content.

## Limits

- Native Flutter/Dart/plugin/security code changes require a new **signed APK**. No unreviewed arbitrary remote Dart/AI code execution.
- Compatible server-provided resources, published content, AI prompts and approved Supabase/Edge API behavior may update independently of the Android binary after **backend deployment** and app refetch.
- Android only. iOS third-party IPA distribution has separate Apple restrictions; Flutter Web/PWA is the non-Play option for other devices.
- Foreground app launch/resume and manual checks are implemented here. **Background push for updates while the app has never been opened is not yet proven**; add only after Firebase native-device and push delivery QA.
- Android's installation confirmation and per-source permissions are not bypassable in the normal release flow.
- Do not publicly release before security review (#142), patient identity-linking decision (#140), support/privacy/account deletion workflows and controlled physical-device acceptance (#146).

**Production impact of this PR:** None until reviewed CI, merge and verified existing Pages deploy. Supabase schema, patient data, legacy website and its admin dashboard are unchanged.
