# Sukun Life — shared resource catalog and administrative routine roadmap

## Goals
1. Admin, Member, Patient and Guest view the same canonical Quran/Hadith/Dua/Ruqyah resource catalog and resource reader routes; the same eight `resourceSections` define public navigation and admin/clinical pickers.
2. Admin-only capabilities are additive: draft/review/publish verified content, assign routines to a specific eligible user and see their routine progress, without changing the user's personal routines unexpectedly.
3. All user-specific progress remains access-controlled and auditable. "Admin" in UI cannot imply cross-user database access.

## Delivered in initial UX PR
- Admin dashboard replaces the oversized marketing-like patient card with task-first sections, responsive two-column work cards and direct access to the **same `/resources` route** used by members and patients; existing super-admin content editor and patient-care routes remain separate.
- Personal action editor now loads the same CMS category relation and Quran metadata used by the clinical picker instead of a flattened title-only list.
- Dedicated selectable canonical Quran surah -> actual Arabic ayah picker, sourced exclusively from existing `quran-content` Edge API. Save `quran:<surah>:<ayah>` external reference, **never fabricated or duplicated verse text**.
- Clicking a selected ayah opens the existing canonical Quran reader route with `?ayah=` deep link. No production DB schema change is needed for this reference shape; existing owner-private RLS still applies.
- Tests verify ordered resource round-trip, invalid Quran ref rejection and admin links to shared public catalog.

## Important current limitation
- The existing Admin patient-care planner uses `plan_action_resources` (CMS) and `plan_action_quran_surahs` (whole surahs). It does not yet persist per-verse clinical prescriptions. Do not silently convert `quran:<surah>:<ayah>` into a whole-surah assignment.
- The Admin panel lists *patients*, not all user accounts; a new directory needs minimal metadata and an explicit account-to-patient mapping. Do not claim that every account is already an accessible patient.
- Owner-private `personal_routines`, `personal_routine_actions` and `personal_routine_progress` must not be opened globally to authenticated clients.

## Next secure milestone — Super Admin delegated routine assignments and read-only progress
1. Authorize via existing trusted server-side role source, **never** mutable `user_metadata`. Decide whether only Super Admin, or separately authorized care staff, can delegate personal routines.
2. Add a server-validated target-user directory with a minimum required identity projection (display name and status; avoid exposing clinical data). Search must be paginated and audited.
3. Create **dedicated privileged RPCs/Edge Functions** (service credentials strictly server-side) for assignment to a chosen user, and for read-only progress retrieval. Require fresh auth token and server-side role check **on every call**, validate target UUID, check active account/consent policy, and audit actor, target, action and timestamp.
4. Do not loosen existing per-owner RLS. Delegated assignments should have explicit assignment provenance, accept/reject state and a separate reminder opt-in. Admin may never silently schedule local notifications on another user's phone.
5. Reuse the same `resourceSections`, Canonical Quran picker and CMS category display. For care plans add a dedicated per-ayah reference with safe reader route and verified verse boundary checks, rather than overloading CMS UUID.
6. Per-user dashboard progress should distinguish manual completion vs missed reminders, only display authorized user-scoped records, and never present a pseudo-medical adherence metric.
7. Stage database migration and RLS tests for anonymous, ordinary Member, Patient, unauthorized Admin and Super Admin; include cross-owner tamper cases. Rehearse rollback in staging, then separately approve production rollout.
8. Device QA: low-memory Android and browser, guest/member/patient/admin, pagination, canceled assignments, local reminders, same existing audio and Quran reader, no cross-account leakage.

## Production gates
- No new RLS policy or user-directory exposure in this PR.
- No APK auto-publish, no Play Console change and no live update-feed enable.
- CI and Web Preview must pass before merge; Signed Android APK needed only after native UI code release.
