import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

class ReminderSchedule {
  const ReminderSchedule({
    required this.notificationId,
    required this.taskId,
    required this.actionId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  final int notificationId;
  final String taskId;
  final String actionId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
}

List<ReminderSchedule> planCareReminders({
  required Iterable<PatientTask> tasks,
  required DateTime now,
  int maximumPending = 48,
}) {
  final reminders = <ReminderSchedule>[];
  for (final task in tasks) {
    final action = task.action;
    if (!task.status.canUpdate ||
        action.reviewStatus != ActionReviewStatus.approved ||
        !action.reminderEnabled ||
        action.exactTime == null ||
        task.scheduledAt == null) {
      continue;
    }

    final scheduledAt =
        task.status == PatientTaskStatus.snoozed && task.snoozedUntil != null
        ? task.snoozedUntil!
        : _patientLocalExactTime(task);
    if (!scheduledAt.isAfter(now)) continue;

    reminders.add(
      ReminderSchedule(
        notificationId: stableNotificationId('care:${task.id}'),
        taskId: task.id,
        actionId: action.id,
        title: 'সুকুন লাইফ',
        body: 'আপনার নির্ধারিত কাজের সময় হয়েছে।',
        scheduledAt: scheduledAt,
        payload: 'care_task:${task.id}',
      ),
    );
  }

  reminders.sort(
    (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
  );
  return List.unmodifiable(reminders.take(maximumPending));
}

ReminderSchedule planSnoozeReminder({
  required PatientTask task,
  required DateTime snoozedUntil,
}) => ReminderSchedule(
  notificationId: stableNotificationId('care:${task.id}'),
  taskId: task.id,
  actionId: task.action.id,
  title: 'সুকুন লাইফ',
  body: 'পরে করার জন্য রাখা কাজটির সময় হয়েছে।',
  scheduledAt: snoozedUntil,
  payload: 'care_task:${task.id}',
);

DateTime _patientLocalExactTime(PatientTask task) {
  final exactTime = task.action.exactTime!;
  return DateTime(
    task.occurrenceDate.year,
    task.occurrenceDate.month,
    task.occurrenceDate.day,
    exactTime.hour,
    exactTime.minute,
  );
}

int stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final byte in value.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
