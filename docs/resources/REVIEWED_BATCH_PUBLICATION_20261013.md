# Reviewed content publication — October 13, 2026

## Current evidence

Staging project `qacklgqvxvjjzsimjoip` contains 178 Draft items, grouped as 128 article, 24 dua, 8 amal, 17 audio and 1 private test item. A total of 101 article items are deliberately labeled with `সূত্র যাচাই প্রয়োজন` and cannot be promoted as verified Qur'an Ayat. The approved book/audio sources have an owner attestation recorded in the item rights notes.

All 177 substantive Drafts are initially `staff_only`. Changing `status` alone does not make them visible to guests; after a reviewed Super Admin confirmation, the allowed batch changes **eligible** items to `public` before the normal review/publish transitions.

## Authenticated one-click batch

- In the real Flutter Super Admin Content Library, use the reviewed batch button and the explicit confirmation dialog.
- The pure allowlist accepts approved book slugs (`srg2024-*`) for article, dua or amal, and owner-attested downloadable audio slugs (`sukun-ruqyahbd-*`); rejects QA/test/synthetic items, scriptural placeholders, private patient data, canonical Qur'an/Hadith items, missing rights or source, unsafe media and unexpected statuses.
- Each item is processed using only the existing `save_content_item` (to make eligible item public), `transition_content_item(..., 'submit')` and `transition_content_item(..., 'publish')` RPCs. Both backend functions require `auth.uid()` and DB-verified Super Admin, and write reviewer/audit logs. No service-role or client impersonation.
- Failures are counted without leaking raw backend messages; remaining records retain their reviewable states. Reopen the library after an interruption to resume. If the session isn't a verified Super Admin the backend rejects the operation.
- This is a browser-facing **Super Admin action**, not an automated backend deployment. Mere GitHub merge/Web build does not publish database records. Current assistant Supabase SQL session is `postgres` with no `auth.uid()`; it cannot execute this workflow on behalf of a logged-in CMS user.

## Scope boundaries

This reviewed batch should cover at most 76 current records (27 guides, 24 dua, 8 amal, 17 audio). The other 102 stay private and require item-level correction, source verification or removal from the editorial test set. The eight Ruqyah Ayat categories are not populated by publishing article drafts; canonical verified Qur'an items and memberships must be created separately.

After an authorized Admin uses the action, verify `status = published`, `visibility = public`, `published_at`, `content_reviews`, `admin_audit_logs`, and actual guest/patient browser visibility. Do not claim completion based on code deploy alone.
