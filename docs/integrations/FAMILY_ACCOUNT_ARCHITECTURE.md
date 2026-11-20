# Family accounts

One Supabase Auth user (the family login) owns one `family_accounts` row. Profiles are
ordinary `patients` rows linked through `family_members`. No limit of five is coded.

## Rules enforced in the database

- The owner profile keeps `patients.user_id`. Other profiles have no login (`user_id` null).
- A patient is in at most one active family (partial unique index). Unlinking sets
  `unlinked_at` and keeps every plan, task and completion.
- `private.accessible_patient_ids()` = own active patient plus active members of the family
  the caller owns. `private.can_access_patient(id)` is the one check used by RLS and RPCs.
- Read policies (tasks, completions, prescriptions with `visibility='patient'`, plans,
  notification events, patients) allow any accessible profile. Staff-only rows stay hidden
  because the original visibility conditions were kept.
- Patient RPCs take an optional `p_patient_id`. It is validated on every call; omitted means
  the caller's own profile (single-patient accounts behave exactly as before).
  `record_task_completion` has no id argument: the profile is the task's patient, and the caller
  must be allowed to act for it, so a forged id is impossible.
- Per device: `register_notification_device(..., p_patient_id)` stores the selected profile on
  that installation's row. Switching phone A never touches phone B. The app keeps the choice
  locally per device too.
- `my_family_profiles()` lists selectable profiles (name, relationship, owner first).
- Staff RPCs `admin_create_family`, `admin_add_family_member`, `admin_remove_family_member`
  are audited. A profile cannot be moved between families silently, a profile with its own
  login cannot be linked, and the owner profile cannot be unlinked.

## Flutter side (implemented)

Code lives in `app/lib/features/family/`.

- `my_family_profiles()` is read by `SupabaseFamilyProfilesRepository`. A single patient account
  returns one row and the app behaves exactly as before.
- `activeProfileProvider` (Riverpod `AsyncNotifier`) holds the fetched list and the selected
  profile. The selection is stored per device and per login in `shared_preferences`, never on the
  server. It defaults to the owner profile, and a stored id that is not in the fetched list is
  discarded. `activePatientIdReaderProvider` is the only thing repositories use to learn the id.
- Top-right `ProfileSwitcherButton` (Patient app bar and the patient Home bar). It is hidden when
  there is one profile. The sheet shows name, initials avatar, relationship label, a check on the
  current profile and the disclosure that linked profiles share patient-visible information.
- Every patient read filters by the active `patient_id` (plan, tasks, prescriptions, progress,
  inbox, reminder window). `ensure_patient_tasks`, `ensure_patient_reminder_tasks` and
  `register_notification_device` receive `p_patient_id`; it is omitted when there is no profile
  context. `record_task_completion` stays id-less by design.
- `ProfileScoped` wraps each patient route and re-keys the subtree on a switch, so one profile's
  numbers can never stay on screen for another.
- The offline completion queue records `patient_id` on every event and is read per profile
  (`readForPatient`). Events written before family accounts have no `patient_id`; they are only
  ever applied to the exact task id they name, and the server re-checks access on submit.
- `ActiveProfileEffects` (above the router) calls
  `NotificationCoordinator.resyncForActiveProfile()` on a switch: it waits for any refresh that
  started for the previous profile, re-registers this installation with the new patient id,
  schedules the new profile's reminders and cancels the previous profile's pending ones. Reminder
  ids come from task ids, so nothing is scheduled twice. Push payloads stay generic.

Known limits: a local reminder that was already delivered for another profile still opens
`/patient/today?task=...` for the active profile only; pending offline events for a profile are
flushed when that profile is next opened.
