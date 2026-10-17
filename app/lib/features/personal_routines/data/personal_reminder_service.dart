import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_preferences_store.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_reminder_planner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final personalReminderServiceProvider = Provider<PersonalReminderService>((
  ref,
) {
  return PersonalReminderService(
    repository: PersonalRoutineRepository(Supabase.instance.client),
    local: ref.watch(localNotificationsGatewayProvider),
    calculator: ref.watch(prayerCalculationServiceProvider),
    settingsStore: ref.watch(utilityPreferencesStoreProvider),
  );
});

/// Schedules a bounded window of reminders only after explicit user opt-in.
/// On Web, the current gateway only delivers while the tab is active.
class PersonalReminderService {
  const PersonalReminderService({
    required this.repository,
    required this.local,
    required this.calculator,
    required this.settingsStore,
  });

  final PersonalRoutineRepository repository;
  final LocalNotificationsGateway local;
  final PrayerCalculationService calculator;
  final UtilityPreferencesStore settingsStore;

  String _enabledKey(String ownerId) => 'personal_reminders_enabled:$ownerId';
  String _idsKey(String ownerId) => 'personal_reminder_ids:$ownerId';

  Future<bool> isEnabled() async {
    final owner = repository.ownerId;
    return (await SharedPreferences.getInstance()).getBool(
          _enabledKey(owner),
        ) ??
        false;
  }

  Future<bool> enable() async {
    await local.initialize();
    if (!await local.requestPermission()) return false;
    final owner = repository.ownerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey(owner), true);
    await refresh();
    return true;
  }

  Future<void> disable() async {
    final owner = repository.ownerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey(owner), false);
    await cancelOwner(owner);
  }

  Future<void> cancelOwner(String ownerId) async {
    await local.initialize();
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_idsKey(ownerId)) ?? const [];
    for (final value in ids) {
      final id = int.tryParse(value);
      if (id != null) await local.cancel(id);
    }
    await prefs.remove(_idsKey(ownerId));
  }

  Future<int> refresh() async {
    final owner = repository.ownerId;
    if (!await isEnabled()) return 0;
    await local.initialize();
    if (!await local.isPermissionGranted()) {
      await cancelOwner(owner);
      return 0;
    }
    final routines = await repository.listRoutines();
    final actions = await repository.listActions();
    final settings = await settingsStore.load();
    final active = {
      for (final routine in routines)
        if (routine['is_active'] == true) routine['id'] as String,
    };
    final scheduled = planPersonalRoutineReminders(
      ownerId: owner,
      actions: actions,
      activeRoutineIds: active,
      calculator: calculator,
      settings: settings,
      now: DateTime.now(),
    );
    // Never cancel clinician-prescribed care reminders: only cancel IDs
    // stored under this owner-specific personal namespace.
    await cancelOwner(owner);
    final precise = await local.canSchedulePrecisely();
    final ids = <String>[];
    for (final reminder in scheduled) {
      await local.schedule(reminder, precise: precise);
      ids.add(reminder.notificationId.toString());
    }
    await (await SharedPreferences.getInstance()).setStringList(
      _idsKey(owner),
      ids,
    );
    return ids.length;
  }
}
