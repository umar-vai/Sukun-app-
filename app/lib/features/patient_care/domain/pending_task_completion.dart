import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

class PendingTaskCompletion {
  const PendingTaskCompletion({
    required this.userId,
    required this.taskId,
    required this.status,
    required this.clientEventId,
    required this.occurredAt,
    this.snoozedUntil,
    this.skipReason,
  });

  factory PendingTaskCompletion.fromJson(Map<String, dynamic> json) {
    return PendingTaskCompletion(
      userId: json['user_id'] as String,
      taskId: json['task_id'] as String,
      status: PatientTaskStatus.fromDatabase(json['status'] as String?),
      clientEventId: json['client_event_id'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      snoozedUntil: _date(json['snoozed_until']),
      skipReason: json['skip_reason'] as String?,
    );
  }

  final String userId;
  final String taskId;
  final PatientTaskStatus status;
  final String clientEventId;
  final DateTime occurredAt;
  final DateTime? snoozedUntil;
  final String? skipReason;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'task_id': taskId,
    'status': status.name,
    'client_event_id': clientEventId,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'snoozed_until': snoozedUntil?.toUtc().toIso8601String(),
    'skip_reason': skipReason,
  };

  PatientTask applyTo(PatientTask task, {required bool pendingSync}) {
    return switch (status) {
      PatientTaskStatus.completed => task.copyWith(
        status: status,
        completedAt: occurredAt,
        clearSnoozedUntil: true,
        clearSkipReason: true,
        isPendingSync: pendingSync,
      ),
      PatientTaskStatus.snoozed => task.copyWith(
        status: status,
        snoozedUntil: snoozedUntil,
        clearCompletedAt: true,
        clearSkipReason: true,
        isPendingSync: pendingSync,
      ),
      PatientTaskStatus.skipped => task.copyWith(
        status: status,
        skipReason: skipReason,
        clearCompletedAt: true,
        clearSnoozedUntil: true,
        isPendingSync: pendingSync,
      ),
      _ => task,
    };
  }
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
