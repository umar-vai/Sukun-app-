import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_notification_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_preferences_store.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settings = PrayerUtilitySettings(
    location: UtilityLocation(
      id: 'dhaka',
      name: 'Dhaka',
      latitude: 23.8103,
      longitude: 90.4125,
      timezone: 'Asia/Dhaka',
      source: UtilityLocationSource.manual,
    ),
    calculationMethod: PrayerCalculationMethodOption.karachi,
    asrConvention: AsrConvention.hanafi,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no prayer notification is scheduled before opt-in', () async {
    final gateway = _FakeGateway();
    final service = PrayerNotificationService(
      local: gateway,
      calculator: AdhanPrayerCalculationService(),
      settingsStore: const _StoredPrayerSettings(settings),
    );
    expect(await service.isEnabled(), isFalse);
    expect(await service.refresh(), 0);
    expect(gateway.scheduled, isEmpty);
    expect(gateway.permissionRequests, 0);
  });

  test(
    'explicit opt-in schedules and disable cancels only prayer IDs',
    () async {
      final gateway = _FakeGateway();
      final service = PrayerNotificationService(
        local: gateway,
        calculator: AdhanPrayerCalculationService(),
        settingsStore: const _StoredPrayerSettings(settings),
      );
      expect(await service.enable(), isTrue);
      expect(await service.isEnabled(), isTrue);
      expect(gateway.permissionRequests, 1);
      expect(gateway.scheduled, isNotEmpty);
      final ids = gateway.scheduled.keys.toSet();

      await service.disable();
      expect(await service.isEnabled(), isFalse);
      expect(gateway.scheduled, isEmpty);
      expect(gateway.cancelled.containsAll(ids), isTrue);
    },
  );

  test('concurrent refresh requests share one scheduling pass', () async {
    final gateway = _FakeGateway();
    final service = PrayerNotificationService(
      local: gateway,
      calculator: AdhanPrayerCalculationService(),
      settingsStore: const _StoredPrayerSettings(settings),
    );
    expect(await service.enable(), isTrue);
    gateway.scheduleCalls = 0;
    await Future.wait([service.refresh(), service.refresh()]);
    expect(gateway.scheduleCalls, gateway.scheduled.length);
    expect(gateway.scheduled, isNotEmpty);
  });

  test('turning off during refresh leaves no new alarms', () async {
    final gateway = _FakeGateway();
    final service = PrayerNotificationService(
      local: gateway,
      calculator: AdhanPrayerCalculationService(),
      settingsStore: const _StoredPrayerSettings(settings),
    );
    expect(await service.enable(), isTrue);
    final updating = service.refresh();
    await service.disable();
    await updating;
    expect(await service.isEnabled(), isFalse);
    expect(gateway.scheduled, isEmpty);
  });

  test('missing city prevents permission prompts and scheduling', () async {
    final gateway = _FakeGateway();
    final service = PrayerNotificationService(
      local: gateway,
      calculator: AdhanPrayerCalculationService(),
      settingsStore: const _StoredPrayerSettings(PrayerUtilitySettings()),
    );
    await expectLater(service.enable(), throwsStateError);
    expect(gateway.permissionRequests, 0);
    expect(gateway.scheduled, isEmpty);
  });
}

class _StoredPrayerSettings implements UtilityPreferencesStore {
  const _StoredPrayerSettings(this.settings);

  final PrayerUtilitySettings settings;

  @override
  Future<PrayerUtilitySettings> load() async => settings;

  @override
  Future<void> save(PrayerUtilitySettings settings) async {}
}

class _FakeGateway implements LocalNotificationsGateway {
  int permissionRequests = 0;
  int scheduleCalls = 0;
  final Map<int, ReminderSchedule> scheduled = {};
  final Set<int> cancelled = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> requestPreciseSchedulingPermission() async => false;

  @override
  Future<bool> canSchedulePrecisely() async => false;

  @override
  Future<String> configureTimezone() async => 'Asia/Dhaka';

  @override
  Future<void> schedule(
    ReminderSchedule reminder, {
    required bool precise,
  }) async {
    scheduleCalls++;
    scheduled[reminder.notificationId] = reminder;
  }

  @override
  Future<void> cancel(int notificationId) async {
    scheduled.remove(notificationId);
    cancelled.add(notificationId);
  }

  @override
  Future<void> showRemote({
    required String title,
    required String body,
    String? payload,
  }) async {}
}
