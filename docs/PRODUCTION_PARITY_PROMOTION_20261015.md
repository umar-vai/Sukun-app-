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
