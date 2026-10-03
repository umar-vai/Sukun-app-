import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

class ReminderTaskWindow {
  const ReminderTaskWindow({required this.planId, required this.tasks});

  final String? planId;
  final List<PatientTask> tasks;
}

abstract interface class NotificationRepository {
  Future<ReminderTaskWindow> getReminderTasks({required int horizonDays});

  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String pushToken,
    required String timezone,
  });

  Future<void> removeDevice(String installationId);
}

class NotificationException implements Exception {
  const NotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
