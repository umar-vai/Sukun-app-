# Calm redesign (November 2026): progress and feature-preservation log

Approved visual target: the "Sukun Life Redesign" canvas (12 phone screens plus
a design-system board) reviewed with the product owner on 9 November 2026.

Rule for this redesign: **UI only**. No route, permission, RLS, Supabase query,
feature flag or business rule is removed or changed. Every existing entry point
must stay reachable. When a shortcut moves, it is recorded below.

## Done in this pass

### Design system (applies to every screen)
- `app/lib/app/theme/sukun_tokens.dart`: new spacing, radius and shadow tokens.
- `sukun_theme.dart`: primary buttons and FAB use Deep Tide with white text
  (AA contrast; Sukun Blue stays for rings, icons and highlights). Calmer
  cards (no border, soft shadow, radius 22), 14px controls, pill chips, and
  themed list tiles, switches, segmented buttons and tab bars.
- `sukun_design.dart`: white `SukunSurface` cards use soft elevation instead
  of borders. `SukunBottomNavigation` is a floating rounded bar; admin mode
  (`navyEmphasis`) marks the active tab in Night Navy.

### Screens
| Screen | File | What changed |
|---|---|---|
| Admin dashboard | `features/home/presentation/role_home_screens.dart` | Navy welcome card, 4 quick tiles, grouped link rows |
| User home | `features/home/presentation/unified_home_screen.dart` | "Next amal" card moved to the top with Start and All buttons plus the next two items; 4-column resource grid; calmer notice button; no gradient on the prayer card |
| Login | `features/auth/presentation/login_screen.dart` | Mist brand hero with the untouched official logo |
| Admin tabs | `admin_scaffold.dart`, `role_navigation_shell.dart` | Navy active tab |
| Patient list | `features/patients/presentation/patients_list_screen.dart` | Status filter pills with counts, initial avatars, real status pill (was always "চালু"), code and phone on one line, Users tab highlighted |
| Patient detail | `features/patients/presentation/patient_detail_screen.dart` | Identity header, tabs (সারাংশ, পরিকল্পনা, নির্দেশনা), progress ring, bottom action bar |

## Feature-preservation checklist

### Admin dashboard (`/admin/dashboard`)
| Old entry point | Route | Where it is now |
|---|---|---|
| নতুন রোগী যোগ করুন | `/admin/patients/new` | Quick tile 1 |
| রোগী খুঁজুন | `/admin/patients` | Quick tile 2 |
| সকল ব্যবহারকারী (button and header link) | `/admin/users` | Quick tile 3, also the Users tab |
| ব্যবহারকারীর রুটিন ও অগ্রগতি | `/admin/user-routines` | Quick tile 4 |
| প্রস্তুত রুটিন / রুটিন টেমপ্লেট | `/admin/routine-templates` | Row "রুটিন টেমপ্লেট (প্রস্তুত রুটিন)" |
| রোগীর পরিকল্পনা ও অগ্রগতি | `/admin/patients` | Row in "রোগী ও অগ্রগতি" |
| উপকরণ পরিচালনা করুন / কনটেন্ট পরিচালনা | `/admin/content` | Row in "একই উপকরণ, সবার জন্য" |
| সবার লাইব্রেরি / পাবলিক উপকরণ লাইব্রেরি | `/resources` (push) | Section action and row |
| সবার জন্য নোটিশ | `/admin/announcements` | Row, also the Notices tab |
| নামাজের সময়, কিবলা | `/prayer-times`, `/qibla` | "প্রয়োজনীয় টুলস" cards |
| রিসোর্স | `/resources` | Section action |
| Sign out | AppBar | Unchanged |

### User home (`/`, `/patient/home`)
| Old entry point | Where it is now |
|---|---|
| Greeting, "আপনার প্রতিদিনের সুকুন" | Unchanged header |
| নোটিশ shortcut (`/announcements`) | Same button, calmer style |
| Next amal (`/my-routines`) | Top card; whole card still opens `/my-routines`; new Start button opens the action's own route |
| Prayer card: city picker, countdown ring, 5 prayers, কিবলা, পূর্ণ সময়সূচি | Unchanged content and keys |
| Hidden 40-day challenge (`SUKUN_SHOW_40_DAY_CHALLENGE`) | Unchanged, still off by default |
| 8 resource sections and "সব দেখুন" | 4-column grid, same keys and routes |
| Guest login prompt, Login/Logout | Unchanged |

### Patient list (`/admin/patients`)
| Old entry point | Where it is now |
|---|---|
| Search by name, phone or code (submit, clear) | Same search field |
| Pull to refresh, loading, error with retry, empty state | Unchanged |
| Open patient (`/admin/patients/:id`) | Tap any row |
| নতুন রোগী যোগ করুন (`/admin/patients/new`) and success snackbar | Same floating button |
| Status pill | Now shows the real status (চালু, নিষ্ক্রিয়, সংরক্ষিত) |
| New | Status filter pills. They only filter the rows the search already loaded |

### Patient detail (`/admin/patients/:id`)
| Old entry point | Where it is now |
|---|---|
| Name, patient code, phone, status | Header at the top |
| 7-day progress (completed, skipped, remaining, retry on error) | সারাংশ tab, ring card |
| Care plan list, version count, open a plan (`plans/:planId`) | পরিকল্পনা tab (all versions); active plans also on সারাংশ |
| Empty plans with "সেবা পরিকল্পনা তৈরি করুন" | Same empty card on both tabs |
| Prescription list with visibility, session date, saved date, full text | নির্দেশনা tab; latest one also on সারাংশ |
| "সেবা পরিকল্পনা সাজান" from a prescription (`plans/new?prescriptionId=`) | Each prescription card |
| "+" button menu: add prescription (`prescriptions/new`) or create plan (`plans/new`) | Replaced by two always-visible buttons in the bottom bar, same routes and success messages |
| Pull to refresh, loading, error, not-found states | Unchanged |

Tests: `test/features/patients/patient_detail_redesign_test.dart` (6 tests) proves each row above still works.

## Verification
- `flutter analyze`: no issues.
- `flutter test`: 547 passed, 3 skipped (same as before the change).
- Web screenshots at 390x844 of admin home, member home, guest home and login.

## Still to do (next passes)
Rework these into the approved layout, using the same checklist approach:
prescription to plan wizard (3 steps), content
library and notices, routine and progress, resources hub, Qur'an reader and
audio player, account and settings. The admin "আজ যা দেখতে হবে" counts need
real data queries, so they are not added yet (no invented numbers).
