import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/data/completion_queue_store.dart';
import 'package:sukun_life/features/patient_care/data/supabase_patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/data/task_completion_coordinator.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final patientCareRepositoryProvider = Provider<PatientCareRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailablePatientCareRepository();
  }
  final client = Supabase.instance.client;
  return SupabasePatientCareRepository(
    client,
    TaskCompletionCoordinator(
      store: SecureCompletionQueueStore(),
      remote: SupabaseTaskCompletionRemote(client),
    ),
  );
});

final class UnavailablePatientCareRepository implements PatientCareRepository {
  const UnavailablePatientCareRepository();

  Never _unavailable() => throw const PatientCareException(
    'Connect Supabase to open patient care.',
  );

  @override
  Future<CarePlan?> getActivePlan() async => _unavailable();

  @override
  Future<List<PlanAction>> getActivePlanActions(String planId) async =>
      _unavailable();

  @override
  Future<PatientDay> getToday() async => _unavailable();

  @override
  Future<List<Prescription>> getVisiblePrescriptions() async => _unavailable();

  @override
  Future<PatientTask> recordTask({
    required PatientTask task,
    required PatientTaskStatus status,
    required String clientEventId,
    DateTime? snoozedUntil,
    String? skipReason,
  }) async => _unavailable();
}
