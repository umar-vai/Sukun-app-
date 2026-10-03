# Islamic Utilities Architecture

This document records the Phase 8 implementation boundary for Prayer Times and
Qibla. These utilities are intentionally separate from patient care and from the
verified canonical content system described in
`docs/ISLAMIC_RESOURCES_ARCHITECTURE.md`.

## Prayer times

- Prayer times are calculated on-device with `adhan_dart`.
- The user must explicitly choose a calculation method and an Asr convention.
  The app does not silently choose a religious convention.
- The app displays the selected method and convention beside the timetable and
  explains that a trusted local mosque timetable may differ.
- Dates and calculations use the timezone associated with the selected or
  detected location.

## Location and privacy

- Location is requested only while the app is in use.
- The user can decline location access and select a curated Bangladesh city
  instead.
- The selected location and prayer preferences are stored locally on the
  device. They are not written to Supabase or attached to a patient record.
- No background location permission is requested.
- Android declares coarse and fine location permissions. iOS declares
  `NSLocationWhenInUseUsageDescription` only.

## Qibla

- The Qibla bearing is calculated on-device from the selected coordinates.
- When a compass sensor is available, the arrow is rotated relative to the
  device heading.
- The screen exposes ready, calibration-needed, and unavailable states.
- If the sensor is unavailable, the numerical bearing remains visible so the
  user can use another trusted compass.

## Product boundaries

- Prayer and Qibla settings do not affect care plans, plan actions, task
  generation, reminders, adherence, or clinical records.
- These calculated utilities do not reuse, create, or bypass verification for
  Qur'an, Hadith, Dua, Ruqyah, or other canonical resources.
- No backend secrets or third-party API credentials are required by these
  utilities.

## Verification

- Calculation, Qibla-bearing, explicit-configuration, local-preference,
  permission-denial fallback, setup, and compass-state tests are automated.
- Android was manually verified on an emulator for settings, a rendered Dhaka
  timetable, and the live compass screen.
- iOS compilation and physical-device sensor behavior require final validation
  on macOS/iPhone during Phase 9 release readiness.
