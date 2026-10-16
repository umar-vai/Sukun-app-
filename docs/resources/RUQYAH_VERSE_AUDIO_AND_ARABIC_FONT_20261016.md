# Ruqyah selected-ayah audio and Arabic font — 2026-10-16

## Scope / sourcing

- Screen: the **existing** Quran > Ruqyah Ayat reader in the one Flutter app; no parallel site.
- The production editorial content has 101 published source-book Quran excerpts; only 99 carry a start surah+ayah metadata pair. `srg2024-qur-001` and `srg2024-qur-047` are preparatory introductions without standalone canonical ayah metadata.
- The source-book excerpts have no independently verified end-verse markers. Therefore individual card playback is **explicitly labelled as only the starting canonical ayah**, not the selected editorial excerpt's complete recitation. Do not invent end boundaries, string-match Arabic to a guessed verse, or play an unrelated surah recording as if it matches a card.
- Use the existing `quran-content` Supabase Edge Function and the exact `surah:ayah` start key. The returned canonical verse audio URL is accepted **only** from approved HTTPS Quran CDN hosts. Stream on click using the section's already-installed `just_audio` engine; never mirror/host MP3 in Supabase, GitHub or public Pages.
- Avoid extra fetch if a card meaning already loaded: the first-verse Bengali translation and recording URL reuse the same cached provider request. On failures, allow retry without a permanent failure cache. Introductory cards have audio disabled with an explicit reason.
- Only Arabic text within this Ruqyah reader receives `GoogleFonts.amiriQuran`, with responsive size and generous line height. User-established brand Bengali typography must remain unchanged. Font loading uses the existing `google_fonts` dependency and network where not cached, with Flutter fallback.

## QA / release gates

- Flutter format/analyze/tests, Edge/RLS guards, backend-free Web build, browser navigation and Pages deploy verification.
- Manual browser test: a single start-reference item such as 114:1, pause/resume, switching to section recording, network-off/audio unavailable fallback, responsive Arabic marks. Verify an unmatched introduction cannot play guessed verse audio.
- Automated unit guards: trusted audio URL domain, HTTPS only, no guessed intro references, prior 101 editorial distribution unchanged.
- Note: reliable **entire excerpt** recitation for multi-verse selections needs separate approved source MP3 matched by exact editorial slug or verified complete end bounds, plus audio rights and playback QC. Do not label this start-only feature as full coverage.

## Unchanged

- Quran API implementation; Supabase project data, auth, RLS, users/patients; existing `sukunlife.com` public website and old dashboard; native APK/AAB/IPA.
