import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

class ReminderTaskWindow {
  const ReminderTaskWindow({required this.planId, required this.tasks});

  final String? planId;
  final List<PatientTask> tasks;
}

abstract interface class NotificationRepository {
  /// [patientId] is the selected family profile; null keeps the original
  /// single-patient behaviour.
  Future<ReminderTaskWindow> getReminderTasks({
    required int horizonDays,
    String? patientId,
  });

  /// [patientId] records which profile THIS installation currently serves.
  /// Switching profiles on one phone never touches another phone's row.
  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String pushToken,
    required String timezone,
    String? patientId,
  });

  Future<void> removeDevice(String installationId);
}

class NotificationException implements Exception {
  const NotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
