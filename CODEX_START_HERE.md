# CODEX START HERE — Sukun Life App Master Plan

This document is the single master specification for building the Sukun Life App. Codex should read this file completely before implementing anything.

---

# 1. Project goal

Build a new, standalone Sukun Life mobile application that serves two audiences:

1. **General users** who want authentic Islamic/Ruqyah resources.
2. **Existing Sukun Life patients** who need a personalized prescription/care-plan experience with reminders and adherence tracking.

The app's primary differentiator is **not** merely Islamic content. The core value is:

> Practitioner/Admin prescription → structured patient actions → scheduled reminders → task completion tracking → patient progress visibility.

The app must remain useful for ordinary users, but patient care is the product core.

---

# 2. Hard boundaries

## Existing public website

Do **not** modify, replace, extend, inject into, or depend on the current public website.

Official website is a brand/reference source only:

- https://www.sukunlife.com/

## Existing internal Sukun dashboard

Sukun Life already maintains patient profiles, sessions and prescriptions in an existing dashboard.

For MVP:

- Do not modify that dashboard.
- Do not write back to it.
- Admin can read/copy the existing prescription and create a structured app plan in the new app.

Future integration is optional and may be added only after Sukun provides explicit API/read-only database access.

Preferred future integration priority:

1. Existing official API
2. Read-only database integration
3. Manual import/copy fallback

No direct Flutter-to-old-database connection.

---

# 3. Product model: one app, multiple roles

Use one Flutter application.

Roles:

- `guest`
- `patient`
- `super_admin`

Optional future roles:

- `practitioner`
- `content_editor`
- `reviewer`
- `support`
- `analyst`

## Guest mode

Guest does not require login.

Can access public resources such as:

- Dua & Amal
- Ruqyah Ayat
- Ruqyah Audio
- Guides
- Articles/Blog
- Videos
- PDFs
- Books/chapters
- Prayer times
- Qibla
- Quran/Hadith resources when implemented

Guest cannot access any patient data.

## Patient mode

Patient logs in and gets a personalized dashboard.

Patient can:

- see own current prescription summary
- see today's care plan
- receive reminders
- open assigned audio/video/PDF/resources
- mark a task `done`, `snoozed`, or `skipped`
- see own progress/adherence
- see only patient-visible notes
- use public resources

Patient cannot:

- create/edit/delete content
- create patients
- see other patients
- modify prescribed plan rules
- see staff-only notes

## Super Admin mode

The same Flutter app becomes editable/admin-capable after server-verified `super_admin` login.

Super Admin can:

- create/manage patients
- create temporary login credentials
- create/edit/archive patient plans
- convert prescription text into draft actions
- approve/edit AI-suggested actions
- add/edit/archive content
- assign resources to plans
- set schedules and reminders
- send notifications
- view adherence/progress reports
- preview content as patient
- manage app settings

---

# 4. Brand and UI system

The app must visually follow official Sukun Life identity. Do not invent a generic Islamic visual system.

## Official brand source of truth

- Official website: https://www.sukunlife.com/
- Official supplied Sukun Life logo artwork
- Official Sukun Life brand guidelines when present

## Design tokens

```dart
SukunBlue  = Color(0xFF0F9BD7);
DeepTide   = Color(0xFF0A70A8);
NightNavy  = Color(0xFF0D2B45);
Mist       = Color(0xFFE8F5FC);
Saffron    = Color(0xFFF2C45A); // limited accent only
```

Recommended semantic use:

- Primary button/action: Sukun Blue
- Secondary emphasis: Deep Tide
- Headline/body dark text: Night Navy
- Soft page/card surfaces: White + Mist
- Warm limited accent: Saffron
- Success/error colors should be accessible semantic colors, not arbitrary brand replacements

## Typography

English:

- Poppins 300 / 400 / 600 / 700

Bangla:

- Anek Bangla — display/headline
- Hind Siliguri — UI/body copy
- Tiro Bangla — Qur'anic/Hadith text where appropriate

## Logo

Use only the official original logo file.

Never:

- redraw
- recolor
- stretch
- rotate
- crop into a different mark
- add glow/drop shadow
- rearrange logo elements
- generate an AI replacement

Expected project path after official asset is supplied:

```text
app/assets/brand/sukunlife_logo.png
app/assets/brand/sukunlife_logo_white.png   # only if officially supplied
```

Do not manufacture missing variants.

## Visual tone

The design should feel:

- tranquil
- trustworthy
- premium but restrained
- faith-anchored
- patient-friendly
- breathable and uncluttered

Avoid:

- dominant green/gold simply because it is Islamic
- loud gradients
- generic mosque-heavy decoration on every screen
- glassmorphism everywhere
- excessive shadows
- low-contrast text
- AI-looking decorative imagery

---

# 5. Recommended app navigation

## Patient/Guest bottom navigation

```text
Home
My Plan
Resources
Progress
Profile
```

For guests, tapping `My Plan` or `Progress` should request patient login.

## Admin navigation

Admin can use a different shell/navigation state within the same app:

```text
Dashboard
Patients
Plans
Content
Reports
Settings
```

Admin must have `Preview as Patient` for content/plan review.

---

# 6. Core patient experience

After patient login, the home screen should answer:

> "What do I need to do now/today?"

Priority sections:

1. Greeting + current plan/day
2. Next action
3. Today's task list
4. Completion progress
5. Prescription shortcut
6. Assigned resources
7. Prayer-time utility (secondary)

Example:

```text
Assalamu Alaikum, Rahim
Day 12 of your current plan

NEXT
9:30 PM — Jin & Hasad Ruqyah — 15 min
[Play]

TODAY
✓ Morning Amal
✓ Supplement
○ Ruqyah Audio
○ Special Amal
○ Night Azkar

Progress: 2/5
```

---

# 7. Prescription → Action Engine

This is the most important domain feature.

## Key distinction

- **Prescription** = original practitioner/admin text
- **Action** = structured app-understandable rule

Example prescription:

```text
সকাল-সন্ধ্যা আয়াতুল কুরসি ৩ বার পড়বেন।
জিন-হাসাদ রুকইয়াহ অডিও প্রতিদিন ১৫ মিনিট শুনবেন।
রাতে অলিভ অয়েল ব্যবহার করবেন।
১৫ দিন পর ফলোআপ করবেন।
```

Suggested structured actions:

```text
1. Ayatul Kursi ×3 — Morning — Daily
2. Ayatul Kursi ×3 — Evening — Daily
3. Jin & Hasad Ruqyah — Audio — 15 min — Daily
4. Olive Oil instruction — Night — Daily
5. Follow-up — after 15 days
```

## Processing flow

```text
Original Prescription
        ↓
AI/Rules Parse
        ↓
Suggested Action Drafts
        ↓
Resource Matching
        ↓
Admin Review/Edit
        ↓
Approve & Publish
        ↓
Care Plan Version
        ↓
Task Instances + Reminders
        ↓
Patient Completion
        ↓
Progress/Adherence
```

## AI role

AI is only a parser/assistant.

Allowed AI tasks:

- split instructions into candidate actions
- extract counts
- extract duration
- detect morning/evening/night windows
- detect frequency
- suggest content-resource matches
- identify ambiguity

AI must not:

- prescribe
- invent treatment
- change dosage
- invent exact reminder time
- infer religious rulings
- publish automatically

## Human approval

Every AI-generated action must have a review state:

```text
draft
needs_review
approved
rejected
```

Only `approved` actions can be published to a patient plan.

## AI backend

Call AI from a server-side Supabase Edge Function or backend.

Never expose API keys in Flutter.

Provider can be OpenAI or Gemini. Keep provider implementation behind an interface so it can be changed later.

### Suggested AI output contract

```json
{
  "actions": [
    {
      "type": "amal",
      "title": "Ayatul Kursi",
      "resource_match_query": "Ayatul Kursi",
      "count": 3,
      "duration_minutes": null,
      "frequency": "daily",
      "time_windows": ["morning", "evening"],
      "exact_time": null,
      "instruction": "৩ বার পড়বেন",
      "confidence": 0.95,
      "needs_review": false,
      "ambiguities": []
    }
  ]
}
```

If exact time is absent, keep it `null`.

If text says "কয়েকবার", do not invent a number. Return ambiguity.

---

# 8. Prescription sections from existing workflow

Current Sukun prescription/session patterns can include:

- Amal
- Supplement
- Gosol
- Audio
- Special Amal
- Comment/Instruction
- Counselling
- Outcome
- Effect/Diagnosis

Patient-facing default visibility:

| Field | Default visibility |
|---|---|
| Amal | patient |
| Audio | patient |
| Supplement instruction | patient |
| Gosol/routine | patient |
| Special Amal | patient |
| General patient instruction | patient |
| Diagnosis | staff_only |
| Effect observations | staff_only |
| Internal comments | staff_only |
| Outcome | staff_only |
| Private counselling note | staff_only |

Never assume every existing dashboard field should be shown to patients.

---

# 9. Care plan model

A patient can have many historical plans but only one active plan by default.

Never overwrite previous clinical history.

Example:

```text
Plan v1 — inactive
Plan v2 — inactive
Plan v3 — active
```

Publishing a newer plan can:

- deactivate the previous plan
- cancel future local schedules belonging to old actions
- generate future task instances for the new plan
- retain all historical task completion records

---

# 10. Action vs task instance

Do not treat these as the same entity.

## Plan Action

Recurring rule:

```text
Ayatul Kursi ×3
Daily
07:00
30 days
```

## Task Instance

Specific occurrence:

```text
2026-10-01 07:00 — Ayatul Kursi
2026-10-02 07:00 — Ayatul Kursi
2026-10-03 07:00 — Ayatul Kursi
```

This enables daily adherence tracking.

Patient task states:

```text
pending
completed
snoozed
skipped
missed
cancelled
```

---

# 11. Resource/content management

Super Admin must manage content from the same app.

Content types:

```text
dua
amal
quran
hadith
article
guide
audio
video
pdf
book
book_chapter
external_link
```

Core fields:

```text
id
type
title
title_bn
slug
summary
body
arabic_text
bangla_text
translation
reference_text
category_id
tags
thumbnail_url
media_source_type
media_url
youtube_video_id
visibility
status
created_by
updated_by
created_at
updated_at
archived_at
```

Visibility:

```text
public
patient_only
assigned_only
staff_only
```

Lifecycle:

```text
draft
review
published
archived
```

Prefer archive/unpublish over hard delete.

---

# 12. External media strategy

Large media should usually stay outside Supabase storage.

Store metadata + URL.

Supported media source types:

```text
direct_audio_url
direct_video_url
youtube
external_pdf
external_web
```

## Direct audio

Preferred for native player experience.

Support:

- play/pause
- seek
- background playback
- lock-screen controls
- resume position
- playback speed
- repeat/sleep timer later

## YouTube

Use official supported YouTube playback/embed behavior.

Do not extract YouTube audio as raw MP3.

## PDF

Use external PDF URL in an in-app viewer or safe external viewer.

## Licensing

Do not copy third-party content into Sukun-controlled storage unless permission/license is confirmed.

---

# 13. Prayer time and Qibla

These are utility modules, not admin-managed content.

## Prayer time

Use location + a configurable calculation method.

Allow:

- location permission
- manual city selection fallback
- calculation-method settings

## Qibla

Use location/GPS + compass/sensor where available.

Include clear sensor-calibration and unavailable-sensor states.

Build these after the patient care core flow works.

---

# 14. Notifications and reminders

Use a hybrid system.

## Local notifications

Primary for exact patient reminders after plan sync.

Advantages:

- works without active internet
- reliable scheduled reminders within OS constraints

## Firebase Cloud Messaging

Use for:

- plan updated
- content announcement
- admin push
- sync request
- generic remote notification

Do not promise DND/silent-mode bypass.

Reminder data should support:

```text
action_id
task_instance_id
scheduled_at
timezone
notification_type
status
opened_at
snoozed_until
```

---

# 15. Authentication and patient account creation

Patient should not authenticate with a public sequential ID alone.

Admin creation flow:

```text
Name
Phone
Patient reference ID
Temporary PIN/invite
```

First login:

1. Patient ID/phone + temporary credential
2. verify
3. force new PIN/password
4. optional biometric unlock on device

Never store plaintext permanent passwords.

Super Admin should use stronger authentication; add MFA when practical.

---

# 16. Database model — initial proposal

Use PostgreSQL/Supabase.

Core tables:

```text
profiles
user_roles
patients
patient_external_refs

prescriptions
prescription_versions

care_plans
plan_actions
task_instances
task_completions

content_categories
content_items
content_tags
content_item_tags

plan_action_resources

notification_devices
notification_events

admin_audit_logs
app_settings
```

Suggested relationships:

```text
auth.users
  └─ profiles
      ├─ user_roles
      └─ patients (when patient role)

patients
  ├─ prescriptions
  ├─ care_plans
  │   └─ plan_actions
  │       ├─ task_instances
  │       │   └─ task_completions
  │       └─ plan_action_resources → content_items
  └─ notification_devices
```

---

# 17. Suggested fields for core tables

## `patients`

```text
id uuid pk
user_id uuid nullable unique
patient_code text unique
full_name text
phone text
status text
created_by uuid
created_at timestamptz
updated_at timestamptz
```

## `prescriptions`

```text
id uuid pk
patient_id uuid
source_type text        -- manual | imported | future_external_sync
source_external_id text nullable
raw_text text
session_date date nullable
visibility text
created_by uuid
created_at timestamptz
```

## `care_plans`

```text
id uuid pk
patient_id uuid
prescription_id uuid nullable
version int
name text
start_date date
end_date date nullable
status text             -- draft | active | inactive | archived
published_at timestamptz nullable
published_by uuid nullable
created_at timestamptz
updated_at timestamptz
```

## `plan_actions`

```text
id uuid pk
care_plan_id uuid
type text
title text
instruction text nullable
resource_id uuid nullable
count_target int nullable
duration_minutes int nullable
frequency_rule jsonb
time_window text nullable
exact_time time nullable
start_date date
end_date date nullable
sort_order int
review_status text
ai_source jsonb nullable
created_at timestamptz
updated_at timestamptz
```

## `task_instances`

```text
id uuid pk
plan_action_id uuid
patient_id uuid
occurrence_date date
scheduled_at timestamptz nullable
timezone_offset_minutes integer
status text
completed_at timestamptz nullable
snoozed_until timestamptz nullable
skip_reason text nullable
created_at timestamptz
```

`occurrence_date` is the patient-local calendar day represented by the task.
`scheduled_at` must remain null when the approved action does not contain an
explicit exact time; a technical task generator must never invent a clinical
schedule time. `timezone_offset_minutes` records the offset used when converting
an explicitly supplied local time into an instant. Notification timezone and
delivery configuration remain separate concerns.

## `content_items`

Use fields from section 11 plus indexed title/category/status/visibility fields.

---

# 18. Supabase RLS policy requirements

RLS must exist before production data is used.

Minimum rules:

## Patient

Can:

- select own patient profile
- select own active/historical patient-visible plans
- select own task instances
- update only allowed completion fields for own task instances
- select public/patient-visible content

Cannot:

- select another patient's record
- insert/update/delete content
- create plans
- change plan rules
- read staff-only records

## Super Admin

Can manage app records via verified role.

Do not trust a role string sent by client UI.

## Testing

Add automated SQL tests proving tenant/patient isolation.

---

# 19. Suggested Flutter architecture

Start with a feature-first architecture.

```text
app/
  lib/
    app/
      app.dart
      router.dart
      theme/
    core/
      auth/
      database/
      notifications/
      media/
      errors/
      utils/
    features/
      onboarding/
      auth/
      home/
      patients/
      prescriptions/
      care_plans/
      tasks/
      resources/
      progress/
      prayer_times/
      qibla/
      admin/
      settings/
  assets/
    brand/
    icons/
```

State management: choose one consistent production-grade option such as Riverpod and document the choice.

Routing: use a declarative router such as GoRouter.

Do not over-engineer with unnecessary clean-architecture boilerplate before core flows work.

---

# 20. Supabase project structure

```text
supabase/
  migrations/
  functions/
    prescription-to-actions/
    send-notification/
  tests/
    rls_patient_isolation.sql
    action_generation.sql
  seed.sql
```

Never commit real secrets.

---

# 21. Environment variables

Client-safe Flutter variables may contain only public identifiers/anon keys intended for client use.

Server secrets belong in Supabase/CI secret storage.

Typical configuration:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
FIREBASE_PROJECT_ID

# server-only, never Flutter source
AI_PROVIDER
OPENAI_API_KEY
GEMINI_API_KEY
SUPABASE_SERVICE_ROLE_KEY
```

---

# 22. MVP screens

## Public/Patient

1. Splash
2. Guest / Patient Login entry
3. Patient login
4. Patient first-login credential reset
5. Home
6. My Plan
7. Task details
8. Prescription details
9. Resource library
10. Audio player
11. Video viewer
12. PDF viewer
13. Article/guide reader
14. Progress
15. Profile/settings

## Super Admin

1. Admin dashboard
2. Patient list/search
3. Create patient
4. Patient detail
5. Prescription input/view
6. Generate actions from prescription
7. Action review/editor
8. Plan preview
9. Publish plan
10. Content library
11. Add/edit content
12. Notifications
13. Reports/progress
14. App settings

## Secondary utilities

15. Prayer times
16. Qibla
17. Quran/Hadith later if verified datasets are ready

---

# 23. Admin plan-builder UX

For a patient:

```text
Patient Detail
  → New Prescription / Paste Prescription
  → Generate Actions
  → Review Suggested Actions
  → Resolve Missing Time/Count/Resource
  → Preview as Patient
  → Publish
```

Action editor supports:

```text
Type
Title
Linked Resource
Count
Duration
Frequency
Morning/Evening/Night
Exact Time
Start/End
Instruction
Reminder toggle
```

Admin can also add actions manually without AI.

---

# 24. Content CMS inside the app

Super Admin workflow:

```text
Content
  → Add
  → choose type
  → fill metadata/body/URL
  → Save Draft
  → Preview
  → Publish Now
  → Published
```

The server-verified Super Admin is the final content publisher. The normal CMS
does not require self-review, source-verification approval, or a second
verification state before publishing any content type. Qur'an/Hadith source,
reference, translation, and rights metadata remain mandatory where applicable;
direct publishing never permits AI-generated canonical religious text.

Editing content should update database content without requiring a Play Store/App Store release.

A software feature change still requires app release.

---

# 25. Progress/adherence reporting

Patient view:

- today's completion
- 7-day trend
- active plan progress
- optional streak, but avoid gamification that trivializes care

Admin view:

- today's completion percentage
- 7/30 day adherence
- repeatedly missed task types
- plan ending soon
- follow-up due

Do not make clinical claims from adherence alone.

---

# 26. Offline behavior

Cache:

- current active plan
- today's task list
- core text instructions
- selected downloaded resources if supported

Local task completion should queue and sync when connectivity returns.

Avoid silently losing a completion event because the device was offline.

---

# 27. Search

Resource search should support:

- title
- Bangla title/text where appropriate
- category
- tags
- type

Admin patient search:

- name
- patient code
- phone

---

# 28. Safety/quality rules

- AI output requires human approval.
- Medical/supplement dosage must never be inferred.
- Internal notes must not leak to patient views.
- Quran/Hadith text should come from verified datasets/source material, not model-generated text.
- Resource references should be stored where applicable.
- Third-party media rights must be respected.

---

# 29. Analytics/error monitoring

Recommended later in MVP:

- Firebase Analytics or PostHog for product events
- Crashlytics or Sentry for crash/error reporting

Track events such as:

```text
login_success
plan_opened
task_completed
task_snoozed
audio_started
audio_completed
resource_opened
admin_plan_published
```

Never send sensitive free-text prescription/clinical content into generic analytics platforms.

---

# 30. Testing requirements

Minimum test layers:

## Flutter

- unit tests for action/task calculations
- widget tests for role-gated UI
- integration test for login → plan → completion

## Supabase

- RLS isolation tests
- role authorization tests
- plan versioning tests
- task generation tests

## AI parser

Create fixtures for Bangla mixed-text prescriptions.

Tests must verify that ambiguous instructions remain ambiguous rather than being invented.

---

# 31. CI/CD

Set up GitHub Actions after project scaffold exists.

Recommended jobs:

```text
flutter analyze
flutter test
format check
Supabase SQL/lint/test where practical
```

Do not commit production secret files.

---

# 32. Implementation phases

## Phase 0 — Foundation

- Flutter project scaffold
- theme tokens/fonts
- Supabase project wiring
- auth shell
- role model
- base routing
- migrations skeleton
- RLS strategy/tests

## Phase 1 — Unique Sukun core

Build this end-to-end before secondary utilities:

```text
Admin creates patient
→ adds/pastes prescription
→ creates actions manually
→ publishes plan
→ patient logs in
→ patient sees today's plan
→ patient completes/skips/snoozes
→ admin sees progress
```

## Phase 2 — Prescription AI assistant

- Edge Function
- structured output schema
- review UI
- ambiguity handling
- resource matching suggestions

## Phase 3 — Content/resource CMS

- resource library
- audio URL player
- YouTube/video
- PDF
- articles/guides
- book structure
- public/assigned visibility

## Phase 4 — Notifications

- local reminder scheduling
- FCM
- plan-update push
- snooze behavior

## Phase 5 — Islamic utilities

- prayer times
- Qibla
- verified Quran/Hadith modules if approved

## Phase 6 — Hardening/release

- full RLS audit
- offline sync
- crash analytics
- performance
- accessibility
- Android/iOS release setup

---

# 33. Definition of MVP done

MVP is not done until this real flow works:

1. Super Admin logs into the same app.
2. Admin creates a patient.
3. Admin creates/pastes prescription source text.
4. Admin creates or AI-generates candidate actions.
5. Admin reviews and publishes a plan.
6. Patient logs in with their account.
7. Patient sees only their own plan.
8. Patient receives scheduled reminder(s).
9. Patient can complete/snooze/skip task(s).
10. Completion syncs to backend.
11. Admin can see patient adherence/progress.
12. Admin can add/edit/archive a resource without releasing a new app version.
13. Patient can open an externally hosted audio/video/PDF resource.
14. RLS tests prove one patient cannot read another patient's data.

---

# 34. First Codex execution order

When starting development, Codex should do the following in this order:

1. Read `AGENTS.md` and this document.
2. Inspect repository state.
3. Create Flutter project under `app/`.
4. Configure packages only after choosing a minimal, justified dependency set.
5. Implement official Sukun theme tokens and typography first.
6. Add official logo asset path but do not fabricate logo artwork if asset is unavailable.
7. Add Supabase folder/config/migration baseline.
8. Define roles and RLS strategy.
9. Build authentication + role-aware router.
10. Create database migrations for patients, prescriptions, care plans, plan actions, task instances and content metadata.
11. Build manual Admin patient + plan flow before AI.
12. Build patient home/My Plan and task completion.
13. Add RLS isolation tests.
14. Only then implement AI parser Edge Function.
15. Add resource CMS + external media handling.
16. Add notification scheduling.
17. Add secondary prayer/Qibla utilities.
18. Run analyze/tests after each meaningful milestone.
19. Keep `README.md`, this file, and implementation checklist synchronized with major architecture changes.

---

# 35. Important implementation decisions already made

Do not repeatedly re-open these unless a hard technical blocker appears:

- Flutter mobile app: **Yes**
- Separate web admin required for MVP: **No**
- Same app Super Admin mode: **Yes**
- Supabase backend: **Yes**
- External media URLs by default: **Yes**
- AI auto-publish: **No**
- Existing website modification: **No**
- Existing dashboard modification in MVP: **No**
- Patient-to-patient data visibility: **Never**
- Version clinical plans instead of overwriting: **Yes**
- Human approval for prescription parsing: **Mandatory**

---

# 36. Final product statement

Sukun Life App is a branded, standalone Islamic care platform where general users can access useful Islamic/Ruqyah resources, while Sukun Life patients log in to receive personalized plans based on practitioner prescriptions. The app reminds patients what to do and when to do it, tracks their completion, and lets Sukun Life's Super Admin manage patients, care plans and content from the same Flutter application. Large media is linked from approved external sources, and AI is used only to turn existing prescription text into reviewable structured action suggestions.
