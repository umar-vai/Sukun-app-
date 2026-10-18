import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

abstract interface class CarePlansRepository {
  Future<List<CarePlan>> getPatientPlans(String patientId);

  Future<CarePlan?> getPlan(String planId);

  Future<List<PlanAction>> getActions(String planId);

  Future<List<ContentResourceOption>> getAvailableResources();

  Future<CarePlan> createDraft(CreateCarePlanInput input);

  Future<PlanAction> saveAction(SavePlanActionInput input);

  /// Atomically sets all published, patient-accessible resource links on a
  /// draft action. Requires database-verified Super Admin and audit.
  Future<void> replaceActionResources({
    required String actionId,
    required List<String> resourceIds,
    required String requestId,
  });

  /// Link canonical public Quran chapters without copying verse text.
  Future<void> replaceActionQuranSurahs({
    required String actionId,
    required List<ContentResourceOption> surahs,
    required String requestId,
  });

  Future<List<PlanAction>> reorderActions(
    String planId,
    List<String> actionIds,
    String requestId,
  );

  Future<void> rejectAction(String actionId, String requestId);

  Future<CarePlan> publishPlan(String planId, String requestId);

  Future<CarePlan> archivePlan(String planId, String requestId);

  /// Explicitly retire an empty draft blocking a new prescription import.
  /// The backend rechecks draft status, ownership and absence of work atomically.
  Future<void> archiveEmptyDraftForPrescriptionImport({
    required String patientId,
    required String planId,
    required String requestId,
  });
}

class CarePlanWorkflowException implements Exception {
  const CarePlanWorkflowException(this.message);

  final String message;

  @override
  String toString() => message;
}
