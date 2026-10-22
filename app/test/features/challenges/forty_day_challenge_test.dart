import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/challenges/data/forty_day_challenge_repository.dart';

void main() {
  final start = DateTime(2026, 10, 23);

  test('five canonical stages cover all forty days without overlap', () {
    expect(fortyDayStages.length, 5);
    final all = <int>{};
    for (final stage in fortyDayStages) {
      for (var day = stage.firstDay; day <= stage.lastDay; day++) {
        expect(all.add(day), isTrue);
      }
    }
    expect(all, {for (var day = 1; day <= 40; day++) day});
    expect(fortyDayStages.map((stage) => stage.title), [
      'প্রস্তুতি',
      'নজরের আমল',
      'বরই পাতার আমল',
      'আশফিয়া ডিটক্স',
      'জাদুর ডিটক্স',
    ]);
  });

  test('missed days do not delete prior progress or reset day clock', () {
    final progress = ChallengeProgress(
      startedOn: start,
      pausedDays: 0,
      pausedOn: null,
      completedDays: {1, 3, 7},
    );
    expect(progress.dayAt(DateTime(2026, 10, 27)), 5);
    expect(progress.completedDays, {1, 3, 7});
    expect(progress.stageAt(DateTime(2026, 11, 3)).title, 'নজরের আমল');
    expect(progress.complete, isFalse);
  });

  test('pause freezes day and resume accounts for paused days', () {
    final paused = ChallengeProgress(
      startedOn: start,
      pausedDays: 0,
      pausedOn: DateTime(2026, 10, 25),
      completedDays: {1, 2},
    );
    expect(paused.isPaused, isTrue);
    expect(paused.dayAt(DateTime(2026, 11, 10)), 3);
    final resumed = ChallengeProgress(
      startedOn: start,
      pausedDays: 7,
      pausedOn: null,
      completedDays: {1, 2},
    );
    expect(resumed.dayAt(DateTime(2026, 11, 2)), 4);
  });

  test('day counter clamps at 40; all days completed is independent', () {
    final progress = ChallengeProgress(
      startedOn: start,
      pausedDays: 0,
      pausedOn: null,
      completedDays: {},
    );
    expect(progress.dayAt(DateTime(2027, 4, 2)), 40);
    expect(progress.complete, isFalse);
    final completed = ChallengeProgress(
      startedOn: start,
      pausedDays: 0,
      pausedOn: null,
      completedDays: {for (var day = 1; day <= 40; day++) day},
    );
    expect(completed.complete, isTrue);
  });
}
