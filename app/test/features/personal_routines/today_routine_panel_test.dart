import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/personal_routines/presentation/today_routine_panel.dart';

void main() {
  test('Today summary counts done, skipped and remaining correctly', () {
    final summary = TodayRoutineSummary(
      actions: [
        {'id': 'a'},
        {'id': 'b'},
        {'id': 'c'},
      ],
      outcomes: {'a': 'done', 'b': 'skipped'},
    );
    expect(summary.total, 3);
    expect(summary.completed, 1);
    expect(summary.remaining, 2);
    expect(summary.fraction, closeTo(1 / 3, 0.001));
    expect(
      TodayRoutineSummary(actions: const [], outcomes: const {}).fraction,
      0,
    );
  });

  testWidgets('Today Routine has ring and one-tap completion, hidden pauses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final marked = <String>[];
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayRoutinePanel(
            routines: const [
              {'id': 'r1', 'is_active': true},
              {'id': 'r2', 'is_active': false},
            ],
            actions: const [
              {
                'id': 'a1',
                'routine_id': 'r1',
                'is_active': true,
                'title': 'আয়াতুল কুরসি',
              },
              {
                'id': 'a2',
                'routine_id': 'r1',
                'is_active': true,
                'title': 'পানি পান',
              },
              {
                'id': 'a3',
                'routine_id': 'r2',
                'is_active': true,
                'title': 'পজ করা কাজ',
              },
            ],
            outcomes: const {'a1': 'done'},
            onToggleDone: (id, alreadyDone) => marked.add('$id:$alreadyDone'),
            onOpen: opened.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('আজকের রুটিন'), findsOneWidget);
    expect(
      find.byKey(const Key('today-routine-progress-ring')),
      findsOneWidget,
    );
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('১ টি সম্পন্ন'), findsNothing);
    expect(find.text('1 টি সম্পন্ন'), findsOneWidget);
    expect(find.text('1 টি বাকি'), findsOneWidget);
    expect(find.text('পজ করা কাজ'), findsNothing);
    await tester.tap(find.byKey(const Key('today-toggle-a2')));
    expect(marked, ['a2:false']);
    await tester.tap(find.text('আয়াতুল কুরসি'));
    expect(opened, ['a1']);
    expect(tester.takeException(), isNull);
  });
}
