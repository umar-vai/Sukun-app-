import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/presentation/live_reminders_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Future<bool> Function(String id, bool enabled) onToggle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LiveRemindersCard(
              load: () async => [
                const LiveReminder(
                  id: 'evening',
                  title: 'Evening amal',
                  enabled: true,
                  time: ReminderClock(17, 30),
                  notificationTitle: 'সন্ধ্যার আমল',
                ),
                const LiveReminder(
                  id: 'untimed',
                  title: 'Untimed',
                  enabled: false,
                  canSwitchOn: false,
                ),
                const LiveReminder(
                  id: 'morning',
                  title: 'Morning water',
                  enabled: true,
                  time: ReminderClock(7, 30),
                ),
              ],
              onToggle: onToggle,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String id) =>
      tester.widget<SwitchListTile>(find.byKey(Key('live-reminder-$id'))).value;

  testWidgets('lists by time, shows the name and saves a switch at once', (
    tester,
  ) async {
    final calls = <(String, bool)>[];
    await pump(
      tester,
      onToggle: (id, enabled) async {
        calls.add((id, enabled));
        return enabled;
      },
    );
    final morning = tester.getTopLeft(find.text('Morning water')).dy;
    final evening = tester.getTopLeft(find.text('Evening amal')).dy;
    expect(morning, lessThan(evening));
    expect(find.textContaining('নোটিফিকেশন: সন্ধ্যার আমল'), findsOneWidget);
    // No approved time: it cannot be switched on.
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('live-reminder-untimed')),
          )
          .onChanged,
      isNull,
    );

    await tester.tap(find.byKey(const Key('live-reminder-evening')));
    await tester.pumpAndSettle();
    expect(calls, [('evening', false)]);
    expect(switchValue(tester, 'evening'), isFalse);
    expect(find.textContaining('বন্ধ হয়েছে'), findsOneWidget);
  });

  testWidgets('a failed save flips the switch back', (tester) async {
    await pump(tester, onToggle: (_, _) async => throw Exception('offline'));
    await tester.tap(find.byKey(const Key('live-reminder-morning')));
    await tester.pumpAndSettle();
    expect(switchValue(tester, 'morning'), isTrue);
    expect(find.textContaining('বদলানো যায়নি'), findsOneWidget);
  });

  test('routine rows need an id and read the saved time', () {
    expect(LiveReminder.fromRoutineAction({'title': 'x'}), isNull);
    final row = LiveReminder.fromRoutineAction({
      'id': 'a1',
      'title': 'Water',
      'is_active': false,
      'local_time': '07:30:00',
      'notification_title': 'পানি',
    })!;
    expect(row.enabled, isFalse);
    expect(row.time, const ReminderClock(7, 30));
    expect(row.notificationTitle, 'পানি');
  });
}
