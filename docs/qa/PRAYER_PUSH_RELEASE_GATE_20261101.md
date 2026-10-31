# Five-waqt notifications: remaining native/Web push release gates

Audited against the connected Production Supabase project and main Flutter
source on 2026-11-01. This is an operational snapshot, not evidence of future
delivery. Do not turn on a public release gate solely because CI passes.

## Working now

- Home displays the next prayer and a live countdown. City, calculation method,
  and Asr convention are explicit local user preferences.
- User-controlled native local notifications and active-tab browser notifications
  use dedicated prayer IDs and explicit permission.
- `PrayerNotificationService` serializes concurrent refresh, waits for an
  in-flight refresh before opt-out, and limits iOS prayer pending requests to 12
  (reserving capacity for separate patient/personal reminders). iOS requests are
  refreshed when the app opens/resumes; this is **not** unlimited offline coverage.
- Web Pages stays on the existing verified Flutter URL. No new APK is needed for
  development.

## Not yet enabled

**Closed-browser push is not a released feature.** On the audited system:

1. `app/web/sukun-push-config.js` has `enabled: false` by default, and
   `.github/workflows/functional-web-pages.yml` requires the explicit
   `SUKUN_WEB_PUSH_RELEASE_READY` gate and public Firebase identifiers/VAPID.
2. The Firebase service worker currently supports only validated
   `care_reminder` background messages, not `prayer_time`.
3. `notification_devices` has **zero active installations**, including Web;
   existing RPC registration is scoped to patient/care notifications.
4. Production `pg_cron` and `pg_net` are not installed. No server timer can
   currently deliver user-specific five-waqt notifications when a tab is closed.
5. Device-level Android/iOS permission, DND, power saving, lock-screen display,
   notification-tap and time-boundary tests have not been run on actual phones.

## Secure implementation gate (future PR)

- Explicit per-device consent for General User/Patient, independently of care.
  Do not silently opt Guests into persistent background delivery. Document
  any Guest feature and its privacy/abuse model separately.
- Owner-scoped RLS RPCs: register/rotate/revoke a Web FCM token; store minimal
  **explicit** prayer settings (city/method/time zone), not patient data or
  device geolocation history; clear on opt-out/account switch.
- Server recomputes the five times per selected date and handles local time
  zones, sunrise exclusion, Asr convention, and expiry; no permissionless
  browser-submitted dispatch time or arbitrary send endpoint.
- Install/test `pg_cron` + `pg_net` only after approval and staged RLS negative
  tests. Invoke a rate-limited, protected server Edge Function using a server-only
  secret in Vault. Verify Firebase project match without logging secrets.
- Durable per-(installation, local date, prayer ID) idempotent outbox and
  transaction-safe claims; retries, invalid-token deactivation, opt-out
  exclusion, and non-sensitive generic message body. No clinical content.
- Expand the service worker only for validated prayer IDs, with safe /prayer-times
  navigation, no arbitrary URL/payload. Add foreground/background deduplication.
- Stage and exercise 320px Home, daylight/time-zone boundaries, five daily
  deliveries, offline/closed-browser/locked phone, notifications disabled and
  revoked, two browsers, duplicate worker, and account switch.
- Before enabling production flags require a valid Firebase Web VAPID/public
  configuration, server-side Firebase credentials, a tested scheduler, an opted-in
  test installation, and successful actual phone/browser acceptance. A provider
  `sent` response is not proof that a user received a notification.

Existing `sukunlife.com` and the legacy internal dashboard must remain unchanged.
