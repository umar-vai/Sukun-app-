import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

void main() {
  test('today lists featured task exactly once', () {
    final first = _task('first', PatientTaskStatus.pending);
    final second = _task('second', PatientTaskStatus.pending);
    final completed = _task('completed', PatientTaskStatus.completed);
    final day = PatientDay(tasks: [first, second, completed]);

    expect(day.nextTask?.id, 'first');
    expect(day.remainingTasks.map((task) => task.id), ['second', 'completed']);
    expect(
      {day.nextTask!.id, ...day.remainingTasks.map((task) => task.id)}.length,
      day.tasks.length,
    );
  });

  test('all tasks remain visible when no action is featured', () {
    final completed = _task('completed', PatientTaskStatus.completed);
    final skipped = _task('skipped', PatientTaskStatus.skipped);
    final day = PatientDay(tasks: [completed, skipped]);

    expect(day.nextTask, isNull);
    expect(day.remainingTasks.map((task) => task.id), ['completed', 'skipped']);
  });
}

PatientTask _task(String id, PatientTaskStatus status) => PatientTask(
  id: id,
  patientId: 'test-patient',
  occurrenceDate: DateTime(2026, 10, 8),
  status: status,
  action: PlanAction(
    id: 'action-$id',
    carePlanId: 'test-plan',
    type: 'recitation',
    title: 'Test $id',
    frequency: const ActionFrequency.daily(),
    startDate: DateTime(2026, 10, 8),
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: false,
  ),
);
