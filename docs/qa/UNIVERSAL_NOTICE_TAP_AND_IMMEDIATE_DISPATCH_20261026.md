# Universal notice: Android tap + Admin Publish → Push acceptance (26 October 2026)

## Owner report and verified boundaries

- Current Staging QA APK receives single-token Firebase Console notifications.
- Android expanded tray can show public notice image. That verifies generic FCM and
  image rendering **only**, not correct deep-link navigation.
- Owner reports tapping the notification may open the app without showing the
  addressed notice. Code now retries a pending validated UUID after Android resume,
  alongside existing cold-start/session-after-frame relay.
- Isolated Staging public notice table previously had a published QA notice; the
  uploaded image appears to include identifiable account/financial details.
  **Replace/delete that public image before any broadcast**, including Staging.
- Staging publish creates an outbox job; no sender currently dispatched that
  queued public notice. The existing Production GitHub schedule is 5-minute
  best-effort with an explicit closed release gate.

## Reviewed change (not deployed by this PR)

1. The existing Flutter Admin editor saves a notice under Super Admin RLS.
2. On initial publication, it requests an **authenticated** server-side
   dispatch of that one newly published notice UUID.
3. Server verifies the caller via Auth and database-backed `super_admin` role;
   service-only SQL atomically claims **only** that pending published UUID.
4. The existing FCM HTTP v1 sender includes
   `type=universal_announcement`, `announcement_id=<UUID>`, optional approved
   public `image_url`, and optional `countdown_ends_at`. It targets only
   the opt-in topic `sukun_public_notices_v1`.
5. Sender remains blocked by `SUKUN_UNIVERSAL_PUSH_RELEASE_READY` until native
   consent, notification tap, opt-out, retry/dedupe and non-sensitive public
   image acceptance are verified. Disabled sender leaves new notice in queue.
6. Existing cron-only fallback stays separate. Native push is **best effort**;
   FCM topic subscriptions prioritize throughput, not guaranteed instant or
   delivery to every device. The server can only record provider acceptance.

## Required rollout stages

- GitHub Flutter format/analyze/tests, Edge typecheck/tests, SQL migration/RLS,
  Flutter Web build/role/browser checks → PR merge.
- Apply new **additive** migration only to isolated Staging, verify service-only
  execute privileges and negative duplicate-claim tests; do not edit Production.
- Deploy compatible Staging `dispatch-universal-announcements` Edge Function;
  commit alone does **not** deploy it.
- For single-device Android QA, **do not activate the topic release gate**;
  use Firebase Console test-send with a fresh device registration token and
  only a published public, non-sensitive Staging notice UUID.
- Test **background and terminated** states separately with metadata-bearing
  notification, after checking the image URL in private browser mode.
- Verify destination detail, back/close and no accidental auto-popup cover.
  Record sanitized evidence, Android API level and pass/fail results.
- Before any real topic enablement: opt-in/out on Android and iOS, duplicate
  prevention, completed background/cold-start tap, safe queued outbox, Firebase
  server credentials, rate limits, and staged consented cohort. Explicit
  operator approval required to change the server+workflow release gates.
- Web browser-closed push requires a separate browser VAPID/service-worker gate.
  In-app public notice inbox works across all Flutter roles without push.

**Never enable global/topic sender merely to test a single handset.**
No APK/AAB/IPA built by routine CI. No existing `sukunlife.com` or legacy
dashboard changes.
