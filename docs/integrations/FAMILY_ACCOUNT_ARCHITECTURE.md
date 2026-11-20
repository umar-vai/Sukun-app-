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

## Routines and the 40 day challenge

Per profile (owner decision). `personal_routines`, `challenge_enrollments` and `challenge_day_checkins`
have `patient_id`; a missing value defaults to the owner's own profile, so older app versions keep
working. Challenge keys include a generated `profile_key`; upserts use
`on_conflict=user_id,challenge_key,profile_key`. Writes require a profile the caller may act for.
Admin routines created for a user without a profile land on that user's own profile.

## Flutter work still to do

Top-right switcher reading `my_family_profiles()`; an active-profile provider that every
patient repository reads; passing `p_patient_id` to the generators and device registration;
profile-keyed offline completion queue; reschedule local reminders on switch; disclosure text
that linked profiles share patient-visible information. Existing screens keep working for
single-patient accounts because the RPC parameter is optional.
