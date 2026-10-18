# Navigation audit — 2026-10-18

Scope: the standalone Flutter app on Web and mobile, across Guest/Member,
Patient, and Super Admin sessions. No public website or clinical data changes.

## Findings and corrections

| Area | Finding | Correction |
| --- | --- | --- |
| Guest/Member | The home page had a bottom bar, but Resources, notices, Qur'an, and utility routes lost it. | A role-aware route shell now keeps Home, Resources, and Notices available on secondary screens. The home page uses the same branded bottom bar. |
| Patient | Five destinations appeared on main screens only. Assigned resource detail, routines, notices, prayer, and utility routes lost them. | The route shell carries the five patient destinations onto secondary screens. |
| Super Admin | Dashboard, Patients, and Content had a bottom bar; notice editor and clinical nested screens lost it. The notice list highlighted Content. | The route shell covers nested screens; Notices is a fourth Admin destination with its own selected state. |
| Direct links / refresh | Browser history may have no in-app page to return to. | Secondary screens show Back with a safe section fallback, plus Home. Invalid routes show a Home action. |

The login and mandatory first-password-change screens intentionally stay outside
the navigation shell so a patient cannot bypass the credential gate. Role
destinations still pass through the existing GoRouter role redirect and Supabase
RLS; this change does not grant access to protected data.

## Verification

- Widget test covers a guest deep link, Back to Resources, Home, and role-specific
  fallback destinations at 360 × 640 and 430 × 932 without overflow.
- Existing protected-route tests cover unresolved and expired sessions.
- Full Flutter analyze: clean. Full Flutter test suite: 335 passed.
- CI and live Pages browser review are still required before release acceptance.
