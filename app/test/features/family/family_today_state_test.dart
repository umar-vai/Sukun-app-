import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/features/family/presentation/profile_scope.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_home_screen.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

import 'family_test_support.dart';

/// In-memory backend: every profile has its own plan and its own task state.
/// The repository answers for whichever profile the device has selected,
/// exactly like the Supabase one filters by `patient_id`.
final class _PerProfileCareRepository implements PatientCareRepository {
  _PerProfileCareRepository(this._activeId, this._tasksByPatient);

  final ActivePatientIdReader _activeId;
  final Map<String, List<PatientTask>> _tasksByPatient;

  @override
  Future<PatientDay> getToday() async {
    final id = (await _activeId())!;
    return PatientDay(
      activePlan: CarePlan(
        id: 'plan-$id',
        patientId: id,
        version: 1,
        name: 'Plan $id',
        startDate: DateTime(2026, 11, 1),
        status: CarePlanStatus.active,
        createdAt: DateTime(2026, 11, 1),
      ),
      tasks: List.of(_tasksByPatient[id]!),
    );
  }

  @override
  Future<PatientTask> recordTask({
    required PatientTask task,
    required PatientTaskStatus status,
    required String clientEventId,
    DateTime? snoozedUntil,
    String? skipReason,
  }) async {
    final list = _tasksByPatient[task.patientId]!;
    final updated = task.copyWith(status: status, completedAt: DateTime.now());
    final index = list.indexWhere((t) => t.id == task.id);
    list[index] = updated;
    return updated;
  }

  @override
  Future<CarePlan?> getActivePlan() async => (await getToday()).activePlan;

  @override
  Future<List<PlanAction>> getActivePlanActions(String planId) async => [];

  @override
  Future<List<Prescription>> getVisiblePrescriptions() async => [];
}

List<PatientTask> _tasks(String patientId, int total, int done) => [
  for (var i = 0; i < total; i++)
    PatientTask(
      id: '$patientId-task-$i',
      patientId: patientId,
      occurrenceDate: DateTime(2026, 11, 20),
      status: i < done
          ? PatientTaskStatus.completed
          : PatientTaskStatus.pending,
      action: PlanAction(
        id: '$patientId-action-$i',
        carePlanId: 'plan-$patientId',
        type: 'recitation',
        title: 'Action $i of $patientId',
        frequency: const ActionFrequency.daily(),
        startDate: DateTime(2026, 11, 1),
        sortOrder: i,
        reviewStatus: ActionReviewStatus.approved,
        reminderEnabled: false,
      ),
    ),
];

void main() {
  testWidgets(
    'each profile keeps independent completion state: 6/10 then 3/8',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = {
        'p-owner': _tasks('p-owner', 10, 6),
        'p-spouse': _tasks('p-spouse', 8, 3),
      };
      final profiles = [
        profile('p-owner', 'Rahim Uddin', primary: true),
        profile('p-spouse', 'Amina Rahim', relationship: 'স্ত্রী', order: 1),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...familyOverrides(profiles),
            patientCareRepositoryProvider.overrideWith(
              (ref) => _PerProfileCareRepository(
                ref.watch(activePatientIdReaderProvider),
                backend,
              ),
            ),
          ],
          child: const MaterialApp(
            home: ProfileScoped(child: PatientHomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PatientHomeScreen)),
      );

      // Owner: 6 of 10.
      expect(find.text('১০টির মধ্যে ৬টি করেছেন'), findsWidgets);
      expect(find.text('৮টির মধ্যে ৩টি করেছেন'), findsNothing);

      // Switch to the spouse: the owner's numbers must be gone.
      await container.read(activeProfileProvider.notifier).select('p-spouse');
      await tester.pumpAndSettle();
      expect(find.text('৮টির মধ্যে ৩টি করেছেন'), findsWidgets);
      expect(find.text('১০টির মধ্যে ৬টি করেছেন'), findsNothing);

      // Completing a task as the spouse changes only the spouse: 4 of 8.
      await tester.tap(find.widgetWithText(FilledButton, 'করেছি').first);
      await tester.pumpAndSettle();
      expect(find.text('৮টির মধ্যে ৪টি করেছেন'), findsWidgets);

      // Back to the owner: still exactly 6 of 10, untouched.
      await container.read(activeProfileProvider.notifier).select('p-owner');
      await tester.pumpAndSettle();
      expect(find.text('১০টির মধ্যে ৬টি করেছেন'), findsWidgets);
      expect(find.text('৮টির মধ্যে ৪টি করেছেন'), findsNothing);
      expect(
        backend['p-owner']!.where(
          (t) => t.status == PatientTaskStatus.completed,
        ),
        hasLength(6),
      );
    },
  );
}
