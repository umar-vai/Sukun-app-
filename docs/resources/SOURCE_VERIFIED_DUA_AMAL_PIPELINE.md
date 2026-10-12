# Sukun Life: source-verified Dua/Amal ingestion and AI material preparation

**Priority reset: 2026-10-12 — Issue #64.** Follow the single-codebase Flutter Web-first strategy. This is a specification for a **source-grounded, reviewable** library, not evidence that all resources were imported.

## Input and provenance: required before extraction

The repository still contains a previously corrupted PDF (`সেলফ রুকইয়াহ গাইড (ফাইনাল) (1).pdf`; Issue #54). On 2026-10-12 the user privately supplied the original legacy Word `.doc` file. Its SHA-256 is `8b9af4677cec5c4b8964a431a47c076a7a59e862d91606caede8ad6141257f24`. Local LibreOffice conversion recovered 125,503 Bengali codepoints and 30,286 Arabic codepoints in Word XML; unlike the broken PDF, the source is legible. **Do not commit the source, full extracted passages, or private editorial card package into public GitHub.** An initial 160-candidate internal index was generated (23 dua, 101 Quran-text blocks, 8 amal, 15 supplements, 4 ghusl, 8 guides, 1 compiled prayer). These are *unverified draft blocks*, not 160 separate authenticated religious actions. Human verification, de-duplication, rights clearance and source references are still required before publication.

For every entry captured from the exact source, store:
- Stable source ID, source file **SHA-256**, publisher/edition, licensed-use decision, page or chapter/heading and a **verbatim short source excerpt**.
- Category: dua / amal / quran / hadith / ruqyah guide / ghusl guide / audio / other approved material. Distinguish article and supplemental guidance from canonical Qur'an/Hadith text.
- Original Arabic where applicable, **human-reviewed** Bangla translation/transliteration, source reference, author's notes clearly separated from scripture.
- Repetition, duration, timing, procedure only when explicitly present in approved source; store `null` otherwise, never infer.
- Link to independently verified canonical source, original document section and reviewer before a Qur'an/Hadith resource may be published.
- Visibility, rights/attribution, review state and final publish state according to existing `content_items` CMS.

## Source → admin drafts → approved catalog (no new patient-data schema yet)

1. **Acquire correct source.** Verify rendered page readability and Arabic/Bangla legibility; record hash. If corrupted, stop extraction until owner supplies DOCX/clean PDF.
2. **Inventory all real entries.** Parse chapter-by-chapter, preserve references and page locators. Count actual distinct dua, amal, ghusl and audio instructions after deduplication. Do **not** promise a guessed number from meeting notes.
3. **Structured draft material.** Create an editor draft for each distinct canonical or procedural resource with original references and language fields. AI may draft *noncanonical summaries/metadata* based on extracted text; it must not generate new ayah/hadith wording, religious rulings or patient dosing.
4. **Review & rights.** Sukun Life reviewer verifies Arabic text and Bangla translation against authoritative source, confirms publication permissions and signs off. Rejected/unverified stays private and never enters patient matching.
5. **Publish once, reuse everywhere.** A published, patient-accessible `content_items.id` is canonical for guest resources, personal routines and patient plans. Reuse `plan_action_resources`, not duplicated pasted documents.
6. **Prescription upload.** Existing private PDF/photo upload and Gemini draft actions stay intact. `resource_match_query` is a **search query only**. The client resolves it deterministically against published patient-accessible resources, displaying ranked choices to Admin, **never automatically linking an arbitrary ID**.
7. **Ready-to-review patient handout.** Generate a *draft* reading/checklist/audio link packet by composing approved resource content and exact practitioner-provided instructions only. Where a relevant library entry is missing/unverified, create an **Admin content request** instead of hallucinating a PDF. Human review is required before patient assignment/publication.
8. **Fallback.** AI failure must preserve the original prescription and keep the manual action builder/Resource Picker usable. No raw model quota, patient data or secrets in logs.

## Source catalog draft transport contract (local/staging only)

Path: `docs/resources/source_catalog_template.json`. Its `entries` array remains EMPTY intentionally because item-level religious-source and publication-rights verification are pending. A local/private draft index has been prepared from the now-readable original. Do not seed production data. Each later entry should contain:

```json
{
  "id": "SOURCE_STABLE_ID",
  "kind": "dua",
  "title_bn": "TITLE_FROM_SOURCE",
  "source_page": 1,
  "source_section": "VERIFIED_SECTION",
  "source_excerpt": "SHORT_EXACT_SOURCE_QUOTE",
  "reference": null,
  "arabic_text": null,
  "bangla_text": null,
  "transliteration_bn": null,
  "repeat_count": null,
  "time_rule": null,
  "verification_status": "pending",
  "rights_status": "pending"
}
```

`SOURCE_STABLE_ID`, title and excerpt above are **placeholders**, not real materials. The template contains no such populated entry.

## Acceptance tests

- All entries map to a rendered/legible source section, no invented text, count, frequency or healing guarantees.
- Arabic script and Bangla spelling variants match appropriately; the matching code never loses Bengali vowel marks.
- Existing unpublished, assigned-only without applicable ownership, and staff-only contents never become public; only published patient-accessible resources can be suggested for review.
- AI suggests **approved** resource IDs only after deterministic repository lookup; orphan match query does not produce a fake item.
- PDF/docx export, when implemented, uses *only source-verified catalog content and explicit prescription fields*; draft first; no auto-publish.
- Browser smoke from **same** Flutter app's approved GitHub Pages preview; no parallel websites or native packaging.
- Staging/synthetic tests before any production schema or sensitive data change.

**Source received:** original Word `.doc` recovered locally (hash above). Next blockers are canonical Arabic/Hadith source verification, legal re-publication rights, editorial review and safe admin-only import. Never infer that code or private local drafts are already staged/published.
