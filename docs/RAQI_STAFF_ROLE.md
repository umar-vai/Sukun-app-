# Raqi staff role (2026-11-12)

Owner request: the main admin adds raqis by Gmail or phone. A raqi signs in
and lands in the admin area, works with patients and reminders, and cannot
change content.

## What a raqi can and cannot do

| Can | Cannot |
| --- | --- |
| See every patient (রোগী tab, search) | Edit content / CMS, library admin |
| Open a patient, plans, progress | Edit Sukun official templates |
| Import official templates, ghusl calendar | Notices, routine templates |
| Build, publish plans; switch reminders | Prescriptions, AI suggestions |
| Admin routines for a person (import, switch) | Create patient accounts |
|  | Add or remove staff |

All rules are enforced in the database (`private.is_care_staff()` on the
patient-care functions and policies; everything else still requires
`private.is_super_admin()`). The app only hides what a raqi cannot use:
two tabs (হোম, রোগী), no পরিচালনা section, no template pencil, no
prescription or AI buttons, and `isSuperAdminOnlyPath` sends a raqi home.

## Adding a raqi

Admin home → পরিচালনা → **রাকি ও টিম** (`/admin/staff`) → "রাকি যোগ করুন":
name, Gmail and/or phone.

- **Gmail:** the raqi signs in with Google using that Gmail. The account gets
  the `raqi` role on first sign-in (trigger on `auth.users`), or at once if
  the account already exists. The app also calls `claim_staff_membership`
  on every sign-in.
- **Phone:** matches an account whose sign-in phone, or linked patient record
  phone, has the same last 11 digits. The app has no SMS sign-in, so a raqi
  without such an account should be added by Gmail.
- "সরান" removes the role at once; the entry is kept for history. Both
  actions are audited (`staff.raqi_added`, `staff.raqi_removed`).

## Database

- `20261113115900_app_role_raqi.sql`: enum value (must commit alone).
- `20261113120000_raqi_staff_role.sql`: `staff_members` table, RPCs
  `admin_add_raqi`, `admin_remove_raqi`, `claim_staff_membership`, the
  sign-in trigger, and in-place patches of 18 patient-care functions and 18
  policies. pgTAP: `supabase/tests/raqi_staff_role_test.sql`.
- `send-notification` Edge Function v5 accepts a raqi publishing a plan.
