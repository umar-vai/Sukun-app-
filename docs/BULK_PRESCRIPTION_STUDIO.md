# Bulk Prescription Studio

## Baseline and canonical records

The implementation branches from production main `888209c9b54af39ffcd3670dc7388c480c0af508`, including the merged implementations of PRs #251 and #252.

Patient-specific prescriptions continue to use `care_plans`, `plan_actions`, and their existing resource relations. The plan version and its immutable published action rows are the approved instruction snapshot. Existing patient task generation, local reminder limits, completion records, and notification routing remain the delivery infrastructure.

The live role enum contains `patient`, `super_admin`, and `member`. Clinical studio access requires the database-backed Super Admin role. A future Raqi permission needs an explicitly reviewed patient assignment and clinical capability model.

## Practitioner workflow

1. Open a patient's plan or create a new draft.
2. Use the Official Templates panel on desktop, or the Official Templates sheet on a phone.
3. Search, select individual templates, or select a whole category. Filtered-result selection has its own button.
4. Import the combined selection once. Imported rows are saved as `needs_review`, with reminders disabled.
5. Select action rows and apply recurrence, dates, explicit reminder time, or reminder settings. Batch changes affect selected rows and reset their review state.
6. Expand a row to inspect its instructions, dates, counts, duration, and resources. Use its editor for reviewed changes or to restore the template instruction.
7. Use the row menu for intentional duplication, copying its schedule to other selected rows, or creating consecutive stages and multiple daily sessions.
8. Save Draft imports any pending template selections into the private draft. Action edits and batch changes also save directly to that draft.
9. Review actions, preview the patient view, and explicitly publish the existing plan version.
10. Export Prescription PDF previews, downloads, or prints the same version. Historical published versions remain exportable from their plan builder.

The original catalog remains the Flutter template source. Category totals are calculated from that catalog. The SQL migration contains the reviewed template-ID allowlist, without a second instruction catalog.

## Backend changes

The additive migration is `20261107033304_bulk_prescription_studio.sql`.

- `official_template_id` retains original category provenance.
- `prescription_item_id` retains an item's lineage across copied plan versions.
- `import_official_plan_actions` atomically imports a bounded selection, skips existing active template instances, and records a content-free audit event.
- `save_prescription_studio_action` uses the existing action/resource validation functions in one transaction. An invalid resource rolls back the associated instruction edit. Existing RPC signatures remain available.
- `update_prescription_draft_actions` locks the draft, validates the whole batch, and applies only the requested fields to the selected rows.
- `undo_prescription_draft_batch` restores the last saved schedule/removal batch and rejects an undo after a later persisted edit.
- `expand_prescription_action_schedule` creates explicit daily sessions or consecutive date-bounded stages. Retries return the original action IDs.
- Publication validates official placeholders, required published resources, reminder times, and copied date ranges.
- Copied plan versions retain official provenance, lineage, resource ordering, and relative stage dates.

These functions use `SECURITY INVOKER`, existing RLS, database role checks, and restricted execute grants. Draft operations do not create patient tasks or send notifications.

Studio imports and schedule expansion support up to 100 active actions per draft, batches of up to 100 actions, and up to 12 explicitly configured stages or daily sessions. Template payloads are bounded to 256 KiB. Existing clinical action-save validation remains active.

The delegated general-user composer retains its separate 12-action contract. It is a personal-routine flow and is outside the canonical patient prescription domain.

## Schedules and notifications

Consecutive stages are ordinary structured actions with distinct start/end dates and independent completion identities. Multiple daily sessions are separate actions with practitioner-supplied times. Both feed the existing daily/weekly task and reminder generators.

Time-of-day presets never insert an exact reminder time. The existing device-local timezone conversion and bounded reminder queue continue to handle explicit times, including Asia/Dhaka. Patient Today queries include approved occurrences for the current date and exclude cancelled tasks.

Notification taps resolve an authenticated patient's current task and its persisted linked resource. A single eligible audio/Quran/dua/hadith resource opens directly. Passive instructions, completed tasks, unavailable resources, and actions with multiple resources stay in Today. Text-derived resource suggestions are excluded from automatic notification opening.

Prayer-relative clinical scheduling remains outstanding. The personal-routine prayer scheduler has a different contract and requires patient location/method settings. Clinical prayer anchors need a reviewed shared contract before they can be offered in this studio.

## PDF rendering and privacy

The renderer uses the maintained `pdf` and `printing` packages, the existing `pdfrx` preview, and File Picker downloads. Pages are A4 with the official unmodified logo, blue/navy text, original reviewed instructions, schedule details, patient identity, available practitioner identity, version, draft status, and page numbering.

Flutter's text engine shapes the existing bundled Bengali font before each page is embedded at 216 dpi. This produces image-based prescription pages. Body text selection and text extraction are unavailable in this implementation. Canonical Arabic resource text is not copied into the export. Linked resources retain their existing references and current publication permissions.

PDFs remain in the authorized app session and the practitioner's requested local download/print output. They are not uploaded to a server bucket or included in the Pages bundle. Preview identity is distinct for each generated document.

## Validation and release gates

Synthetic-only Flutter and PostgreSQL tests accompany the feature. Local PostgreSQL verification uses a disposable PGlite instance with the real baseline clinical migrations and RLS, plus assertion equivalents for the committed pgTAP test. The full Supabase migration rebuild and pgTAP suite remain separate CI gates.

Responsive widget checks cover 360 × 640, 430 × 932, and 1440 × 900. Browser tests and visual review are recorded separately from authenticated staging acceptance.

On 7 November 2026 the Supabase connector listed `Sukun Life Staging` (`qacklgqvxvjjzsimjoip`) but its SQL connection failed with Postgres authentication error `28P01`. An alternative connected account lacked permission. Production read-only schema checks succeeded. The new migration has not been deployed to either hosted project.

The current production manifest was verified at `https://app.sukunlife.com/preview-build.json` and reported `888209c9b54af39ffcd3670dc7388c480c0af508`.

Required release evidence remains

- Staging migration and real Supabase pgTAP results
- Authorized synthetic Admin and Patient browser acceptance
- PDF download and browser-print interaction
- Final branded compact/large-phone visual acceptance
- Android/iOS-compatible notification and print acceptance
- Merge after those gates, production migration, Pages deployment, and exact deployed SHA verification

## Rollback strategy

Keep the old action-save and publication RPC signatures available. If client rollback is necessary, deploy the last accepted Flutter commit while retaining the additive columns, provenance, audit records, and validation trigger. Published history and patient completions must be preserved. Apply any later corrective database change as a reviewed forward migration.

The public company website and external CRM/dashboard are outside this change.
