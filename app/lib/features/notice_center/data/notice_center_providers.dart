import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/notice_center/domain/amal_reminder.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/personal_routines/data/personal_reminder_service.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_seen_store.dart';

/// Counts behind the notice badge and the two notice sections.
class NoticeCenterSummary {
  const NoticeCenterSummary({
    this.notices = const [],
    this.seenNoticeKeys = const {},
    this.amalReminders = const [],
    this.showsAmalSection = false,
  });

  final List<UniversalAnnouncement> notices;
  final Set<String> seenNoticeKeys;
  final List<AmalReminder> amalReminders;

  /// Signed-in Members and Patients get the amal section; guests do not.
  final bool showsAmalSection;

  bool isNoticeUnseen(UniversalAnnouncement notice) {
    final key = universalNoticePublicationKey(notice);
    return key != null && !seenNoticeKeys.contains(key);
  }

  int get unseenNoticeCount => notices.where(isNoticeUnseen).length;
  int get amalCount => amalReminders.length;
  int get total => unseenNoticeCount + amalCount;
}

/// Never throws: each source that fails simply contributes nothing, so the
/// home screen and notice screen stay usable when offline. Invalidate it
/// after the user opens a notice or finishes an amal.
final noticeCenterProvider = FutureProvider.autoDispose<NoticeCenterSummary>((
  ref,
) async {
  final session = ref.watch(appSessionProvider).value;
  // Recompute for the newly selected family profile, never keep the old one.
  ref.watch(activePatientIdProvider);
  final userId = session?.userId;
  final now = DateTime.now();

  var notices = const <UniversalAnnouncement>[];
  var seen = const <String>{};
  try {
    notices = await ref.read(announcementRepositoryProvider).published();
    seen = await ref.read(universalNoticeSeenStoreProvider).read(userId);
  } on Object {
    // Notice feed unavailable: show no notice count.
  }

  final signedIn = session != null && (session.isMember || session.isPatient);
  final amal = <AmalReminder>[];
  if (signedIn) {
    if (session.isPatient) {
      try {
        final day = await ref.read(patientCareRepositoryProvider).getToday();
        if (day.activePlan != null) {
          amal.addAll(dueCareReminders(day.tasks, now: now));
        }
      } on Object {
        // Care plan unavailable: the personal part can still show.
      }
    }
    if (AppEnvironment.isSupabaseConfigured) {
      try {
        final service = ref.read(personalReminderServiceProvider);
        // Only routines the user asked to be reminded about count as
        // amal notifications.
        if (await service.isEnabled()) {
          final repository = service.repository;
          final routines = await repository.listRoutines();
          final actions = await repository.listActions();
          final outcomes = await repository.todaysOutcomes(now);
          final settings = await ref
              .read(utilityPreferencesStoreProvider)
              .load();
          amal.addAll(
            duePersonalReminders(
              actions: actions,
              activeRoutineIds: {
                for (final routine in routines)
                  if (routine['is_active'] == true && routine['id'] is String)
                    routine['id'] as String,
              },
              todaysOutcomes: outcomes,
              calculator: ref.read(prayerCalculationServiceProvider),
              settings: settings,
              now: now,
            ),
          );
        }
      } on Object {
        // Personal routines unavailable.
      }
    }
  }

  // A different person may have signed in while the requests were running.
  if (ref.read(appSessionProvider).value?.userId != userId) {
    return const NoticeCenterSummary();
  }
  return NoticeCenterSummary(
    notices: notices,
    seenNoticeKeys: seen,
    amalReminders: sortAmalReminders(amal),
    showsAmalSection: signedIn,
  );
});
