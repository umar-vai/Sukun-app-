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
