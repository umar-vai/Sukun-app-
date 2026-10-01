import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

abstract interface class PatientCareRepository {
  Future<PatientDay> getToday();

  Future<CarePlan?> getActivePlan();

  Future<List<PlanAction>> getActivePlanActions(String planId);

  Future<List<Prescription>> getVisiblePrescriptions();

  Future<PatientTask> recordTask({
    required String taskId,
    required PatientTaskStatus status,
    required String clientEventId,
    DateTime? snoozedUntil,
    String? skipReason,
  });
}

class PatientCareException implements Exception {
  const PatientCareException(this.message);

  final String message;

  @override
  String toString() => message;
}
