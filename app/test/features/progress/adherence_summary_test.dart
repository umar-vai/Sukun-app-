import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/progress/domain/adherence_summary.dart';

void main() {
  test(
    'aggregates a complete date range without treating cancelled tasks as care',
    () {
      final summary = AdherenceSummary.fromTasks(
        throughDate: DateTime(2026, 10, 3),
        dayCount: 3,
        tasks: [
          TrackedTaskStatus(
            date: DateTime(2026, 10, 1),
            status: PatientTaskStatus.completed,
          ),
          TrackedTaskStatus(
            date: DateTime(2026, 10, 1),
            status: PatientTaskStatus.skipped,
          ),
          TrackedTaskStatus(
            date: DateTime(2026, 10, 2),
            status: PatientTaskStatus.cancelled,
          ),
          TrackedTaskStatus(
            date: DateTime(2026, 10, 3),
            status: PatientTaskStatus.snoozed,
          ),
        ],
      );

      expect(summary.days, hasLength(3));
      expect(summary.total, 3);
      expect(summary.completed, 1);
      expect(summary.skipped, 1);
      expect(summary.remaining, 1);
      expect(summary.completionRate, closeTo(1 / 3, 0.001));
      expect(summary.days[1].total, 0);
    },
  );
}
