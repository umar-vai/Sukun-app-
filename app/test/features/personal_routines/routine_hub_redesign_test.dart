import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';
import 'package:sukun_life/features/personal_routines/presentation/routine_hub_parts.dart';
import 'package:sukun_life/features/personal_routines/presentation/today_routine_panel.dart';
import 'package:sukun_life/features/progress/presentation/unified_progress_screen.dart';

void main() {
  group('routine hub tab from the URL', () {
    test('no tab and ?tab=today open Today', () {
      expect(routineHubInitialTab(), RoutineHubTab.today);
      expect(routineHubInitialTab(initialTab: 'today'), RoutineHubTab.today);
    });

    test('?tab=progress opens Today, where progress now lives', () {
      expect(routineHubInitialTab(initialTab: 'progress'), RoutineHubTab.today);
    });

    test('old ?tab=assigned links land on My Routines', () {
      expect(
        routineHubInitialTab(initialTab: 'assigned'),
        RoutineHubTab.myRoutines,
      );
    });

    test('adding from the library always opens My Routines', () {
      expect(
        routineHubInitialTab(initialTab: 'progress', resourceId: 'r1'),
        RoutineHubTab.myRoutines,
      );
    });
  });

  testWidgets('hub has two tabs: Today\'s amal and My Routines', (
    tester,
  ) async {
    var selected = RoutineHubTab.today;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RoutineHubTabs(
              selected: selected,
              onSelected: (tab) => setState(() => selected = tab),
            ),
          ),
        ),
      ),
    );
    expect(RoutineHubTab.values, [
      RoutineHubTab.today,
      RoutineHubTab.myRoutines,
    ]);
    expect(find.text('আজকের আমল'), findsOneWidget);
    expect(find.text('আমার রুটিন'), findsOneWidget);
    expect(find.text('অগ্রগতি'), findsNothing);
    // Today's amal sits on the left.
    expect(
      tester.getCenter(find.text('আজকের আমল')).dx,
      lessThan(tester.getCenter(find.text('আমার রুটিন')).dx),
    );
    await tester.tap(find.byKey(const Key('routine-hub-tab-myRoutines')));
    await tester.pump();
    expect(selected, RoutineHubTab.myRoutines);
  });

  test('admin-set routines come first, active before paused', () {
    final ordered = orderRoutinesForHub(
      const [
        {'id': 'own-paused', 'is_active': false},
        {'id': 'own-1', 'is_active': true},
        {'id': 'admin-paused', 'is_active': false},
        {'id': 'admin-1', 'is_active': true},
      ],
      const {'admin-1', 'admin-paused'},
    );
    expect(ordered.assigned.map((r) => r['id']), ['admin-1', 'admin-paused']);
    expect(ordered.own.map((r) => r['id']), ['own-1', 'own-paused']);
  });

  test('streak counts back from today, or from yesterday if not yet done', () {
    final today = DateTime(2026, 11, 12);
    expect(
      routineStreakDays({'2026-11-12', '2026-11-11', '2026-11-10'}, today),
      3,
    );
    expect(routineStreakDays({'2026-11-11', '2026-11-10'}, today), 2);
    expect(routineStreakDays({'2026-11-10'}, today), 0);
    expect(routineStreakDays(const {}, today), 0);
    // Month boundary.
    expect(
      routineStreakDays({'2026-12-01', '2026-11-30'}, DateTime(2026, 12, 1)),
      2,
    );
  });

  test('schedules and outcomes read as Bangla, never raw values', () {
    expect(routineScheduleLabel({'schedule_kind': 'manual'}), 'নিজে যখন চাই');
    expect(
      routineScheduleLabel({
        'schedule_kind': 'fixed',
        'local_time': '21:15:00',
      }),
      'প্রতিদিন 21:15',
    );
    expect(
      routineScheduleLabel({
        'schedule_kind': 'fajr',
        'prayer_offset_minutes': 10,
      }),
      'ফজরের 10 মিনিট পরে',
    );
    expect(routineOutcomeLabel('done').$1, 'আজ সম্পন্ন');
    expect(routineOutcomeLabel('skipped').$1, 'আজ বাদ');
    expect(routineOutcomeLabel(null).$1, 'আজ বাকি');
  });

  test('progress dates are shown in Bangla', () {
    expect(banglaDayLabel('2026-11-09'), 'সোম, ৯ নভেম্বর');
    expect(banglaDayLabel('not-a-date'), 'not-a-date');
  });

  group('deleting asks first', () {
    Future<bool?> runConfirm(WidgetTester tester, String answer) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmRoutineDeletion(
                context,
                title: 'রাতের আমল',
                isRoutine: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('রুটিনটি মুছে ফেলবেন?'), findsOneWidget);
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('cancel keeps the routine', (tester) async {
      expect(await runConfirm(tester, 'বাতিল'), isFalse);
    });

    testWidgets('confirm allows the delete', (tester) async {
      expect(await runConfirm(tester, 'মুছে ফেলুন'), isTrue);
    });
  });

  testWidgets('routine card shows Bangla actions and forwards each choice', (
    tester,
  ) async {
    final chosen = <String>[];
    var deleteTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineCard(
            routine: const {
              'id': 'r1',
              'title': 'রাতের আমল',
              'is_active': true,
            },
            actions: const [
              {
                'id': 'a1',
                'routine_id': 'r1',
                'title': 'আয়াতুল কুরসি',
                'schedule_kind': 'manual',
                'notification_title': 'ঘুমের আগে',
              },
            ],
            outcomes: const {'a1': 'done'},
            busy: false,
            onToggleActive: () {},
            onDeleteRoutine: () => deleteTapped = true,
            onOpenAction: (_) {},
            onActionMenu: (_, value) => chosen.add(value),
            onAddAction: () {},
          ),
        ),
      ),
    );
    expect(find.text('চালু আছে'), findsOneWidget);
    expect(find.text('নিজে যখন চাই · ঘুমের আগে'), findsOneWidget);
    expect(find.text('আজ সম্পন্ন'), findsOneWidget);

    await tester.tap(find.byKey(const Key('routine-action-menu-a1')));
    await tester.pumpAndSettle();
    for (final label in ['আজ বাদ দিন', 'সম্পাদনা', 'ডুপ্লিকেট', 'মুছে ফেলুন']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('ডুপ্লিকেট'));
    await tester.pumpAndSettle();
    expect(chosen, ['duplicate']);

    await tester.tap(find.byKey(const Key('routine-menu-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('মুছে ফেলুন'));
    await tester.pumpAndSettle();
    expect(deleteTapped, isTrue);
  });

  testWidgets('patients see the care plan card first; members do not', (
    tester,
  ) async {
    var opened = false;
    Widget panel({VoidCallback? patientToday}) => MaterialApp(
      home: Scaffold(
        body: TodayRoutinePanel(
          routines: const [],
          actions: const [],
          outcomes: const {},
          onToggleDone: (_, _) {},
          onOpen: (_) {},
          onOpenPatientToday: patientToday,
        ),
      ),
    );
    await tester.pumpWidget(panel(patientToday: () => opened = true));
    expect(find.byKey(const Key('today-patient-plan-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today-patient-plan-card')));
    expect(opened, isTrue);

    await tester.pumpWidget(panel());
    expect(find.byKey(const Key('today-patient-plan-card')), findsNothing);
  });

  testWidgets('patient today page highlights the Routine tab', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PatientScaffold(title: 'আজ', selectedIndex: 3, body: SizedBox()),
      ),
    );
    final nav = tester.widget<SukunBottomNavigation>(
      find.byType(SukunBottomNavigation),
    );
    expect(nav.selectedIndex, 1);
  });
}
