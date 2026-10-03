# Notifications Architecture

Phase 7 adds patient care reminders without turning notification delivery into a source of clinical instructions.

## Local care reminders

- Flutter schedules local notifications only from server-authorized `task_instances` returned by `ensure_patient_reminder_tasks`.
- The database RPC generates task instances only when the active plan action is `approved`, has `reminder_enabled = true`, and contains an explicit `exact_time`.
- Missing times are never inferred from a time window or from AI output.
- The app keeps a 31-day task horizon and at most 48 pending local notifications, leaving headroom under iOS pending-notification limits.
- Notification text is intentionally generic so private care details are not displayed on a locked screen.
- Patient-selected snooze times are explicit and replace the original task notification.
- Done and Skip cancel that task notification.
- A full reminder refresh cancels every previously tracked care reminder before installing the current active-plan schedule.
- When a care plan becomes inactive or archived, a database trigger cancels its future pending/snoozed tasks and scheduled backend notification events.

Local notifications use inexact allow-while-idle delivery on Android. This avoids requesting exact-alarm privileges and does not claim to bypass device battery, Focus, or Do Not Disturb policies.

## Push notifications

Flutter uses Firebase client configuration supplied through public runtime defines. Firebase server credentials are never included in Flutter or checked into the repository.

On plan publication, the admin app invokes the authenticated `send-notification` Edge Function. The function:

1. verifies the Supabase bearer token;
2. verifies the caller's database-backed `super_admin` role;
3. verifies that the requested plan is active;
4. loads only active device registrations for that plan's patient;
5. sends a generic `plan_updated` message through FCM HTTP v1;
6. records per-device delivery events and a non-sensitive admin audit summary;
7. deactivates tokens rejected as invalid/unregistered.

The payload contains only the event type and care-plan identifier. It does not contain prescription text, action content, staff notes, Firebase credentials, or another patient's identifiers. Foreground, background, and notification-open handling all trigger a local reminder refresh. Plan publication remains successful if push delivery is temporarily unavailable.

Server-only Supabase secrets:

```text
FIREBASE_SERVICE_ACCOUNT_JSON
FIREBASE_PROJECT_ID
```

`FIREBASE_PROJECT_ID` is checked against the service-account project when supplied. Secret values must never be printed, returned to Flutter, committed, or put into analytics.

## Device ownership and isolation

- `register_notification_device` derives `user_id` and `patient_id` from `auth.uid()` and the active patient record.
- Flutter cannot supply a patient ID.
- One installation replaces its own stale token, but a different user cannot take over an existing token.
- `remove_notification_device` deletes only the authenticated user's matching installation.
- Direct authenticated insert/update/delete grants on `notification_devices` are revoked; the validated RPCs are the write boundary.
- Existing RLS keeps device registrations, notification events, and reminder tasks isolated per patient.

## Deliberate MVP boundary

Admin broadcast notifications are not included. Phase 7 supports only care-plan update delivery to the patient who owns that plan. This keeps the MVP within its patient-care scope and avoids introducing audience selection, consent, moderation, and unsubscribe rules without approved requirements.
