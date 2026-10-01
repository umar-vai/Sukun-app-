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

  Future<List<PlanAction>> reorderActions(
    String planId,
    List<String> actionIds,
    String requestId,
  );

  Future<void> rejectAction(String actionId, String requestId);

  Future<CarePlan> publishPlan(String planId, String requestId);

  Future<CarePlan> archivePlan(String planId, String requestId);
}

class CarePlanWorkflowException implements Exception {
  const CarePlanWorkflowException(this.message);

  final String message;

  @override
  String toString() => message;
}
