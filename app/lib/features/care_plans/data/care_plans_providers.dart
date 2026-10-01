import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/data/supabase_care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final carePlansRepositoryProvider = Provider<CarePlansRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableCarePlansRepository();
  }
  return SupabaseCarePlansRepository(Supabase.instance.client);
});

final class UnavailableCarePlansRepository implements CarePlansRepository {
  const UnavailableCarePlansRepository();

  Never _unavailable() => throw const CarePlanWorkflowException(
    'Connect Supabase to use care-plan management.',
  );

  @override
  Future<CarePlan> archivePlan(String planId, String requestId) async =>
      _unavailable();

  @override
  Future<CarePlan> createDraft(CreateCarePlanInput input) async =>
      _unavailable();

  @override
  Future<List<PlanAction>> getActions(String planId) async => _unavailable();

  @override
  Future<List<ContentResourceOption>> getAvailableResources() async =>
      _unavailable();

  @override
  Future<List<CarePlan>> getPatientPlans(String patientId) async =>
      _unavailable();

  @override
  Future<CarePlan?> getPlan(String planId) async => _unavailable();

  @override
  Future<CarePlan> publishPlan(String planId, String requestId) async =>
      _unavailable();

  @override
  Future<void> rejectAction(String actionId, String requestId) async =>
      _unavailable();

  @override
  Future<List<PlanAction>> reorderActions(
    String planId,
    List<String> actionIds,
    String requestId,
  ) async => _unavailable();

  @override
  Future<PlanAction> saveAction(SavePlanActionInput input) async =>
      _unavailable();
}
