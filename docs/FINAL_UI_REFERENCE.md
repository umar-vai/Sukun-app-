# Sukun Life App — Mandatory Final UI Reference

This document defines the required visual target for the final Sukun Life mobile app. It is not optional polish. Coding agents must treat it as a product acceptance requirement.

The goal is to make the completed Flutter app feel like the previously approved Sukun Life concept mockups: calm, premium, modern, airy, highly legible, and clearly branded — not like a generic Material demo app.

## 1. Design acceptance rule

A feature is not visually complete merely because it works.

Before declaring the app complete, every major screen must receive a dedicated UI refinement pass. The final result must look like one coherent designed product, not a collection of default Flutter widgets.

Do not leave default Material styling where a custom Sukun Life treatment is expected.

## 2. Global visual language

Use the official Sukun Life brand system only:

- Sukun Blue `#0F9BD7`
- Deep Tide `#0A70A8`
- Night Navy `#0D2B45`
- Mist `#E8F5FC`
- Saffron `#F2C45A` as a limited warm accent only
- White surfaces for cards and important content areas

Typography:

- English: Poppins
- Bangla headline/display: Anek Bangla
- Bangla body/UI: Hind Siliguri
- Qur'an/Hadith: Tiro Bangla only where appropriate

The app must feel:

- calm
- premium
- soft
- modern
- uncluttered
- trustworthy
- faith-anchored without decorative excess
- clinical enough for patient care

Avoid:

- default-looking Flutter screens
- random green/gold Islamic themes
- heavy gradients
- fake glassmorphism
- neon colors
- excessive borders
- cramped layouts
- tiny text
- inconsistent radii
- generic stock icons used without hierarchy
- dense dashboard styling

## 3. Layout system

Use a consistent spacing scale and visual rhythm.

Recommended baseline:

- Page horizontal padding: 20 px
- Major section gap: 24–28 px
- Card internal padding: 18–20 px
- Small item gap: 8–12 px
- Card corner radius: 20–24 px
- Button corner radius: 14–16 px
- Input corner radius: 14–16 px
- Bottom navigation outer radius: approximately 24 px

Use generous whitespace. Prefer fewer stronger visual blocks over many small containers.

## 4. Surface and elevation

Primary pages should use Mist or very light neutral backgrounds.

Important cards should use white surfaces. Use very subtle shadow/elevation only when hierarchy needs it. Do not make every card float equally.

Featured/next-action cards may use a soft blue-tinted surface or light brand accent treatment, but must remain easy to read.

The visual hierarchy should normally be:

1. Page title / greeting
2. Main status or featured card
3. Section title
4. Content/task cards
5. Secondary actions

## 5. Bottom navigation

Patient-facing navigation must feel intentionally designed and visually close to the approved concept direction.

Use a compact rounded bottom navigation treatment with clear active state, balanced icon sizing, and safe-area spacing.

It must not look like an untouched default NavigationBar.

Suggested patient destinations:

- Today
- My Plan
- Resources
- Progress
- Profile

Keep labels concise and readable. Active item should use Sukun Blue/Deep Tide emphasis and a soft selected background.

Admin mode may use a role-appropriate navigation structure, but must use the same design language.

## 6. Patient Home / Today screen

This is one of the most important visual screens and must feel premium.

Required visual structure:

- Friendly greeting at top
- Current date in secondary styling
- Prominent daily progress/status card
- Clear `Next Action` section
- One visually featured next-action card
- `Today's Plan` section
- Clean task cards beneath

Daily progress card should visually show:

- active plan name
- completed / total
- clear progress indicator
- calm encouraging presentation

The next-action card should show, where applicable:

- action title
- time or time window
- repetition count / duration
- linked resource affordance
- Done as primary CTA
- Snooze and Skip as secondary actions

Do not make all three actions visually equal. Done is the primary action.

Completed tasks should visibly feel complete without becoming visually noisy.

## 7. My Plan screen

My Plan must read like a clear personal care plan, not a database list.

Use:

- plan summary header
- grouped action sections
- readable timing/frequency
- compact chips only where they genuinely improve scanning
- linked resource cards/buttons
- clear prescription access

Keep practitioner-authored instructions visually distinct from metadata.

## 8. Progress screen

The progress screen should feel encouraging and understandable at a glance.

Include visually refined cards for:

- today
- 7-day adherence
- 30-day adherence
- completed tasks
- missed/skipped tasks where appropriate

Use simple progress visuals and restrained charts. Avoid overloading the patient with analytics.

Admin progress views can be more detailed, but should keep the same brand treatment.

## 9. Islamic Resources hub

The top-level Resources area must feel like a curated library, separate from patient-care screens.

The eight primary sections must be visually easy to browse:

- Qur'an
- Hadith
- Dua & Azkar
- Ruqyah
- Books & PDFs
- Articles & Guides
- Audio
- Video

Use elegant section cards or tiles with consistent iconography and enough whitespace.

Search and filter controls should be clean and compact.

Resource detail screens must prioritize reading comfort and source/reference credibility.

## 10. Qur'an / Hadith visual treatment

Qur'an and Hadith screens require stronger typography discipline than normal content screens.

- Arabic text should have generous line height and spacing
- translation should be visually separated from Arabic
- source/reference should be visible but secondary
- verification/source metadata should be clear without dominating the reading experience
- never use decorative backgrounds that reduce readability

## 11. Media screens

Audio should feel like a native spiritual/wellness player, not a generic URL launcher once Phase 6 is complete.

Use:

- clear title
- resource category/source
- large central play/pause control
- progress scrubber
- elapsed/remaining time
- speed control where supported
- background playback state

Video and PDF screens should preserve the same visual shell and navigation consistency.

## 12. Prayer / Qibla screens

Prayer Time and Qibla screens may be visually distinctive but must remain inside the Sukun Life brand.

Prayer screen:

- current prayer emphasis
- next prayer time
- clean list of daily prayers
- current location/method in secondary styling

Qibla screen:

- large readable directional compass
- clear Kaaba/Qibla indicator
- calibration state when needed
- restrained design, not ornamental

## 13. Super Admin UI

Admin screens should look operational but still premium.

Prioritize:

- clear page hierarchy
- strong search/filter
- readable patient cards/rows
- clear status chips
- focused forms
- obvious primary actions
- safe destructive-action styling

The AI action review screen should visually distinguish:

- original prescription
- generated suggestion
- ambiguity / needs-review warnings
- linked resource selection
- approve/import controls

Do not let AI/provider internals appear in the visual design.

## 14. Components that must be custom-refined

Create reusable branded widgets where practical for:

- page header
- section header
- primary card
- featured card
- task card
- progress card
- resource tile/card
- status chip
- branded button styles
- search field
- empty state
- error state
- loading/skeleton state
- bottom navigation

Do not duplicate styling screen-by-screen.

## 15. Motion and interaction

Use subtle motion only where it improves perceived quality:

- button press feedback
- card state transitions
- progress updates
- tab/navigation transitions
- task completion confirmation

Avoid flashy animation.

## 16. Accessibility and readability

Final design must support:

- adequate color contrast
- readable text sizes
- comfortable tap targets
- dynamic text where feasible
- safe-area handling
- no clipped Bangla text
- no clipped Arabic text
- proper RTL handling where applicable
- small and large phone layouts

## 17. Device QA requirement

Before visual completion is declared, manually inspect major screens at minimum on:

- one compact Android phone size
- one large Android phone size
- one modern iPhone size

Check:

- overflow
- safe areas
- keyboard overlap
- bottom nav spacing
- long Bangla strings
- long patient/action titles
- Arabic line wrapping
- empty states
- loading states
- error states

## 18. Mandatory visual review pass

After functional phases are complete, perform a dedicated `Final UI Match & Polish` pass across the entire app.

For every major screen:

1. inspect current implementation
2. identify default/generic-looking elements
3. refine layout, typography, spacing, cards, hierarchy, icon treatment and navigation
4. preserve all existing functionality and security rules
5. run Flutter format/analyze/tests
6. verify Android debug build
7. only then mark the screen visually complete

## 19. Screens that must receive explicit final polish

At minimum:

- splash / launch
- sign in
- first-login password change
- Patient Home / Today
- My Plan
- Prescription
- Progress
- Resource Hub
- Resource Search
- Resource Detail
- Qur'an list/detail
- Hadith list/detail
- Dua & Azkar
- Ruqyah
- Audio player
- Video/PDF shell
- Prayer Times
- Qibla
- Profile
- Admin Dashboard
- Patient List
- Patient Detail
- Prescription creation
- Manual Plan Builder
- AI Action Review
- Content CMS list/editor/direct-publish screens
- notification/reminder related screens

## 20. Completion gate

Do not call the app visually complete until all of the following are true:

- no major screen looks like a default Flutter demo
- the official Sukun Life palette and typography are consistently applied
- patient-facing screens feel calm and premium
- admin screens feel clean and operational
- spacing/radius/icon treatment is consistent
- bottom navigation is custom-refined
- loading/empty/error states are branded
- Bangla and Arabic typography has been manually reviewed
- major screens pass compact + large phone visual QA
- CI remains green

Functional completion and visual completion are separate gates. Both are required for the final product.
