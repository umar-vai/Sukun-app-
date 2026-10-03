import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_progress_screen.dart';
import 'package:sukun_life/features/progress/data/progress_providers.dart';
import 'package:sukun_life/features/progress/data/progress_repository.dart';
import 'package:sukun_life/features/progress/domain/adherence_summary.dart';

void main() {
  testWidgets(
    'patient progress renders tracked completion without clinical claims',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressRepositoryProvider.overrideWithValue(
              const _FakeProgressRepository(),
            ),
          ],
          child: const MaterialApp(home: PatientProgressScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('50% completed'), findsOneWidget);
      expect(find.text('1  Done'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('not a clinical assessment'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('not a clinical assessment'), findsOneWidget);
    },
  );
}

final class _FakeProgressRepository implements ProgressRepository {
  const _FakeProgressRepository();

  AdherenceSummary _summary(int days) => AdherenceSummary.fromTasks(
    tasks: [
      TrackedTaskStatus(
        date: DateTime.now(),
        status: PatientTaskStatus.completed,
      ),
      TrackedTaskStatus(
        date: DateTime.now(),
        status: PatientTaskStatus.pending,
      ),
    ],
    throughDate: DateTime.now(),
    dayCount: days,
  );

  @override
  Future<AdherenceSummary> getMyProgress({int days = 7}) async =>
      _summary(days);

  @override
  Future<AdherenceSummary> getPatientProgress(
    String patientId, {
    int days = 7,
  }) async => _summary(days);
}
