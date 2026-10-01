# Sukun Life App

Standalone mobile application for Sukun Life, focused on personalized patient care plans, prescription-to-action conversion, reminders, adherence tracking, and a curated Islamic/Ruqyah resource library.

> **Important:** The existing public website and existing internal Sukun Life dashboard are not to be modified by this project. This repository is for a new, independent app ecosystem.

## Start here

For Codex/developers, read these files in order:

1. [`AGENTS.md`](./AGENTS.md) — non-negotiable development and brand rules.
2. [`CODEX_START_HERE.md`](./CODEX_START_HERE.md) — complete product specification, architecture, data model, UI, AI workflow, security, roadmap, and implementation order.
3. [`IMPLEMENTATION_CHECKLIST.md`](./IMPLEMENTATION_CHECKLIST.md) — practical execution checklist.

## Product in one sentence

**Sukun Life App = Islamic Resource App + Personalized Patient Care Plan + Reminders + Amal/Task Tracking + Super Admin Management in the same Flutter app.**

## Proposed stack

- Flutter — Android/iOS app
- Supabase — PostgreSQL, Auth, Row Level Security, Edge Functions
- Firebase Cloud Messaging — push notifications
- Local notifications — scheduled reminders on device
- External URLs/CDN/YouTube — audio, video, PDF media sources
- OpenAI or Gemini API — prescription text → suggested structured actions, always requiring human review before publish

## Brand source of truth

The app must visually follow the official Sukun Life identity and website: https://www.sukunlife.com/

Never redraw or modify the Sukun Life logo. Use only the official supplied logo asset. Full rules are in `CODEX_START_HERE.md` and `AGENTS.md`.
