import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

enum PatientTaskStatus {
  pending,
  completed,
  snoozed,
  skipped,
  missed,
  cancelled;

  static PatientTaskStatus fromDatabase(String? value) {
    return PatientTaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PatientTaskStatus.pending,
    );
  }

  String get label => switch (this) {
    PatientTaskStatus.pending => 'Pending',
    PatientTaskStatus.completed => 'Done',
    PatientTaskStatus.snoozed => 'Snoozed',
    PatientTaskStatus.skipped => 'Skipped',
    PatientTaskStatus.missed => 'Missed',
    PatientTaskStatus.cancelled => 'Cancelled',
  };

  bool get canUpdate =>
      this == PatientTaskStatus.pending || this == PatientTaskStatus.snoozed;
}

class PatientTask {
  const PatientTask({
    required this.id,
    required this.patientId,
    required this.occurrenceDate,
    required this.status,
    required this.action,
    this.scheduledAt,
    this.completedAt,
    this.snoozedUntil,
    this.skipReason,
    this.isPendingSync = false,
  });

  factory PatientTask.fromJson(Map<String, dynamic> json) {
    return PatientTask(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      occurrenceDate: DateTime.parse(json['occurrence_date'] as String),
      scheduledAt: _date(json['scheduled_at']),
      status: PatientTaskStatus.fromDatabase(json['status'] as String?),
      completedAt: _date(json['completed_at']),
      snoozedUntil: _date(json['snoozed_until']),
      skipReason: json['skip_reason'] as String?,
      action: PlanAction.fromJson(
        Map<String, dynamic>.from(json['plan_actions'] as Map),
      ),
    );
  }

  final String id;
  final String patientId;
  final DateTime occurrenceDate;
  final DateTime? scheduledAt;
  final PatientTaskStatus status;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;
  final String? skipReason;
  final PlanAction action;
  final bool isPendingSync;

  PatientTask copyWith({
    PatientTaskStatus? status,
    DateTime? completedAt,
    DateTime? snoozedUntil,
    String? skipReason,
    bool? isPendingSync,
    bool clearCompletedAt = false,
    bool clearSnoozedUntil = false,
    bool clearSkipReason = false,
  }) {
    return PatientTask(
      id: id,
      patientId: patientId,
      occurrenceDate: occurrenceDate,
      scheduledAt: scheduledAt,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      snoozedUntil: clearSnoozedUntil
          ? null
          : snoozedUntil ?? this.snoozedUntil,
      skipReason: clearSkipReason ? null : skipReason ?? this.skipReason,
      action: action,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
