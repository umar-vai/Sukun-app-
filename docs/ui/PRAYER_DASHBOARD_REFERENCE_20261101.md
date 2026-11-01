# Prayer dashboard: supplied visual reference (2026-11-01)

This proposal updates the real Sukun Life Flutter Home for Guest, General User and Patient. It preserves the current prayer calculation service, settings, notification controls, Supabase integration, and public website.

## Structure

1. Header: selected city (tap opens Prayer Settings) and Gregorian date of the computed local schedule.
2. Current prayer: its Bengali name, a circular progress indicator for the elapsed time of the waqt, and a live countdown until the next prayer.
3. Window: separate start and end times. Fajr ends at **sunrise**, not Dhuhr; other displayed prayer windows use their next calculated prayer boundary. Between sunrise and Dhuhr, show a **break** rather than falsely marking Fajr as ongoing. These calculated boundaries may differ from a local mosque timetable.
4. Bottom: five equal-width slots for Fajr, Dhuhr, Asr, Maghrib, Isha. Current waqt is highlighted; sunrise is not a fifth/sixth prayer.
5. Actions: open Qibla or full Prayer Times. Loading and missing-settings states never fabricate times.

The reference image's green theme was adapted to official Sukun Blue, Deep Tide, and Night Navy. The screenshot's Hijri date has **not** been fabricated; a verified Hijri converter and user-adjustment policy are separate follow-up work.

## QA gates

- Format, analyze, widget tests, and web build.
- Compact 320px phone, standard phone, desktop responsive review; check long Bangla/city labels and dark theme.
- Location setup, prayer boundary transition, Isha-to-next-Fajr overnight case, and links to Qibla/full timetable.
- CI, merge, Pages deployment, and browser verification must be reported separately.
- No APK/AAB build, no migrations, no production data modifications, no changes to sukunlife.com.
