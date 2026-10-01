# AGENTS.md — Sukun Life App

This file contains mandatory instructions for Codex and all coding agents working in this repository.

## 1. Read first

Before writing code, read these files completely in this order:

1. `CODEX_START_HERE.md` — master product and engineering specification.
2. `docs/AI_FAILOVER_ARCHITECTURE.md` — mandatory Prescription → Action AI reliability/failover specification.
3. `IMPLEMENTATION_CHECKLIST.md` — execution checklist.

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

## 8. Implementation discipline

- Build MVP core flow before secondary Islamic utilities.
- Do not start by cloning Ruqyah Pro.
- The unique Sukun flow is: Patient → Prescription → Approved Actions → Reminder → Completion → Progress.
- Keep code modular and testable.
- Add tests for RLS, parsing validation, AI failover, task generation, and notification scheduling.
- Update documentation when architecture changes.

## 9. Do not silently change scope

If a requirement is unclear, preserve the existing architecture and add a TODO/decision note instead of inventing a business rule.
