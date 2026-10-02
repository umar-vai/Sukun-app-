# AGENTS.md — Sukun Life App

This file contains mandatory instructions for Codex and all coding agents working in this repository.

## 1. Read first

Before writing code, read these files completely in this order:

1. `CODEX_START_HERE.md` — master product and engineering specification.
2. `docs/FINAL_UI_REFERENCE.md` — mandatory final visual target and UI acceptance contract.
3. `docs/AI_FAILOVER_ARCHITECTURE.md` — mandatory Prescription → Action AI reliability/failover specification.
4. `docs/ISLAMIC_RESOURCES_ARCHITECTURE.md` — mandatory dedicated Qur'an/Hadith/Dua/Ruqyah/resources architecture and verification rules.
5. `IMPLEMENTATION_CHECKLIST.md` — execution checklist.

## 2. Non-negotiable product rules

1. **Do not modify the existing Sukun Life public website.**
2. **Do not modify the existing Sukun Life internal/dashboard system in the MVP.**
3. This repository must build a **new standalone system**: Flutter app + Supabase backend + notifications + app-managed content.
4. Use **one Flutter app** with role-based modes:
   - Guest/Public
   - Patient
   - Super Admin
5. Super Admin must be able to manage patients, plans and app content from the same app.
6. Patients must only be allowed to view permitted content, use their own care plan, complete/snooze/skip their own tasks, and see their own progress.
7. Permissions must be enforced at the backend/database level with Supabase RLS, not only by hiding UI.
8. Large media should be link-based by default. Store external audio/video/PDF URLs and metadata instead of uploading all files into Supabase.
9. Prescription-to-action AI is an **assistant/parser only**, never a clinician or prescriber. AI output must never auto-publish. A Super Admin/practitioner must review and approve it.
10. Never infer medicine/supplement dosage, exact times, religious rulings, or missing instructions. Mark ambiguous fields as `needs_review`.
11. AI availability must not depend on a single Gemini credential. Implement the four-key server-side Gemini failover router described in `docs/AI_FAILOVER_ARCHITECTURE.md`.
12. Gemini quota/credit/rate-limit/provider errors must never be exposed to the Super Admin in normal UI. The backend must fail over automatically and silently.
13. The app must have a **dedicated top-level Islamic Resources area**, separate from patient-care screens. Follow `docs/ISLAMIC_RESOURCES_ARCHITECTURE.md`.
14. Qur'an/Hadith canonical text and references must come from verified approved sources. Never treat canonical religious text as generic AI-generated copy.
15. Reuse a single canonical resource across public browsing and patient plans through resource IDs/relations; do not duplicate the same content per patient.
16. Functional completion is not visual completion. The finished app must receive the dedicated final visual pass in `docs/FINAL_UI_REFERENCE.md` and must not be declared complete while major screens still look like default Flutter/Material UI.

## 3. Brand rules — mandatory

Source of truth: official Sukun Life website and official supplied Sukun Life brand assets.

Official palette to use as design tokens:

- `Sukun Blue` — `#0F9BD7`
- `Deep Tide` — `#0A70A8`
- `Night Navy` — `#0D2B45`
- `Mist` — `#E8F5FC`
- `Saffron` — `#F2C45A` — accent only, never a dominant UI color

Typography:

- English: **Poppins**
  - Light 300: display/headlines where appropriate
  - Regular 400: body
  - SemiBold 600: emphasis
  - Bold 700: strong emphasis/product names
- Bangla:
  - **Anek Bangla**: display/headline use
  - **Hind Siliguri**: standard UI/body text
  - **Tiro Bangla**: only for Qur'anic/Hadith text where appropriate

Logo rules:

- Use only the official supplied Sukun Life logo artwork.
- Never redraw it.
- Never recolor it.
- Never stretch, rotate, crop, distort, add shadows/effects, or rearrange its elements.
- Do not generate an AI replacement logo.
- If the official logo asset is not yet present, create the asset path/placeholder but do not invent one. Request/provide the official asset separately.

Visual direction:

- Calm, trustworthy, airy, faith-anchored and clinical enough for patient care.
- Prefer clean white/Mist surfaces, Sukun Blue primary actions, Night Navy text, Deep Tide secondary accents.
- Use Saffron sparingly for warmth, warnings/limited highlights, not as a page background.
- Do not use random green/gold themes just because the product is Islamic.
- Photography/illustration, if used, should feel soft, cool, modest and consistent with the official Sukun Life brand.
- Avoid visual clutter, excessive ornaments, fake glassmorphism, heavy gradients, neon colors, or generic AI-Islamic styling.
- Use `docs/FINAL_UI_REFERENCE.md` as the mandatory screen-level visual target. Default Material widgets may be used as implementation primitives, but visible surfaces must be refined into the Sukun Life design system.

## 4. Architecture rules

Target architecture:

- `app/` — Flutter app
- `supabase/` — migrations, seed, tests, Edge Functions
- Firebase Cloud Messaging for remote push
- Local notification scheduling for patient reminders
- External CDN/direct URLs/YouTube for most audio/video/PDF resources
- AI called server-side only through an Edge Function/backend
- Prescription → Action AI must go through a server-side `AiRouter` / `GeminiKeyPool`; Flutter must never choose credentials directly

Never put OpenAI/Gemini/API secret keys inside Flutter code or committed files.

### Mandatory AI key pool

Configure four server-only Gemini secret slots:

```text
GEMINI_API_KEY_1
GEMINI_API_KEY_2
GEMINI_API_KEY_3
GEMINI_API_KEY_4
```

The backend must silently try the next healthy key when the current key is quota-exhausted, rate-limited, temporarily unavailable, invalid/revoked, or times out according to the policy in `docs/AI_FAILOVER_ARCHITECTURE.md`.

Do not assume multiple API keys automatically provide independent quota. Verify quota scope before production and use properly configured independent quota scopes/projects when needed and permitted.

If all four AI slots are unavailable, preserve the prescription and fall back to the manual Action Builder without exposing raw Gemini/quota/key details to the admin.

## 5. Data model principles

Keep these concepts separate:

- `prescription` = original human-authored instruction/source record
- `care_plan` = approved versioned plan for one patient
- `plan_action` = recurring/action rule
- `task_instance` = a scheduled occurrence of an action on a specific day/time
- `task_completion` = patient's interaction/result
- `content_item` = reusable public/assigned resource metadata

Never overwrite clinical history. Use versioning/archive/inactive status.

Resource principles:

- One canonical `content_item` should be reusable in public Resources and in patient plans.
- Link plan actions to resources by relation/ID instead of copying content.
- Resource visibility must support `public`, `patient_only`, `assigned_only`, and `staff_only`.
- Qur'an/Hadith source/reference/verification metadata must be preserved.

## 6. Media rules

A `content_item` may reference:

- direct audio URL
- YouTube URL/video ID
- external MP4 URL
- external PDF URL
- external webpage URL

Do not scrape/copy third-party media into our storage unless Sukun Life has permission/licensing.

## 7. Security rules

- RLS must be enabled on every user/patient-sensitive table.
- Patient can never read another patient's data.
- Super Admin routes and mutations require a server-verified role.
- Service-role keys are server-only.
- Gemini keys are server-only and must never be returned to the client or written to logs/analytics.
- Use audit logs for sensitive admin actions.
- Do not store permanent passwords in plaintext.
- Temporary credentials must force a secure reset/change flow.
- Sensitive practitioner/internal notes must support `staff_only` visibility.
- Do not send raw prescription text to third-party analytics/error trackers.
- Public resource queries must never leak `assigned_only` or `staff_only` content.

## 8. Implementation discipline

- Build MVP core flow before secondary Islamic utilities.
- Do not start by cloning Ruqyah Pro.
- The unique Sukun flow is: Patient → Prescription → Approved Actions → Reminder → Completion → Progress.
- Keep code modular and testable.
- Add tests for RLS, parsing validation, AI failover, task generation, notification scheduling, and resource visibility.
- Build the dedicated Islamic Resources hub during the Content CMS/resource phase, following `docs/ISLAMIC_RESOURCES_ARCHITECTURE.md`.
- Update documentation when architecture changes.
- Preserve green CI. Never disable meaningful tests/lints/security checks to make a change pass.
- After the functional phases, execute the mandatory `Final UI Match & Polish` phase from `docs/FINAL_UI_REFERENCE.md` across all major patient, resource, utility and admin screens.
- Do not finish with generic/default Material styling. Create/refine reusable branded components so spacing, cards, typography, buttons, states and navigation feel consistent across the app.
- Manually review compact and large phone layouts, long Bangla strings, Arabic wrapping, loading/empty/error states and safe areas before declaring visual completion.

## 9. Do not silently change scope

If a requirement is unclear, preserve the existing architecture and add a TODO/decision note instead of inventing a business rule.
