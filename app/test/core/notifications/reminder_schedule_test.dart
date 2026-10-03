import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

void main() {
  final now = DateTime(2026, 10, 2, 8);

  test('schedules only approved reminder actions with an exact time', () {
    final tasks = [
      _task(id: 'approved', exactTime: DateTime(2000, 1, 1, 9)),
      _task(id: 'no-time'),
      _task(
        id: 'needs-review',
        exactTime: DateTime(2000, 1, 1, 10),
        reviewStatus: ActionReviewStatus.needsReview,
      ),
      _task(
        id: 'disabled',
        exactTime: DateTime(2000, 1, 1, 11),
        reminderEnabled: false,
      ),
    ];

    final reminders = planCareReminders(tasks: tasks, now: now);

    expect(reminders, hasLength(1));
    expect(reminders.single.taskId, 'approved');
    expect(reminders.single.scheduledAt, DateTime(2026, 10, 2, 9));
  });

  test('uses the explicit patient-selected snooze time', () {
    final snoozedUntil = DateTime(2026, 10, 2, 12, 15);
    final task = _task(
      id: 'snoozed',
      exactTime: DateTime(2000, 1, 1, 9),
      status: PatientTaskStatus.snoozed,
      snoozedUntil: snoozedUntil,
    );

    final reminder = planCareReminders(tasks: [task], now: now).single;

    expect(reminder.scheduledAt, snoozedUntil);
  });

  test('caps pending reminders to preserve iOS scheduling headroom', () {
    final tasks = List.generate(
      60,
      (index) => _task(
        id: 'task-$index',
        occurrenceDate: DateTime(2026, 10, 3 + index),
        exactTime: DateTime(2000, 1, 1, 9),
      ),
    );

    expect(planCareReminders(tasks: tasks, now: now), hasLength(48));
  });
}

PatientTask _task({
  required String id,
  DateTime? exactTime,
  DateTime? occurrenceDate,
  ActionReviewStatus reviewStatus = ActionReviewStatus.approved,
  bool reminderEnabled = true,
  PatientTaskStatus status = PatientTaskStatus.pending,
  DateTime? snoozedUntil,
}) {
  final date = occurrenceDate ?? DateTime(2026, 10, 2);
  return PatientTask(
    id: id,
    patientId: 'patient-id',
    occurrenceDate: date,
    scheduledAt: exactTime == null
        ? null
        : DateTime(date.year, date.month, date.day, exactTime.hour),
    status: status,
    snoozedUntil: snoozedUntil,
    action: PlanAction(
      id: 'action-$id',
      carePlanId: 'plan-id',
      type: 'recitation',
      title: 'Approved care action',
      frequency: const ActionFrequency.daily(),
      startDate: date,
      sortOrder: 0,
      reviewStatus: reviewStatus,
      reminderEnabled: reminderEnabled,
      exactTime: exactTime,
    ),
  );
}
