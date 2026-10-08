import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_home_screen.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

void main() {
  test('patient day reports completion and next actionable task', () {
    final repository = _FakePatientCareRepository();
    final day = PatientDay(
      activePlan: repository.plan,
      tasks: [repository.completedTask, repository.pendingTask],
    );

    expect(day.completedCount, 1);
    expect(day.completionRatio, 0.5);
    expect(day.nextTask?.id, repository.pendingTask.id);
  });

  testWidgets('patient can mark a task done from Today', (tester) async {
    final repository = _FakePatientCareRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientCareRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: PatientHomeScreen(displayName: 'Rahim')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning action'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'করেছি').first);
    await tester.pumpAndSettle();

    expect(repository.recordedStatus, PatientTaskStatus.completed);
    expect(find.text('1টির মধ্যে 1টি করেছেন'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final class _FakePatientCareRepository implements PatientCareRepository {
  final plan = CarePlan(
    id: 'plan-1',
    patientId: 'patient-1',
    version: 1,
    name: 'Active care plan',
    startDate: DateTime(2026, 10, 2),
    status: CarePlanStatus.active,
    createdAt: DateTime(2026, 10, 2),
  );

  late final action = PlanAction(
    id: 'action-1',
    carePlanId: plan.id,
    type: 'recitation',
    title: 'Morning action',
    frequency: const ActionFrequency.daily(),
    startDate: plan.startDate,
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: false,
    timeWindow: 'morning',
  );

  late PatientTask pendingTask = PatientTask(
    id: 'task-1',
    patientId: 'patient-1',
    occurrenceDate: DateTime(2026, 10, 2),
    status: PatientTaskStatus.pending,
    action: action,
  );

  late final completedTask = PatientTask(
    id: 'task-complete',
    patientId: 'patient-1',
    occurrenceDate: DateTime(2026, 10, 2),
    status: PatientTaskStatus.completed,
    action: action,
  );

  PatientTaskStatus? recordedStatus;

  @override
  Future<PatientDay> getToday() async =>
      PatientDay(activePlan: plan, tasks: [pendingTask]);

  @override
  Future<PatientTask> recordTask({
    required PatientTask task,
    required PatientTaskStatus status,
    required String clientEventId,
    DateTime? snoozedUntil,
    String? skipReason,
  }) async {
    recordedStatus = status;
    pendingTask = PatientTask(
      id: task.id,
      patientId: task.patientId,
      occurrenceDate: task.occurrenceDate,
      status: status,
      action: action,
      snoozedUntil: snoozedUntil,
    );
    return pendingTask;
  }

  @override
  Future<CarePlan?> getActivePlan() async => plan;

  @override
  Future<List<PlanAction>> getActivePlanActions(String planId) async => [
    action,
  ];

  @override
  Future<List<Prescription>> getVisiblePrescriptions() async => [];
}
