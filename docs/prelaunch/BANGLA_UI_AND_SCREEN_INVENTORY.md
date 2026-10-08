# Sukun Life — Screen, State & Bengali Language Inventory

Captured: 2026-10-08; Phase 0 seed inventory (source-level).
Status: STARTED; NOT A COMPLETE DEVICE SCREENSHOT AUDIT.
Source branch main at 83622430; compare changes in web-preview PR #2 before implementation.

## 1. Bengali-first product language contract

- Language shown to all end users and admins: natural, familiar Bangla (Bangladesh) by default, including directions, forms, state and error messages. Technical implementation language remains internal.
- Prefer short verbs and obvious next actions, not word-for-word translations. Phrase error states as what happened + what next, without false guarantees or blaming users.
- Avoid in customer-visible UI: RPC, JWT, PostgREST, Schema, canonical, enum, parser, sync failure, request ID, debug, timeout stack trace, failed query, unknown exception, SQL, token, endpoint and HTTP status.
- Do not translate original Arabic scripture/hadith word-for-word; preserve verified source text and source metadata, label any approved translation as translation. Respect Arabic script direction and licensed Arabic-capable font; do not force Tiro Bangla as an Arabic font.
- A 'করণীয়' is a scheduled user task; 'আমল' only when the particular task is an act of religious practice. Do not assume all tasks are the same.
- An action made in the app does not become a treatment recommendation; don't invent clinical/religious details. Preserve explicit clinician/admin approval and plan history.
- Patient and admin can have different explanatory copy for the same status; admin wording must still be understandable and preserve safety requirements.
- Static instructions, generated labels with names/counts, accessibility semantics, keyboard and screen reader labels, local reminders and FCM push titles/bodies all require localization.
- Avoid exposing patient identity/treatment details in lock-screen push previews; use generic approved reminder text.

## 2. Proposed terms (copy review required)

| Internal English | Patient | Admin |
|---|---|---|
| Today / Dashboard | আজকের করণীয় | কাজের সারসংক্ষেপ |
| My Plan / Care Plan | আমার পরিকল্পনা | রোগীর পরিকল্পনা |
| Plan action | করণীয় | করণীয় কাজ |
| Action type | — | কাজের ধরন |
| Frequency | কতদিন পরপর | কতদিন পরপর করবেন |
| Daily / Every N days | প্রতিদিন / প্রতি N দিন পর | প্রতিদিন / প্রতি N দিন পর |
| Time window | কখন করবেন | করণীয়ের সময় |
| Exact time | নির্ধারিত সময় | নির্দিষ্ট সময় |
| Reminder | মনে করিয়ে দেওয়া | মনে করিয়ে দেওয়ার সময় |
| Snooze | পরে মনে করিয়ে দিন | — |
| Skip | আজ করা হয়নি | — |
| Done / Complete | করেছি | সম্পন্ন |
| Resources | পাঠ ও অডিও | সহায়ক উপকরণ |
| Linked resource | নির্ধারিত উপকরণ | যুক্ত উপকরণ |
| Progress | আমার অগ্রগতি | অগ্রগতি |
| Draft | — | খসড়া |
| Needs review | — | যাচাই বাকি |
| Approved | — | অনুমোদিত |
| Publish | — | রোগীর জন্য চালু করুন |
| Unpublish | — | ব্যবহারকারীদের জন্য বন্ধ করুন |
| Save Draft | — | খসড়া হিসেবে রাখুন |
| Generate action suggestions | — | প্রেসক্রিপশন থেকে করণীয় সাজান |
| Import actions | — | নির্বাচিত করণীয় যোগ করুন |
| Content CMS | — | উপকরণ ব্যবস্থাপনা |
| Resource unavailable | উপকরণটি এখন দেখা যাচ্ছে না | উপকরণটি পাওয়া যায়নি |
| Retry | আবার চেষ্টা করুন | আবার চেষ্টা করুন |
| Pending sync | অনলাইনে জমা বাকি | অনলাইনে জমা বাকি |

Terms are proposals, not approved source text. Clinical and Bangla-language owners must sign off before release.

## 3. Source-screen checklist by role (not device-verified yet)

Columns: localization inventory / state inventory / on-device or user-test / status.
All items below are OPEN unless otherwise explicitly recorded.

### Public / authentication

| Screen/source | Required Bangla surface |
|---|---|
| features/auth/presentation/login_screen.dart | login headings, ID/phone, password, reset/guidance, errors, sign in |
| features/auth/presentation/change_password_screen.dart | new password, confirm, password rules, success/error |
| features/home/presentation/role_home_screens.dart | guest landing, entry actions, basic resource explanation |
| features/resources/presentation/resources_home_screen.dart | browse library, search, section, none found, retry |
| features/resources/presentation/resource_browse_screens.dart | Qur'an, Surah/Ayah, collections, Hadith topics, Dua/Azkar, Ruqyah taxonomy |
| features/resources/presentation/resource_detail_screen.dart | source verification, Arabic, Bangla, translation, media opener and unavailable |
| features/resources/presentation/audio_player_screen.dart | player, seek, speed, error/retry and accessibility |
| features/resources/presentation/youtube_player_screen.dart | loading/error/rights/external content |
| features/islamic_utilities/presentation/prayer_times_screen.dart | prayer names, remaining time, location/timezone, unavailable |
| features/islamic_utilities/presentation/prayer_settings_screen.dart | location, calculation settings, permission errors |
| features/islamic_utilities/presentation/qibla_screen.dart | compass alignment, calibrate, location/sensor error |

### Patient mode

| Screen/source | Required Bangla surface |
|---|---|
| features/patient_care/presentation/patient_home_screen.dart | greeting, today, next task, completed/snooze/skip, offline pending, error |
| features/patient_care/presentation/my_plan_screen.dart | published plan, current prescription, ordered actions and dates |
| features/patient_care/presentation/patient_progress_screen.dart | daily/weekly progress, units, completed/snoozed/skipped |
| features/patient_care/presentation/patient_profile_screen.dart | reminder permission, exact alarms, settings, sign out |
| features/patient_care/presentation/patient_scaffold.dart | all five bottom-nav labels, focus/read order, semantics |
| app/router/app_router.dart | expired session/not found/unauthorized/route errors |
| core/notifications/reminder_schedule.dart | local notification title/body, snooze title/body |

### Super-admin mode

| Screen/source | Required Bangla surface |
|---|---|
| features/home/presentation/role_home_screens.dart | work summary, quick access, main tasks |
| features/home/presentation/admin_scaffold.dart | Dashboard / Patients / Content and semantics |
| features/patients/presentation/patients_list_screen.dart | patient search and add, loading/errors |
| features/patients/presentation/create_patient_screen.dart | patient data/credentials; sensitive helper messages |
| features/patients/presentation/patient_detail_screen.dart | overview, prescriptions, plan versions, add actions |
| features/patients/presentation/create_prescription_screen.dart | original instruction, validation, sources/attachments in PR #2 |
| features/care_plans/presentation/create_care_plan_screen.dart | create version, link prescription, dates and status |
| features/care_plans/presentation/care_plan_builder_screen.dart | action cards, reorder, publish blocker, review, archive |
| features/care_plans/presentation/plan_action_editor_screen.dart | type/title/count/duration/frequency/interval/time/media/review |
| features/care_plans/presentation/ai_action_review_screen.dart | AI parsed suggestions, confidence/uncertainty, manual fallback |
| features/care_plans/presentation/care_plan_preview_screen.dart | patient view and unpublished content not shown |
| features/content_admin/presentation/admin_content_list_screen.dart | search, category/status filters, empty/no result |
| features/content_admin/presentation/admin_content_editor_screen.dart | resource type, guided fields, provenance, submission |
| features/content_admin/presentation/admin_content_preview_screen.dart | verify, source check, publish, reject, audit history |
| features/content_admin/presentation/admin_content_collections_screen.dart | order/source/selection/publish of Ayah collections |

### Shared components, notifications and non-screen surfaces

| Source | Required Bangla surface |
|---|---|
| core/widgets/async_states.dart | default loading/empty/error/retry text, semantics |
| core/widgets/sukun_design.dart | pill/choice/dialog/search/decision labels if baked-in |
| core/media/audio_playback_controller.dart | localized playback failure, not low-level URL failure |
| core/media/external_resource_launcher.dart | unavailable media / retry paths |
| core/notifications/local_notifications_gateway.dart | notification channel title/body/permission surfaces |
| core/notifications/notification_coordinator.dart | reliable but non-technical failure status |
| Supabase Edge Functions | response error codes mapped at Flutter boundary; push title/body and permission-safe metadata |
| Android app name/channel description and iOS display metadata | localized visible system-level surfaces |
| PR #2 resource_picker_sheet.dart | search/type/category/empty/result preview, semantics and manual entry |
| Notification Inbox (not implemented) | read/unread, grouped history, safe links and access-denied states |
| Dialogs / modals / snackbars / forms in all files | confirmations, helper text, validation and retry |

## 4. Minimum UI-state matrix for EVERY primary screen

| State | User should understand |
|---|---|
| Loading | কী তথ্য আনা হচ্ছে, খুব ছোট ও প্রাসঙ্গিক বাক্য |
| Empty (no data) | এখানে এখনো কিছু দেওয়া হয়নি; দরকার হলে পরের কাজ |
| No search match | খোঁজার ফল পাওয়া যায়নি; অন্য শব্দ/ফিল্টার |
| Connection unavailable | ইন্টারনেট দেখে আবার চেষ্টা |
| Server unavailable | এখন সেবা পাওয়া যাচ্ছে না; পরে আবার চেষ্টা |
| No permission | অনুমতি নেই; কী করতে পারবেন |
| Form validation | কোন ঘরে কী দিতে হবে |
| Save pending (offline) | ফোনে রাখা আছে, অনলাইনে জমা বাকি |
| Save success | শুধু সত্যিকার confirmed success |
| Review/publish blocked | কোন নির্দিষ্ট তথ্য বা যাচাই বাকি |
| Invalid/unpublished media | খোলা যাচ্ছে না; নিরাপদ বিকল্প |
| Notification disabled | ডিভাইস সেটিংস থেকে চালু করার পথ |
| Navigating away unsaved | সংরক্ষণ না করা তথ্য হারাতে পারে |
| Accessibility | ট্যাপের লক্ষ্য, উচ্চ contrast, 200% text scaling, ordered labels |

## 5. Known strings requiring centralization

Concrete currently-present source examples:
- 'Care plan builder', 'Structured actions', 'Generate action suggestions'
- 'Edit action', 'Action type', 'Frequency', 'Review status', 'Linked resource'
- 'There are no actions scheduled for today.'
- 'Care reminders', 'Enable reminders', 'Allow precise timing'
- 'No published resources found', 'Loading resources'
- 'Something needs attention', 'Try again'
- 'Sukun Life reminder', 'An approved care action is ready.'
- bottom navigation: 'Today', 'My Plan', 'Resources', 'Progress', 'Profile', 'Dashboard', 'Patients', 'Content'

Caution: some examples are direct source literals; formatting/data-dependent strings need interpolation keys and translation placeholders. Do not auto-replace English in code identifiers, backend diagnostic tags, immutable IDs, verified Arabic text or third-party rights/license notices.

## 6. Language engineering acceptance

1. Introduce dedicated Flutter l10n/ARB resource bundles and default bn_BD supported locale. Keep an English reference for developers/test if desired.
2. Shared AppFailureCode -> UserFacingBanglaMessage mapping; no raw exception text anywhere visible or in accessibility labels.
3. Enforce CI lint for new hardcoded English in user-facing widgets; allow documented technical non-UI strings. Avoid simplistic regex as final truth; manually review exceptions.
4. QA dates, times, numerals, plurals/placeholders, RTL Arabic, Bangla fallback, screen-reader labels and keyboard order.
5. Notify separate reviewer(s) to approve canonical religious text/translations and instruction semantics.
6. Cross-check patient/general guest/admin flows on 360x640 and 430x932 logical sizes with large text and physical Android/iOS devices.
7. Use a device capture/evidence directory outside git containing REDACTED screenshots and scenario IDs; do not commit PHI.
8. L10n coverage target: 100% *user-visible* copy; test that defaults and failure paths also receive Bengali copy.
9. Never claim a state is translated until it is run/rendered and reviewed.

Evidence baseline: 28 presentation/role home/browsing files searched for source patterns -> 33 raw error-toString occurrences, 207 direct Text literal patterns and 239 English-leading field literal patterns. These patterns overlap and omit nonliteral/interpolated strings; actual localized key count is still unmeasured. app_router.dart adds one direct raw error path.

Related risk register: docs/prelaunch/PRELAUNCH_BUG_REGISTER.md.
Reference: https://docs.flutter.dev/ui/internationalization.
