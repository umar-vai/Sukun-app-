import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/home/domain/home_next_actions.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final calculator = AdhanPrayerCalculationService();
  final now = DateTime.utc(2026, 10, 19, 10);

  List<HomeNextAction> select({
    required List<Map<String, dynamic>> routines,
    required List<Map<String, dynamic>> actions,
    Map<String, String> outcomes = const {},
  }) => HomeNextActions.select(
    now: now,
    patientDay: null,
    routines: routines,
    actions: actions,
    outcomes: outcomes,
    settings: const PrayerUtilitySettings(),
    calculator: calculator,
  );

  final routines = <Map<String, dynamic>>[
    {'id': 'owned-routine', 'is_active': true},
    {'id': 'paused-routine', 'is_active': false},
  ];

  test('shows only active own routine actions; links directly to detail', () {
    final items = select(
      routines: routines,
      actions: [
        {
          'id': 'active-action',
          'routine_id': 'owned-routine',
          'title': 'আমল',
          'schedule_kind': 'manual',
          'is_active': true,
        },
        {
          'id': 'paused-action',
          'routine_id': 'paused-routine',
          'title': 'Hidden',
          'schedule_kind': 'manual',
          'is_active': true,
        },
        {
          'id': 'disabled-action',
          'routine_id': 'owned-routine',
          'title': 'Hidden',
          'schedule_kind': 'manual',
          'is_active': false,
        },
      ],
    );
    expect(items, hasLength(1));
    expect(items.single.route, '/my-routines/action/active-action');
    expect(items.single.origin, 'আমার তৈরি রুটিন');
  });

  test('omits completed or skipped manual work for current day', () {
    final items = select(
      routines: routines,
      actions: [
        {
          'id': 'done-action',
          'routine_id': 'owned-routine',
          'title': 'Done',
          'schedule_kind': 'manual',
          'is_active': true,
        },
      ],
      outcomes: {'done-action': 'done'},
    );
    expect(items, isEmpty);
  });

  test('fixed routines are ordered by next occurrence', () {
    final items = select(
      routines: routines,
      actions: [
        {
          'id': 'later',
          'routine_id': 'owned-routine',
          'title': 'Later',
          'schedule_kind': 'fixed',
          'local_time': '22:00:00',
          'timezone_name': 'Asia/Dhaka',
          'is_active': true,
        },
        {
          'id': 'earlier',
          'routine_id': 'owned-routine',
          'title': 'Earlier',
          'schedule_kind': 'fixed',
          'local_time': '18:00:00',
          'timezone_name': 'Asia/Dhaka',
          'is_active': true,
        },
      ],
    );
    expect(items.map((action) => action.id).toList(), ['earlier', 'later']);
    expect(items.first.dueAt, isNotNull);
  });

  test('completed Fajr action schedules next local day, not day after', () {
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
    final items = HomeNextActions.select(
      now: now,
      patientDay: null,
      routines: routines,
      actions: [
        {
          'id': 'fajr-action',
          'routine_id': 'owned-routine',
          'title': 'Morning amal',
          'schedule_kind': 'fajr',
          'prayer_offset_minutes': 5,
          'is_active': true,
        },
      ],
      outcomes: {'fajr-action': 'done'},
      settings: settings,
      calculator: calculator,
    );
    expect(items, hasLength(1));
    final local = tz.TZDateTime.from(
      items.single.dueAt!,
      tz.getLocation('Asia/Dhaka'),
    );
    expect(local.year, 2026);
    expect(local.month, 10);
    expect(local.day, 20);
  });

  test('invalid timings and prayer preferences never invent a due time', () {
    final items = select(
      routines: routines,
      actions: [
        {
          'id': 'invalid-fixed',
          'routine_id': 'owned-routine',
          'title': 'Invalid',
          'schedule_kind': 'fixed',
          'local_time': '28:90:00',
          'timezone_name': 'Asia/Dhaka',
          'is_active': true,
        },
        {
          'id': 'no-prayer-setting',
          'routine_id': 'owned-routine',
          'title': 'Missing prayer settings',
          'schedule_kind': 'fajr',
          'prayer_offset_minutes': 5,
          'is_active': true,
        },
      ],
    );
    expect(items, isEmpty);
  });
  test('renders scheduled next action with Bengali weekday, date and time', () {
    const id = 'patient-plan-task';
    final action = HomeNextAction(
      id: id,
      title: 'করণীয়',
      origin: 'সুকুনের অনুমোদিত পরিকল্পনা',
      route: '/patient/today?task=$id',
      dueAt: DateTime(2026, 10, 21, 1, 52),
    );
    expect(HomeNextActions.dueLabel(action), 'বুধবার, ২১ অক্টোবর · রাত ১:৫২');
  });

  test('shows Bengali afternoon, padded minutes and no due time', () {
    final upcoming = HomeNextAction(
      id: 'owned',
      title: 'রুটিন',
      origin: 'আমার তৈরি রুটিন',
      route: '/my-routines/action/owned',
      dueAt: DateTime(2026, 10, 21, 13, 5),
    );
    expect(
      HomeNextActions.dueLabel(upcoming),
      'বুধবার, ২১ অক্টোবর · দুপুর ১:০৫',
    );
    expect(
      HomeNextActions.dueLabel(
        const HomeNextAction(
          id: 'manual',
          title: 'আমল',
          origin: 'আমার তৈরি রুটিন',
          route: '/my-routines/action/manual',
        ),
      ),
      'সময় নির্ধারিত নয়',
    );
  });
}
