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
- compile-time Supabase configuration
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

Phase 3 is in progress. The first patient-care milestone now provides:

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
- RLS-backed isolation so one patient cannot read or update another patient's
  care activity

The remaining Phase 3 work is linked-resource opening, multi-day
progress/adherence, the Super Admin progress view, and an offline-safe local
completion queue.

The client-supplied official logo is stored unchanged at `app/assets/brand/sukunlife_logo.png`. Do not modify, recolor, crop, distort, or replace it with generated artwork.

### Run the app

```bash
cd app
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_CLIENT_SAFE_PUBLISHABLE_KEY \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID
```

Omit the `dart-define` values for a public-only local preview. Gemini credentials, the Supabase service-role key, and Firebase server credentials must never be passed to Flutter.

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
