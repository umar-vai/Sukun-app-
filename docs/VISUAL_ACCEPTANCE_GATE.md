# Sukun Life App — Mandatory Visual Acceptance Gate

This document is a blocking product-acceptance gate. It applies immediately after Phase 8 functional completion and before Phase 9/release work can be considered complete.

## 1. Why this gate exists

The app may be functionally correct while still failing the approved Sukun Life visual direction. Functional completion does not satisfy visual acceptance.

The final Flutter app must visually match the approved Sukun Life concept direction documented in `docs/FINAL_UI_REFERENCE.md`: calm, premium, airy, modern, highly intentional, and unmistakably Sukun Life. It must not look like a generic Flutter/Material demo.

The following issues are specifically considered visual debt and must be removed before release:

- flat Mist-background pages with weak hierarchy
- generic large white Material cards used as the primary design language
- default-looking NavigationBar/BottomNavigationBar treatment
- generic DropdownButton/DropdownMenu/Dialog/PopupMenu styling left visible as final UI
- weak typography hierarchy
- inconsistent icon treatment
- cramped filter chips or horizontally overflowing controls
- developer-looking forms and settings screens
- plain empty/loading/error states
- inconsistent spacing, radii, and component density

## 2. Hard release rule

**Do not proceed to final release acceptance or declare Phase 9 complete until every required visual checklist item in this file is checked and manually reviewed.**

Passing tests, CI, RLS checks, Android builds, or functional QA does not satisfy this gate by itself.

If a screen works but still looks generic, that screen is not visually complete.

## 3. Required redesign approach

This is not a color-swap or radius-only polish task.

Where needed, redesign:

- screen composition
- information hierarchy
- component structure
- navigation treatment
- spacing rhythm
- typography scale/weight
- card grouping
- primary vs secondary actions
- states and feedback
- iconography treatment
- modal/dropdown/bottom-sheet interaction patterns

Create or refine reusable branded components instead of styling every screen independently.

## 4. Global component gate

All of the following must be custom-refined and consistent:

- [x] Page header
- [x] Section header
- [x] Primary card
- [x] Featured card
- [x] Task card
- [x] Progress card
- [x] Resource card/tile
- [x] Search field
- [x] Text input
- [x] Select/dropdown control
- [x] Modal/bottom sheet
- [x] Status chip
- [x] Primary/secondary/destructive button styles
- [x] Empty state
- [x] Error state
- [x] Loading/skeleton state
- [x] Bottom navigation
- [x] Icon containers and active/inactive icon treatment

## 5. Admin visual gate

- [x] Admin Dashboard recomposed beyond generic stacked cards
- [x] Patient List visually refined
- [x] Patient Detail visually refined
- [x] Create Patient form visually refined
- [x] Prescription creation visually refined
- [x] Manual Plan Builder visually refined
- [x] AI Action Review visually refined
- [x] Content CMS list visually refined
- [x] Content editor/direct-publish flow visually refined
- [x] Admin navigation visually refined
- [x] Admin search/filter states visually refined

## 6. Patient visual gate

- [x] Splash / launch
- [x] Sign in
- [x] First-login password change
- [x] Patient Home / Today
- [x] My Plan
- [x] Prescription
- [x] Progress
- [x] Profile
- [x] Notification/reminder states

## 7. Islamic Resources visual gate

- [x] Resources Home
- [x] Resource Search
- [x] Resource Detail
- [x] Qur'an list/detail
- [x] Hadith list/detail
- [x] Dua & Azkar
- [x] Ruqyah
- [x] Books / PDFs
- [x] Articles / Guides
- [x] Audio player
- [x] Video shell
- [x] PDF shell
- [x] Resource empty/loading/error states

## 8. Prayer and Qibla visual gate

The functional Phase 8 implementation is not automatically visually accepted.

### Prayer Times

- [x] Current prayer emphasis is visually clear
- [x] Next-prayer hierarchy is clear
- [x] Prayer list spacing/typography is refined
- [x] Location/method metadata is secondary but readable

### Prayer Settings

- [x] Location block feels intentionally composed
- [x] Current-location action uses branded hierarchy
- [x] City selector is custom-refined
- [x] Calculation-method selector is not a plain default dropdown
- [x] Madhhab selector is not a plain default dropdown
- [x] Selected state is clear and premium
- [x] Method/madhhab descriptions are visually organized
- [x] Save state/button treatment is polished
- [x] Dropdown/modal/bottom-sheet does not look detached from the Sukun Life design system

### Qibla

- [x] Compass face has intentional branded treatment
- [x] Qibla indicator is visually prominent
- [x] Direction/bearing hierarchy is refined
- [x] Calibration state is clear
- [x] Sensor-unavailable state is clear
- [x] Guidance text is visually secondary
- [x] Screen looks premium, not like a technical compass demo

## 9. Layout and brand rules

Use the mandatory brand system:

- Sukun Blue `#0F9BD7`
- Deep Tide `#0A70A8`
- Night Navy `#0D2B45`
- Mist `#E8F5FC`
- Saffron `#F2C45A` only as a limited accent
- white surfaces where hierarchy requires them

Recommended baseline:

- 20 px page horizontal padding
- 24–28 px major section spacing
- 18–20 px card internal padding
- 20–24 px card radius where appropriate
- 14–16 px button/input radius
- generous whitespace

Do not use one Mist background plus white rectangles as the complete design system. Use grouping, surface hierarchy, spacing, subtle elevation, and typography deliberately.

## 10. Device visual QA gate

Before visual acceptance, manually inspect major screens on:

- [x] compact Android phone size
- [x] large Android phone size
- [x] modern iPhone size

Review:

- [x] safe areas
- [x] keyboard overlap
- [x] bottom-nav spacing
- [x] long English strings
- [x] long Bangla strings
- [x] Arabic line wrapping
- [x] empty states
- [x] loading states
- [x] error states
- [x] modal/dropdown fit
- [x] no horizontal overflow

## 11. Completion evidence

Before marking this gate complete, the coding agent must report:

- screens redesigned
- reusable visual components created/refined
- screens still needing work
- compact/large-phone visual QA performed
- Android build status
- Flutter format/analyze/test status
- CI status

## 12. Blocking completion rule

Visual acceptance remains **FAILED** while any major screen still looks like default Flutter/Material UI or while the checklist above is materially incomplete.

Phase 9/release work may proceed in parallel for non-visual items, but the product must not be described as release-ready or visually complete until this gate passes.
