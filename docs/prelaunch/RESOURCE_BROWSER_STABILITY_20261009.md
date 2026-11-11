# Resource browser stability — 9 October 2026

## Scope
This is the first isolated development change while Sukun Life's D-U-N-S and
Google Play Console registration are in progress.

Relevant existing defect register: SUK-P1-009 (resource browsing rebuilds
and retry UX). Hadith category switching and Dua/Ruqyah taxonomy filters used
to create network futures inside widget build. Any parent rebuild could
repeat costly Supabase reads and replace content with a loading state.

## Changes
- Cache a Future per active Hadith/topic or Dua/Ruqyah taxonomy filter.
- Reuse the Hadith topic-list Future across topic selections.
- Do not refetch if user selects the already active filter.
- Allow manual retry when a request fails without showing raw server errors.
- Reset taxonomy query when widget kind switches between Dua and Ruqyah.
- Widget tests cover repeated parent builds, active-filter no-op, filter
  changes, and a simulated network failure/retry.

## Risk and release gate
This is **UI and request-lifecycle only**. It does not alter production
Supabase, RLS, permissions, clinical care plans, patient notifications,
published religious content, or current deployed web preview.

Automated Flutter tests and mobile-device manual verification are required
before merging the draft PR. Search still downloads all authorized pages in
the resource repository; true server-side filtering and pagination remain a
separate scale-optimization task. Never claim a resource catalog with 100k
items has been load-tested based solely on these tests.
