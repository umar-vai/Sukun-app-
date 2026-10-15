# Sukun Life — Production backend parity (2026-10-15)

## Verified before changes

- Canonical Flutter source: umar-vai/Sukun-app-, `main` (not separate staging UI).
- Supabase staging: `qacklgqvxvjjzsimjoip`; production: `vydfafumxptanpkmtrpr`.
- **Different migration lineages:** staging 30 applied; production 37 applied. Never replay staging baseline or reset production.
- Public tables: staging 27, production 25. Staging content items 183; production 3. No overlapping content UUIDs or slugs; 17 matching category slugs with **different UUIDs**.
- Production has 31 prescription attachments and 9 AI requests; retain all existing records even though the project owner confirms they are non-real/test patients.
- Missing production features: `member` enum, Auth member signup trigger, persistent patient sign-in limiter, patient notification read RPC, selected content bulk-review/publish RPCs, Quran editorial reference metadata/audit table.
- Staging's 101 Quran entries are **ARTICLE excerpts / editorial references**, not canonical verified Quran verses. Do not change them into `quran` type or mark verified automatically.
- A staging public-audio bucket contains one licensed public audio object. Its binary is NOT transferred by SQL; do not point production at staging media permanently.

## Proposed safe rollout

1. Confirm production backup or Supabase PITR/snapshot rollback option before any content bulk-transfer. No blind wipes or database cloning.
2. Apply **phase A** migration (new `member` enum label) separately from phase B to allow PostgreSQL enum transaction boundary.
3. Apply **phase B** idempotent backwards-compatible SQL for member provisioning, patient role exclusivity, login throttling, notification inbox, content editorial bulk routines, editorial metadata table.
4. Run DB checks: roles/trigger, existing admin/patient records unchanged, RLS and function permissions, 101 editorial records are not falsely verified.
5. Reconcile staging resources **by slug**, category IDs via category slugs, authors via authorized production actor; preserve status, reference sources, rights, publication state and exact editorial metadata. Transfer only approved public/source-authorized content after data verification and backup. Keep archived QA/staff-only/synthetic patient files separate.
6. Media: explicitly migrate approved audio bytes and verify rights, CORS, content checksums. Never copy private patients or secret provider keys. AI needs production-only server secrets verified independently.
7. Promote compatible Edge Function changes by comparing source/config between production and staging. **Higher deployment version number does not mean newer implementation.** Never overwrite production functions without diff/compatibility tests.
8. No live public site or old dashboard changes. Production Flutter Web hosting requires separately approved app subdomain and CI/browser gates. Existing GitHub Pages remains safe preview, not connected to private production patient API.

## Scope of this PR

Only additive, versioned SQL parity and safe operator notes. **Not** staging content sync or final live website cutover. CI database/pgTAP and Flutter/Web checks are required before applying production changes.

---

## VERIFIED LIVE PROMOTION — 15 October 2026 (UTC)

**Source main merge:** PR #95, squash commit `0c75be1b141aabf5d15ac16f86d6454432629b9a`. Both PR CI and Flutter Web Preview builds passed; PR preview Pages publishing was intentionally skipped.

### Applied ONLY to production Supabase `vydfafumxptanpkmtrpr`

- Migration `20261015082452 production_parity_member_role_20261015`: successful.
- Migration `20261015082508 production_parity_core_functions_20261015`: successful.
- Migration `production_rights_approved_audio_storage_20261015`: successful. Audio imports table / bucket provisioned; **no staged audio bytes copied**, as the app streams approved external media and the import endpoint is now a retired 410 tombstone.
- Auth `member` enum and signup trigger, nonclinical role provisioning, patient-role finalizer, service-role-only persistent sign-in rate-limit RPC, patient-owned notification opened RPC, four reviewed content bulk routines, and Quran editorial metadata/audit schema verified.
- Resource promotion **completed**: 181 staging content items safely INSERTED with **no conflicts**, production Super Admin actor mapping, category ID mapping by slug (all 17 matching slugs; staging and production category UUIDs differ), original review/publication/visibility/rights/source/status metadata unchanged. 181 production audit entries recorded.
- Two staging QA/archived records intentionally omitted. **No staging users, patients, private files, patient credentials, failed AI attachments, or secrets were copied.** Three pre-existing production content items and 31 production prescription attachments remained intact.
- Quran reconciliation audit data **101 records copied**, including 21 editorial end-ayah fields. This is editorial reference metadata, NOT canonical Quran verification or new publisher approval.
- Exact integrity hashes, computed from content JSON after excluding intentionally remapped category IDs and actor IDs, match:
  - staging 181 records = production 181 imported records: `17b07d01704cced28c096564c5bfd226`.
  - staging 101 Quran audit rows = production 101 rows: `f788d7f66720e026ba4d48d4e7cd001c`.
- Production Edge Functions deployed and ACTIVE: `prescription-to-actions` v11, `prescription-document-to-actions` v21 (latest canonical prompt), `patient-change-password` v7 and `quran-content` v1.
- Auth/Public RLS spot-check: anonymous reads show only published public content, `content_items` and Quran audit tables have RLS; `anon` and `authenticated` cannot call the sign-in rate-limit RPC, while `service_role` can; anonymous callers cannot invoke patient provisioning RPC.
- At verification, production count: 184 total content items (3 previously existing + 181 imported), 101 editorial Quran records/audits, 31 existing prescription attachments, 3 Auth users. No production patient data deleted.

### Still PENDING — DO NOT CLAIM PRODUCTION RELEASE

1. **Patient sign-in Edge Function:** existing production deployment was not overwritten with staging's newer persistent-throttling caller until the production-only `SIGN_IN_RATE_LIMIT_SECRET` is safely configured/verified. The server-side RPC is installed; function wiring requires a controlled deployment with negative auth tests.
2. **Gemini/Quran provider credentials and actual authenticated AI PDF-to-Actions E2E:** remain independently unverified. No provider secrets copied from staging to production.
3. **Production Flutter Web hosting:** Latest Flutter UI is in canonical `main`, but deploying a production-bound browser artifact on an approved separate app domain, validating DNS/CI/browser and privacy is a separate release gate. Do NOT redirect the existing public `sukunlife.com` site or repoint public GitHub Pages preview directly at private production patient data.
4. **Security advisors:** review SECURITY DEFINER function execution access and leaked-password protection warnings, plus authenticated admin/patient RLS negative tests and backup/restore runbook.
5. Staging-only audio blob and QA records are not production data; copying them is not needed for current external streaming but any later owned-media rehost requires explicit rights checks and verified binary/metadata match.
6. No APK/AAB/IPA, public site, legacy dashboard, or app-domain DNS change was made.

**Strict status:** production schema/functions/content promoted and read-only SQL checks passed; production Flutter hosting, provider configuration, secure sign-in deployment, authenticated E2E and public release **not yet verified/completed**.
