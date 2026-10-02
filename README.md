# Sukun Life App

Standalone mobile application for Sukun Life, focused on personalized patient care plans, prescription-to-action conversion, reminders, adherence tracking, and a curated Islamic/Ruqyah resource library.

> **Important:** The existing public website and existing internal Sukun Life dashboard are not to be modified by this project. This repository is for a new, independent app ecosystem.

## Start here

For Codex/developers, read these files in order:

1. [`AGENTS.md`](./AGENTS.md) — non-negotiable development and brand rules.
2. [`CODEX_START_HERE.md`](./CODEX_START_HERE.md) — complete product specification, architecture, data model, UI, AI workflow, security, roadmap, and implementation order.
3. [`docs/AI_FAILOVER_ARCHITECTURE.md`](./docs/AI_FAILOVER_ARCHITECTURE.md) — mandatory silent four-key Gemini failover architecture for Prescription → Action generation.
4. [`docs/ISLAMIC_RESOURCES_ARCHITECTURE.md`](./docs/ISLAMIC_RESOURCES_ARCHITECTURE.md) — dedicated Qur'an/Hadith/Dua/Ruqyah/resources hub, verification rules, CMS behavior, and patient-plan resource linking.
5. [`IMPLEMENTATION_CHECKLIST.md`](./IMPLEMENTATION_CHECKLIST.md) — practical execution checklist.

## Product in one sentence

**Sukun Life App = Islamic Resource App + Personalized Patient Care Plan + Reminders + Amal/Task Tracking + Super Admin Management in the same Flutter app.**

## Main product areas

### 1. Patient Care

- Prescription
- Personalized care plan
- Daily actions/tasks
- Reminders
- Done / Snooze / Skip
- Progress and adherence
- Super Admin patient/plan management

### 2. Dedicated Islamic Resources

The app must have a separate top-level **Resources / ইসলামিক রিসোর্স** area, not mixed into patient-care screens.

Planned resource sections:

```text
Islamic Resources
├── Qur'an
├── Hadith
├── Dua & Azkar
├── Ruqyah
├── Books & PDFs
├── Articles & Guides
├── Audio
└── Video
```

A resource can also be assigned to a patient's plan by linking the same canonical `content_item`; do not duplicate the resource for each patient.

Qur'an/Hadith canonical text and references must come from verified approved sources and must never be treated as generic AI-generated copy. Full requirements are in `docs/ISLAMIC_RESOURCES_ARCHITECTURE.md`.

## Proposed stack

- Flutter — Android/iOS app
- Supabase — PostgreSQL, Auth, Row Level Security, Edge Functions
- Firebase Cloud Messaging — push notifications
- Local notifications — scheduled reminders on device
- External URLs/CDN/YouTube — audio, video, PDF media sources
- Gemini API — prescription text → suggested structured actions, always requiring human review before publish
- Server-side AI Router — four Gemini API key slots with silent failover and manual fallback if all are unavailable

## AI availability rule

The Super Admin must not see Gemini quota/credit/rate-limit/key errors during normal use.

Prescription → Action generation goes through a server-side `AiRouter` / `GeminiKeyPool` using these secret slots:

```text
GEMINI_API_KEY_1
GEMINI_API_KEY_2
GEMINI_API_KEY_3
GEMINI_API_KEY_4
```

If an earlier slot is quota-exhausted or unavailable, the backend automatically tries the next healthy slot. If all four are unavailable, the original prescription remains safe and the workflow falls back to the manual Action Builder without exposing raw provider/quota details.

Do not assume four keys automatically mean four independent quota pools; production configuration must verify quota scope and comply with provider terms. Full implementation requirements are in `docs/AI_FAILOVER_ARCHITECTURE.md`.

## Brand source of truth

The app must visually follow the official Sukun Life identity and website: https://www.sukunlife.com/

Never redraw or modify the Sukun Life logo. Use only the official supplied logo asset. Full rules are in `CODEX_START_HERE.md` and `AGENTS.md`.

## Current implementation

Phase 0 provides an Android/iOS Flutter scaffold in `app/` with:

- application identifier `com.sukunlife.app`
- Riverpod state management and GoRouter navigation
- guest, patient, and super-admin session roles
- server-verified-role-aware route shells
- Sukun Life color and typography tokens
- fail-closed compile-time Supabase configuration with an approved production
  project guard
- a Supabase local-development/migration structure

Phase 1 adds the initial PostgreSQL schema and explicit Data API security:

- versioned prescriptions and care plans
- recurring plan actions, generated task instances, and append-only completion events
- reusable content resources with public/patient/assigned/staff visibility
- source-verification requirements for published Qur'an/Hadith records
- RLS on every public application table
- database-verified super-admin authorization and patient isolation
- an idempotent, ownership-checked `record_task_completion` database function
- pgTAP tests for patient isolation and resource visibility

Phase 2 completes the Super Admin core patient and care-plan workflow:

- a searchable patient list and patient detail screen
- server-only patient Auth provisioning with generated or explicit patient IDs
- temporary credentials flagged for mandatory first-login replacement
- transactional patient profile/role/record/audit finalization
- original prescription capture with immutable version 1
- idempotent request IDs for patient and prescription creation
- Super Admin-only database operations and pgTAP authorization coverage
- one editable draft per patient and immutable published action history
- structured daily/selected-day actions with optional count, duration, explicit
  timing, reminder intent, and review status
- canonical `content_item` resource links without per-patient content copies
- action add/edit/reorder/reject controls and a patient-sanitized preview
- guarded publishing that requires at least one approved action and refuses any
  unresolved action or inaccessible resource
- full plan version history, safe version copying with mandatory re-review,
  automatic deactivation of the previous active plan, and archival
- audited, idempotent workflow functions that retain RLS and verify the
  database-backed Super Admin role

Phase 3 completes the patient-care milestone with:

- patient sign-in using Sukun Patient ID, international phone number, or an
  administrator email
- generic credential errors that do not expose patient-code-to-phone lookups
- mandatory first-login replacement of temporary credentials
- a Today screen generated only from the patient's active approved plan
- local-date task occurrences without inventing an exact time when none was
  prescribed
- next-action and daily completion progress cards
- idempotent Done, Snooze, and Skip events through the protected completion RPC
- My Plan and patient-visible prescription views
- an RLS-protected linked-resource detail view from Today and My Plan, with
  safe HTTPS/YouTube handoff when external media is present
- patient 7-day and 30-day tracked-completion views
- a Super Admin 7-day progress summary on each patient record
- encrypted, account-partitioned write-ahead storage for offline completion events
- automatic retry of queued events with the original idempotency key on the
  next Today refresh/app session
- RLS-backed isolation so one patient cannot read or update another patient's
  care activity

Progress currently reports materialized task activity. Reminder-driven future
task materialization remains in its documented later phase.

The offline queue stores task identifiers and patient interactions in Android
Keystore/iOS Keychain-backed secure storage; it never stores prescription text
or credentials. Android support therefore starts at API 23.

Phase 4 implementation is present across the backend and Flutter review
workflow. The `prescription-to-actions` Edge Function provides:

- database-verified Super Admin access and server-side prescription loading
- strict normalized action-schema validation with mandatory ambiguity review
- deterministic Gemini slot 1 → 2 → 3 → 4 failover
- timeout retry, invalid-key disabling, and database-backed cooldown state
- conservative shared-quota handling through `GEMINI_QUOTA_SCOPE_1..4`
- idempotent request/result storage without automatic plan publication
- neutral manual fallback responses that contain no quota/key/provider details
- structured operational logs containing slot IDs but no credentials or raw
  prescription text

The Flutter Super Admin workflow now provides:

- a Generate Action Suggestions control only on editable plans linked to a
  stored prescription
- a review screen that keeps the original prescription visible beside editable
  Bangla/English suggestions and ambiguity warnings
- deterministic matching against published canonical resource titles, with no
  resource linked until the administrator explicitly selects it
- idempotent draft imports that retain `needs_review` for ambiguous output and
  never approve or publish AI output automatically
- a neutral Manual Action Builder route when every configured AI slot is
  unavailable, without provider, quota, status-code, or key details

The remaining production verification is a hosted failover integration run
with real configured Gemini quota scopes. Repository tests already cover
Bangla/mixed-language response parsing, schema rejection, resource matching,
neutral fallback UI, and simulated four-slot routing behavior.

Phase 5 now includes a dedicated, patient-care-independent Islamic Resources
hub and a server-authorized Super Admin CMS. Guests and patients can browse the
eight required sections, search permitted published metadata, filter by
section/type, and open canonical resource details. Admins can create categories
and resources; save drafts; preview; submit for review; verify or reject
canonical sources; publish; unpublish; and archive without deleting history.

The content schema records Surah/Ayah ranges, approved Arabic and Bangla source
metadata, Hadith collection/book/number/grade, book/chapter relationships,
author/publisher/rights information, visibility, and external-media metadata.
Qur'an and Hadith cannot be verified or published without approved source
metadata, and `generative_ai` is rejected as a canonical source even for a
draft. Reviewer notes live in a separate Super-Admin-only history table and are
not patient-readable. Published content must be explicitly unpublished before
editing; editing canonical content resets its verification state.

Database RLS remains the source of truth: guest searches receive only published
public rows, patients also receive permitted patient/assigned rows, and
staff-only or unpublished content is not returned. Canonical resources continue
to be linked into any number of care plans by ID instead of being copied per
patient. The resource hub supports Surah-to-Ayah browsing, selected/Ruqyah Ayat
collections, topic-wise Hadith browsing, and dedicated Dua/Azkar and Ruqyah
taxonomies.

Phase 6 adds external media support while retaining the canonical resource and
visibility model:

- direct HTTPS audio playback with seek, playback speed, saved resume position,
  background playback, and Android/iOS lock-screen controls
- supported YouTube IFrame playback without extracting or redistributing audio
- safe operating-system viewers for direct video, external PDF, and webpage URLs
- HTTPS/media identifier validation and neutral unavailable-link errors
- visible rights/source notes, CMS validation, and a database publication guard
  requiring rights metadata for published media

The client-supplied official logo is stored unchanged at `app/assets/brand/sukunlife_logo.png`. Do not modify, recolor, crop, distort, or replace it with generated artwork.

### Run the app

For a production build, copy `app/config/production.example.json` to the ignored
`app/config/production.json`, replace only the client-safe Supabase publishable
key, and run:

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=config/production.json
```

The production runtime refuses a missing backend or any Supabase URL other than
the approved project in `docs/PRODUCTION_ENVIRONMENT.md`. For a public-only local
preview, run without defines. `SUPABASE_ANON_KEY` remains a temporary compatibility
alias, but new configuration should use `SUPABASE_PUBLISHABLE_KEY`. Never put the
Gemini credentials, Supabase service-role key, or Firebase server credentials in
the Flutter configuration.

### Verify

```bash
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Database tests require Docker Desktop or Podman:

```bash
npx supabase start
npx supabase test db
npx supabase db lint --local
```

Edge Function validation and type checks can run without Docker:

```bash
npx deno test --allow-import supabase/functions/admin-create-patient/validation_test.ts
npx deno check --allow-import \
  --config supabase/functions/admin-create-patient/deno.json \
  supabase/functions/admin-create-patient/index.ts
```

Public Auth signup is disabled in local Supabase configuration. Patient and admin accounts must be provisioned by a trusted server/admin workflow; apply the same setting to the hosted Supabase project.
