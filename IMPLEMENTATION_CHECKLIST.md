# Sukun Life App — Implementation Checklist

Use this as the execution checklist after reading `AGENTS.md` and `CODEX_START_HERE.md`.

## Phase 0 — Project foundation

- [ ] Create Flutter app in `app/`
- [ ] Set Android/iOS application identifiers
- [ ] Add brand asset directories
- [ ] Add official Sukun Life logo supplied by client
- [ ] Configure Poppins, Anek Bangla, Hind Siliguri, Tiro Bangla
- [ ] Add brand design tokens from `AGENTS.md`
- [ ] Set up routing
- [ ] Set up chosen state management
- [ ] Connect Supabase using environment configuration
- [ ] Create Supabase migration structure
- [ ] Create guest/patient/super_admin role model
- [ ] Implement role-aware app shell
- [ ] Add basic error/loading/empty states

## Phase 1 — Database + security

- [ ] `profiles`
- [ ] `user_roles`
- [ ] `patients`
- [ ] `prescriptions`
- [ ] `care_plans`
- [ ] `plan_actions`
- [ ] `task_instances`
- [ ] `task_completions`
- [ ] `content_categories`
- [ ] `content_items`
- [ ] `notification_devices`
- [ ] `admin_audit_logs`
- [ ] Enable RLS on sensitive tables
- [ ] Patient can only read own data
- [ ] Patient cannot mutate plan rules/content
- [ ] Super Admin access is server-verified
- [ ] Add SQL RLS isolation tests

## Phase 2 — Admin core flow

- [ ] Admin dashboard
- [ ] Patient list/search
- [ ] Create patient
- [ ] Generate patient reference code
- [ ] Temporary credential/invite flow
- [ ] Patient details
- [ ] Create prescription record
- [ ] Manual plan builder
- [ ] Add/edit/reorder action
- [ ] Plan preview as patient
- [ ] Publish plan
- [ ] Plan version history
- [ ] Archive/deactivate old plan

## Phase 3 — Patient core flow

- [ ] Patient login
- [ ] First-login credential change
- [ ] Patient home
- [ ] Next action card
- [ ] Today's tasks
- [ ] My Plan
- [ ] Prescription view
- [ ] Done
- [ ] Snooze
- [ ] Skip
- [ ] Progress screen
- [ ] Offline-safe completion queue

## Phase 4 — Prescription-to-action AI

- [ ] Create server-side Edge Function
- [ ] Add provider abstraction for OpenAI/Gemini
- [ ] Define strict JSON schema
- [ ] Never expose provider secret in Flutter
- [ ] Parse Bangla/mixed-language prescription text
- [ ] Mark ambiguous output as `needs_review`
- [ ] Resource matching suggestions
- [ ] Admin action review screen
- [ ] No automatic publishing
- [ ] Add parser fixtures/tests

## Phase 5 — Content CMS

- [ ] Public/assigned content visibility
- [ ] Audio
- [ ] Video/YouTube
- [ ] PDF
- [ ] Dua/Amal
- [ ] Article/Guide
- [ ] Book + chapters
- [ ] Draft/published/archived lifecycle
- [ ] Admin add/edit/archive content
- [ ] Patient/guest resource browsing
- [ ] Search/filter/category
- [ ] Favorites/bookmarks if included in MVP

## Phase 6 — External media

- [ ] Direct audio URL playback
- [ ] Background audio
- [ ] Lock-screen audio controls
- [ ] YouTube playback via supported approach
- [ ] External PDF viewer
- [ ] Invalid/dead URL handling
- [ ] Respect content rights/licensing

## Phase 7 — Notifications

- [ ] Local scheduled notifications
- [ ] Generate reminders from approved actions
- [ ] Cancel old reminders on plan change
- [ ] Snooze behavior
- [ ] Firebase Cloud Messaging
- [ ] Plan-updated push
- [ ] Optional admin broadcast
- [ ] Device token management

## Phase 8 — Islamic utilities

- [ ] Prayer time calculation
- [ ] Location permission + manual city fallback
- [ ] Calculation method settings
- [ ] Qibla direction
- [ ] Compass calibration states
- [ ] Verified Quran/Hadith resources only when approved

## Phase 9 — Quality + release

- [ ] Flutter analyze clean
- [ ] Flutter tests pass
- [ ] RLS tests pass
- [ ] Patient isolation manually verified
- [ ] Accessibility/contrast review
- [ ] Bangla typography review
- [ ] Offline/reconnect tests
- [ ] Crash reporting
- [ ] Analytics without sensitive prescription text
- [ ] Android release config
- [ ] iOS release config
- [ ] Privacy policy/data handling review
- [ ] Store screenshots and metadata

## MVP acceptance flow

The MVP is accepted only if this works end to end:

- [ ] Admin creates patient
- [ ] Admin creates prescription
- [ ] Admin creates/reviews actions
- [ ] Admin publishes plan
- [ ] Patient logs in
- [ ] Patient sees only own plan
- [ ] Reminder appears
- [ ] Patient marks a task complete
- [ ] Backend records completion
- [ ] Admin sees updated progress
- [ ] Admin can publish/edit a resource without app-store release
- [ ] External audio/video/PDF opens correctly
- [ ] Another patient cannot access the first patient's data
