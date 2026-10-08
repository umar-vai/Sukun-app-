# Patient Notification Inbox: prelaunch scope and release gate

Snapshot: 2026-10-08. Branch: feat/prelaunch-patient-notification-inbox-20261008.
Status: SOURCE IMPLEMENTED, DEVICE + PRODUCTION MIGRATION NOT VERIFIED.
Linked PR: https://github.com/umar-vai/Sukun-app-/pull/8

## Shipped-in-branch behavior (NOT deployed)

- Patient profile/navigation shell exposes an inbox at /patient/notifications.
- It reads only recent server-recorded `notification_events` with status sent/opened and past schedule (50 latest), under authenticated SELECT RLS.
- It presents generic, plain Bengali copy without names, prescriptions, remote payload text, URLs or device tokens.
- Opening a message marks it as opened with an authenticated server RPC and navigates only to known patient-owned routes.
- Unknown types safely open patient Today, not untrusted URLs.
- Failed, cancelled and scheduled events are not shown as delivered messages.
- Refresh, loading, no-messages, errors and retries are present.

### Known limitations

- Local device-only reminders are not persisted to `notification_events`. This is server-sent message history, not a complete activity history.
- Server push callbacks currently sync reminders but are not yet routed to this screen when the notification itself is tapped; the in-app bell icon provides access.
- No unread badge in the top navigation until a privacy-safe, efficiently cached count service exists.
- No "delete all" or "mark all read" bulk operation; avoid unsafe privileges.
- Timeline and deep-link behavior on Android/iOS physical devices still need testing.
- The function migration MUST NOT be applied to the current live Supabase project without reconciling live 37-entry migration history and parallel web-preview PR #2 changes. Live document parser version may differ from existing repo files.

## Security boundaries

- Existing RLS SELECT policy for `notification_events` restricts patient IDs from `private.current_patient_id()`.
- `public.mark_patient_notification_opened(uuid)` is SECURITY DEFINER, explicit `search_path=''`, derives the patient only from `auth.uid()`, checks own row and sent/opened past state, and returns false for unauthorized IDs.
- Direct authenticated patient UPDATE remains forbidden. No new broad GRANT or RLS update policy is introduced.
- Test unauthorized patient, anonymous identity, future scheduled, failed event and repeat idempotency on staging.
- Provider-message ID, device tokens and notification bodies are never selected into client history.
- Push lockscreen preview remains generic and should not display sensitive data.

## Validation gates

- [ ] `supabase db reset` and all pgTAP tests pass in isolated local Supabase
- [ ] `dart format --set-exit-if-changed`, `flutter analyze`, full `flutter test`, Android debug build pass
- [ ] Baseline schema and deployment migration IDs/checksums reconciled against production
- [ ] Authorized DB/security signoff on function ownership and grants
- [ ] Manual patients A/B read/open isolation test with dummy data, with no PHI
- [ ] Local-only reminder behavior explained and not misrepresented
- [ ] Foreground/background/killed app tap, retry/offline, notifications disabled and back behavior tested
- [ ] Accessibility and Bangla text scaling on compact/large Android and iOS verified
- [ ] PR #5 localization merged/rebased first, then PR #8 rebased/conflicts resolved
- [ ] Production backup and rollback signed before any live deployment

Release rule: do not merge/deploy PR #8 until these gates pass; do not infer physical-device compliance from CI.
