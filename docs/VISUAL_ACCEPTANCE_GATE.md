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

- [ ] Page header
- [ ] Section header
- [ ] Primary card
- [ ] Featured card
- [ ] Task card
- [ ] Progress card
- [ ] Resource card/tile
- [ ] Search field
- [ ] Text input
- [ ] Select/dropdown control
- [ ] Modal/bottom sheet
- [ ] Status chip
- [ ] Primary/secondary/destructive button styles
- [ ] Empty state
- [ ] Error state
- [ ] Loading/skeleton state
- [ ] Bottom navigation
- [ ] Icon containers and active/inactive icon treatment

## 5. Admin visual gate

- [ ] Admin Dashboard recomposed beyond generic stacked cards
- [ ] Patient List visually refined
- [ ] Patient Detail visually refined
- [ ] Create Patient form visually refined
- [ ] Prescription creation visually refined
- [ ] Manual Plan Builder visually refined
- [ ] AI Action Review visually refined
- [ ] Content CMS list visually refined
- [ ] Content editor/review/publish flow visually refined
- [ ] Admin navigation visually refined
- [ ] Admin search/filter states visually refined

## 6. Patient visual gate

- [ ] Splash / launch
- [ ] Sign in
- [ ] First-login password change
- [ ] Patient Home / Today
- [ ] My Plan
- [ ] Prescription
- [ ] Progress
- [ ] Profile
- [ ] Notification/reminder states

## 7. Islamic Resources visual gate

- [ ] Resources Home
- [ ] Resource Search
- [ ] Resource Detail
- [ ] Qur'an list/detail
- [ ] Hadith list/detail
- [ ] Dua & Azkar
- [ ] Ruqyah
- [ ] Books / PDFs
- [ ] Articles / Guides
- [ ] Audio player
- [ ] Video shell
- [ ] PDF shell
- [ ] Resource empty/loading/error states

## 8. Prayer and Qibla visual gate

The functional Phase 8 implementation is not automatically visually accepted.

### Prayer Times

- [ ] Current prayer emphasis is visually clear
- [ ] Next-prayer hierarchy is clear
- [ ] Prayer list spacing/typography is refined
- [ ] Location/method metadata is secondary but readable

### Prayer Settings

- [ ] Location block feels intentionally composed
- [ ] Current-location action uses branded hierarchy
- [ ] City selector is custom-refined
- [ ] Calculation-method selector is not a plain default dropdown
- [ ] Madhhab selector is not a plain default dropdown
- [ ] Selected state is clear and premium
- [ ] Method/madhhab descriptions are visually organized
- [ ] Save state/button treatment is polished
- [ ] Dropdown/modal/bottom-sheet does not look detached from the Sukun Life design system

### Qibla

- [ ] Compass face has intentional branded treatment
- [ ] Qibla indicator is visually prominent
- [ ] Direction/bearing hierarchy is refined
- [ ] Calibration state is clear
- [ ] Sensor-unavailable state is clear
- [ ] Guidance text is visually secondary
- [ ] Screen looks premium, not like a technical compass demo

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

- [ ] compact Android phone size
- [ ] large Android phone size
- [ ] modern iPhone size

Review:

- [ ] safe areas
- [ ] keyboard overlap
- [ ] bottom-nav spacing
- [ ] long English strings
- [ ] long Bangla strings
- [ ] Arabic line wrapping
- [ ] empty states
- [ ] loading states
- [ ] error states
- [ ] modal/dropdown fit
- [ ] no horizontal overflow

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