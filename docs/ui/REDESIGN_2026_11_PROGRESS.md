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

### Prescription to plan (`/admin/patients/:id/prescriptions/new` → `plans/:planId`)
Shared pieces: `SukunStepper` (লিখুন → যাচাই → অনুমোদন) and `SukunBottomActionBar` in `core/widgets/sukun_design.dart`.

| Old entry point | Where it is now |
|---|---|
| Typed or uploaded prescription, session date, patient visibility, idempotent save, retry from stored PDF, draft-conflict dialogs, "নিজে প্রেসক্রিপশন লিখুন" | Same screen with stepper step 1; save-only is now the quieter outlined button |
| `ai_configuration_missing` message | **Changed:** no longer names the AI provider (AGENTS.md rule 12); offers the manual path |
| AI review: select, "select ready", filters, bulk morning/evening time, resource matches, Qur'an references, material draft, manual builder, retry | Same, all in Bangla; original prescription now open by default; needs-review cards have a Saffron border |
| After Import | **Changed:** continues to the plan builder (was: back to patient detail). When the builder opened the review (`?from=builder`), it returns there as before |
| Manual builder from AI review | From a new prescription it opens the builder with `addAction=1`; from the builder it keeps the old editor push |
| Patient detail after the flow | Always reloads plans and prescriptions when the flow returns |
| Builder: preview, add action, actions from prescription, publish (blocked until all approved), new version, archive, reorder, duplicate, reject, `addAction=1` | Publish and preview in a fixed bottom bar; add/generate (or archive) under the summary; everything else unchanged |
| Approving an action | **New:** "অনুমোদন" button on each unapproved card with a confirmation dialog. Uses `approvePlanAction` (`care_plans/domain/plan_action_approval.dart`): the same `saveAction` input the editor sends, plus the same multi-resource relink, so linked resources survive. The editor's status field still works |
| Action editor | Numbered step headings, save button fixed at the bottom; fields, keys and validation unchanged |
| Preview | Bangla copy, stepper, "প্ল্যানে ফিরে যান"; still read-only, shows approved actions only |
| New plan / new version | Stepper; prescription list now shows loading and error states |

Tests: `test/features/care_plans/plan_flow_redesign_test.dart` (approval keeps every field, restores resources, confirm/cancel, stepper) and two navigation tests in `ai_action_suggestion_test.dart`. Three older tests were updated to the Bangla copy with the same meaning.

### Routine and progress (`/my-routines`, `/patient/today`)
New shared parts: `features/personal_routines/presentation/routine_hub_parts.dart` (tab switch, routine card, Bangla schedule/outcome labels, delete confirmation).

| Old entry point | Where it is now |
|---|---|
| Tabs আমার রুটিন / নির্ধারিত / আজকের রুটিন | **Changed:** আজ / আমার রুটিন / অগ্রগতি. Today opens first |
| `?tab=today` | Today |
| `?tab=progress` (and `/progress`) | **Fixed:** now opens the Progress tab (used to open Today) |
| `?tab=assigned` | My Routines, scrolled to "প্রস্তুত রুটিন" |
| `?resourceId=` (add from library) | My Routines with the library hint card, as before |
| Reminder bell (enable/disable, permission messages) | AppBar, unchanged |
| AppBar "+ নতুন রুটিন" | Removed as a duplicate; the in-page "নতুন রুটিন তৈরি করুন" button stays |
| Pause/Resume, Delete routine | Routine card menu: থামান / আবার চালু করুন, মুছে ফেলুন. **New:** asks before deleting |
| Action menu Done, Skip, Edit, Duplicate, Delete | Same choices in Bangla. **New:** asks before deleting |
| Raw `schedule_kind` and outcome values | Bangla schedule text and a status pill (আজ সম্পন্ন / আজ বাদ / আজ বাকি) |
| Add/edit action dialog (resources, surah, ayah, schedule, prayer offset, previews) | Same dialog. **New:** says what is missing instead of silently ignoring Save |
| Ready-made routine templates and "রুটিনে যোগ করুন" | "প্রস্তুত রুটিন" section at the end of My Routines (key `routine-assigned-tab`) |
| Patient links: approved plan (`/patient/plan`), today (`/patient/today`) | Plan link at the top of My Routines; today as the large navy card at the top of Today |
| Today ring, counts, toggle done/undo, open detail | Same keys and texts in a calm white card |
| "আগের দিনের অগ্রগতি দেখুন" (bottom sheet) | Same button, now switches to the Progress tab |
| Progress 7/30 days, summary, per-day history, patient progress link, disclaimer | Progress tab: pills, ring summary, Bangla dates (was ISO), same data |
| Action detail: resources, reader settings, reminder deep link, done, skip | Done and "আজ বাদ দিন" in a fixed bottom bar; Bangla copy |
| `/patient/today` | **Fixed:** the bottom bar now highlights রুটিন (was হোম); greeting in Bangla |

Tests: `test/features/personal_routines/routine_hub_redesign_test.dart` (12 tests).

### Resources hub and Qur'an reader (`/resources`, `/resources/quran[/:n]`)
| Old entry point | Where it is now |
|---|---|
| Intro, search (debounced, no catalog load before a query), backend-unavailable note, search results | Unchanged |
| Admin "নতুন রিসোর্স যোগ করুন", "রিসোর্স পরিচালনা" | Same buttons as quiet text buttons under the intro |
| "আমার প্লেলিস্ট ও অফলাইন ডাউনলোড", "রুকইয়াহ অডিও" dialog, "রুকইয়াহর আয়াত পড়ুন" (external) | Three compact tiles in one row (were three stacked full-width buttons) |
| 8 section tiles | Unchanged (same grid sizes, tests intact) |
| Surah list (number, name, ayah count, prelive notice, retry, Quran.com fallback) | Calm cards with number badge and Arabic name; same tap target and texts ("Quran.com এ পড়ুন") |
| Surah reader: full-surah play, per-ayah play, highlight and auto-scroll, `?ayah=` deep link, paging, reader settings, audio shortcut | Same; calmer header and verse cards (highlight colours unchanged) |
| Source attribution | Still hidden, by the owner's decision on 9 Nov 2026 (see question log) |
| Hadith and ayat-collection screens | English titles/labels translated to Bangla |
| **New:** continue reading | `QuranLastReadStore` (device only, `sukun.quran.last_read`): saved on scroll, verse play, full-surah playback and the new per-verse "এখান থেকে পরে পড়ব" bookmark. "Continue Reading" card on the hub and above the surah list. Cleared when the signed-in account changes |

Not changed on purpose: "আজকের আয়াত" (needs an approved daily-ayah source first), the dead `QuranBrowserScreen`/`QuranSurahScreen` code (no route), the admin collections screen (library pass).

Tests: `test/features/resources/quran_continue_reading_test.dart` (4 tests).

### Account and settings (`/account`, `/settings/*`)
| Old entry point | Where it is now |
|---|---|
| Navy profile card (name, email, patient/member label) | White profile card with the name's initial and a role pill |
| Page intro "অ্যাকাউন্ট ও সেটিংস" | Removed as a duplicate of the AppBar title |
| Patient "আমার যত্ন" (plan, clinical settings) | **Moved first** for patients, right after the profile |
| "আমার কার্যক্রম" (playlist, routine, progress, notices) and "পছন্দ ও সেটিংস" (appearance, notifications, Android update) | Same entries, keys and routes; section titles above calm cards |
| Sign out | Same button (key `account-sign-out`), red text. **New:** asks "লগআউট করবেন?" first |
| Notification health settings | Same controls; plain cards replaced by Sukun cards |
| Patient profile web permission message | Translated to Bangla |
| Appearance and Bengali font settings | Already Bangla and on the theme; unchanged |

Tests: `test/features/account/account_redesign_test.dart` (3 tests).

### Admin library, notices and the full audio player
| Old entry point | Where it is now |
|---|---|
| Content preview workflow buttons | **Bug fixed:** a past bulk translation had turned stored status values into Bangla (`'প্রকাশিত হয়েছে'` etc.), so canonical Qur'an/Hadith items could never be published, "প্রকাশ বন্ধ করুন" never appeared and archive always appeared. Restored to the real values (`verified`, `published`, `archived`). Covered by `admin_preview_status_actions_test.dart` (fails on the old code) |
| Ayat collections screen (list, menu, editor dialog) | Same actions and data, all copy in Bangla; stored values shown as Bangla labels |
| Content editor source sheet and placeholders | Bangla copy |
| Content editor preview / save draft / submit | Fixed bottom bar (keys `content-editor-*`), same actions |
| Staging private draft import button and dialog title | Bangla copy |
| Admin notices list | Sukun cards with status pills, loading/error/empty states |
| Notice editor | Same fields and `notice-*` keys; status pill, countdown and safety note in Sukun cards |
| User notices list | Sukun cards; push toggle and QA token unchanged |
| Full audio player and playlist player | Same controls and keys; solid Night Navy hero instead of a gradient, Deep Tide play button |

Tests: `admin_preview_status_actions_test.dart` (4), `admin_collections_bangla_test.dart` (1).

## Verification
- `flutter analyze`: no issues.
- `flutter test`: 584 passed, 3 skipped after the final pass (547 before the redesign).
- Web screenshots at 390x844 of admin home, member home, guest home and login.

## Still to do
- The admin "আজ যা দেখতে হবে" counts need real data queries, so they are not added yet (no invented numbers).
- Signed-in role flows (patient, member, admin) and the AI prescription flow still need a manual check on production after release.
- `docs/VISUAL_ACCEPTANCE_GATE.md` should be re-run against the new screens.
