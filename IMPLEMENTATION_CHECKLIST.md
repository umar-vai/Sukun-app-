# Sukun Life App — Implementation Checklist

Use this as the execution checklist after reading `AGENTS.md`, `CODEX_START_HERE.md`, `docs/AI_FAILOVER_ARCHITECTURE.md`, and `docs/ISLAMIC_RESOURCES_ARCHITECTURE.md`.

## Phase 0 — Project foundation

- [x] Create Flutter app in `app/`
- [x] Set Android/iOS application identifiers
- [x] Add brand asset directories
- [x] Add official Sukun Life logo supplied by client
- [x] Configure Poppins, Anek Bangla, Hind Siliguri, Tiro Bangla
- [x] Add brand design tokens from `AGENTS.md`
- [x] Set up routing
- [x] Set up chosen state management
- [x] Connect Supabase using environment configuration
- [x] Create Supabase migration structure
- [x] Create guest/patient/super_admin role model
- [x] Implement role-aware app shell
- [x] Add basic error/loading/empty states

## Phase 1 — Database + security

- [x] `profiles`
- [x] `user_roles`
- [x] `patients`
- [x] `prescriptions`
- [x] `care_plans`
- [x] `plan_actions`
- [x] `task_instances`
- [x] `task_completions`
- [x] `content_categories`
- [x] `content_items`
- [x] `content_tags`
- [x] `content_item_tags`
- [x] `plan_action_resources`
- [x] `notification_devices`
- [x] `admin_audit_logs`
- [x] Add resource visibility states: `public`, `patient_only`, `assigned_only`, `staff_only`
- [x] Add source/reference/verification fields required for Qur'an/Hadith-sensitive content
- [x] Enable RLS on sensitive tables
- [x] Patient can only read own data
- [x] Patient cannot mutate plan rules/content
- [x] Public/guest resource queries cannot read assigned/staff-only content
- [x] Patient can read only resources allowed by public/patient/assignment rules
- [x] Super Admin access is server-verified
- [x] Add SQL RLS isolation tests
- [x] Add resource-visibility authorization tests

## Phase 2 — Admin core flow

- [x] Admin dashboard
- [x] Patient list/search
- [x] Create patient
- [x] Generate patient reference code
- [x] Temporary credential/invite flow
- [x] Patient details
- [x] Create prescription record
- [x] Manual plan builder
- [x] Add/edit/reorder action
- [x] Link an existing `content_item` to a plan action without duplicating the resource
- [x] Plan preview as patient
- [x] Publish plan
- [x] Plan version history
- [x] Archive/deactivate old plan

## Phase 3 — Patient core flow

- [x] Patient login
- [x] Patient ID/phone password login works without an SMS-gateway dependency
- [x] First-login credential change
- [x] Patient home
- [x] Next action card
- [x] Today's tasks
- [x] My Plan
- [x] Prescription view
- [x] Open linked resource from a plan task
- [x] Done
- [x] Snooze
- [x] Skip
- [x] Progress screen
- [x] Offline-safe completion queue

## Phase 4 — Prescription-to-action AI

- [x] Create server-side Edge Function
- [x] Implement provider/key routing behind a server-side abstraction
- [x] Add four server-only Gemini secret slots: `GEMINI_API_KEY_1..4`
- [x] Implement `GeminiKeyPool` / `AiRouter`
- [x] Use deterministic healthy-key fallback order 1 → 2 → 3 → 4 for MVP
- [x] Detect quota/resource exhaustion/rate-limit failures and silently fail over
- [x] Detect invalid/revoked key configuration and skip/fail over internally
- [x] Add timeout/retry/backoff policy
- [x] Add per-key cooldown/health state so exhausted keys are not retried on every request
- [x] Use provider retry metadata such as `Retry-After` when available
- [ ] Verify whether configured keys have independent quota scopes before production
- [x] Never expose quota/credit/key/provider errors to the Super Admin UI
- [x] If all four slots fail, preserve prescription and continue via manual Action Builder without raw provider errors
- [x] Ensure Flutter never selects or receives Gemini credentials
- [x] Define strict canonical JSON schema shared across all key slots
- [x] Parse Bangla/mixed-language prescription text
- [x] Mark ambiguous output as `needs_review`
- [x] Resource matching suggestions
- [x] Admin action review screen
- [x] No automatic publishing
- [x] Add idempotent request IDs to prevent duplicate actions during failover
- [x] Add internal metrics/logging without raw keys or full sensitive prescription text
- [x] Add parser fixtures/tests
- [x] Test slot 1 exhausted → slot 2 succeeds
- [x] Test slots 1-2 exhausted → slot 3 succeeds
- [x] Test slots 1-3 exhausted → slot 4 succeeds
- [x] Test all four unavailable → no quota error reaches Flutter, manual fallback remains usable
- [x] Test key secrets never appear in logs/API responses

## Phase 5 — Content CMS + Dedicated Islamic Resources

Follow `docs/ISLAMIC_RESOURCES_ARCHITECTURE.md`.

### Resources information architecture

- [x] Build a dedicated top-level `Resources / ইসলামিক রিসোর্স` hub separate from patient-care screens
- [x] Qur'an section
- [x] Hadith section
- [x] Dua & Azkar section
- [x] Ruqyah section
- [x] Books & PDFs section
- [x] Articles & Guides section
- [x] Audio filter/category
- [x] Video filter/category
- [x] Search/filter/category navigation

### Qur'an

- [x] Surah/category structure
- [x] Surah details / Ayah list architecture
- [x] Selected/Ruqyah Ayat collections
- [x] Arabic text field from verified source only
- [x] Approved Bangla translation + source metadata
- [x] Surah/Ayah reference metadata
- [x] Verification status / reviewer metadata
- [x] Never generate or rewrite canonical Qur'an text with AI

### Hadith

- [x] Topic-wise Hadith browsing
- [x] Hadith detail screen
- [x] Collection/book/reference metadata
- [x] Hadith number where available
- [x] Translation/source metadata
- [x] Grade/status field when provided by approved source
- [x] Verification status / reviewer metadata
- [x] Never fabricate Hadith wording, narrator, source, grade, or numbering with AI

### Dua & Azkar

- [x] Morning Azkar
- [x] Evening Azkar
- [x] Masnun Dua categories
- [x] Protection/Sleep/Travel/etc. categories as approved
- [x] Arabic / approved transliteration / Bangla translation fields where used
- [x] Source/reference metadata
- [x] Do not invent repeat counts or religious instructions

### Ruqyah resources

- [x] Ruqyah Ayat
- [x] Ruqyah Audio
- [x] Self-Ruqyah Guide
- [x] Approved topic/category structure (Evil Eye/Jinn/Sihr/etc.)
- [x] Keep general Ruqyah resources separate from personalized patient prescriptions/plans

### Books / PDF / Articles

- [x] Book + chapters
- [x] PDF resources
- [x] Article/Guide
- [x] Author/publisher/source/rights metadata where applicable
- [x] External PDF URLs by default

### CMS lifecycle and reuse

- [x] `draft` / `review` / `verified` / `published` / `archived` workflow where applicable
- [x] Public/patient/assigned/staff-only visibility
- [x] Super Admin create/edit/preview/verify/publish/unpublish/archive
- [x] Link a canonical resource into one or many patient plans using `content_id`
- [x] Do not create duplicate resource copies per patient
- [x] Patient/guest resource browsing
- [x] Search/filter/category
- [ ] Favorites/bookmarks if included in MVP
- [x] RLS prevents unpublished/restricted resources from leaking through search/API

## Phase 6 — External media

- [x] Direct audio URL playback
- [x] Background audio
- [x] Lock-screen audio controls
- [x] Resume position
- [x] Playback speed where appropriate
- [x] YouTube playback via supported approach
- [x] External PDF viewer
- [x] Invalid/dead URL handling
- [x] Respect content rights/licensing
- [x] Never extract YouTube audio into raw MP3

## Phase 7 — Notifications

- [x] Local scheduled notifications
- [x] Generate reminders from approved actions with explicit exact times only
- [x] Cancel and reschedule old reminders on plan change
- [x] Snooze behavior
- [x] Firebase Cloud Messaging client/server architecture
- [x] Plan-updated push
- [x] Optional admin broadcast assessed and excluded from the MVP
- [x] Device token registration, refresh, removal, and invalid-token cleanup
- [x] Android precise reminder timing requests user-controlled exact-alarm access with safe fallback
- [x] Plan-update pushes use a dedicated high-importance Android channel
- [x] Production Android device registration and patient ownership verified
- [x] Live plan-updated FCM notification received on a physical patient device
- [x] Live approved exact-time/Snooze local reminder received on a locked physical patient device

## Phase 8 — Islamic utilities

- [x] Prayer time calculation
- [x] Location permission + manual city fallback
- [x] Calculation method settings
- [x] Qibla direction
- [x] Compass calibration states
- [x] Keep Prayer/Qibla utilities visually consistent with Sukun Life brand and separate from canonical content verification logic

## Phase 9 — Quality + release

- [ ] Flutter analyze clean
- [ ] Flutter tests pass
- [ ] RLS tests pass
- [ ] Patient isolation manually verified
- [ ] Resource visibility/security tests pass
- [ ] Qur'an/Hadith publication cannot bypass required verification rules
- [ ] AI failover integration tests pass
- [ ] No Gemini quota/provider/key details are exposed in normal admin UX
- [ ] Accessibility/contrast review
- [ ] Bangla typography review
- [ ] Qur'an/Hadith typography/readability review
- [ ] Offline/reconnect tests
- [ ] Crash reporting
- [ ] Analytics without sensitive prescription text
- [ ] Android release config
- [ ] iOS release config
- [ ] Privacy policy/data handling review
- [ ] Store screenshots and metadata

## MVP acceptance flow

The MVP is accepted only if this works end to end:

- [x] Admin creates patient
- [x] Admin creates prescription
- [x] Admin creates/reviews actions
- [x] Admin publishes plan
- [x] Patient logs in
- [x] Patient sees only own plan
- [ ] Reminder appears
- [x] Patient marks a task complete
- [x] Backend records completion
- [x] Admin sees updated progress
- [ ] Admin can publish/edit a resource without app-store release
- [x] Dedicated Islamic Resources hub is accessible and clearly separate from `My Plan`
- [x] Qur'an, Hadith, Dua & Azkar, Ruqyah, Books/PDF, Articles/Guides, Audio and Video are represented in the resource architecture
- [x] A single canonical resource can be linked to a patient's plan without duplicating it
- [x] Guest cannot access restricted/assigned/staff-only resources
- [x] Qur'an/Hadith canonical content cannot be published as unsourced generic AI output
- [ ] External audio/video/PDF opens correctly
- [x] Another patient cannot access the first patient's data
- [ ] AI still generates draft actions when earlier Gemini key slots are quota-exhausted and a later slot is healthy
- [ ] Raw Gemini quota/credit/key errors never appear to the Super Admin
