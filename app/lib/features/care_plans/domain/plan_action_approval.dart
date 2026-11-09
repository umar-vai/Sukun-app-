import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:uuid/uuid.dart';

/// Builds the exact save input the action editor would send for [action]
/// with only the review status changed. Mirrors the editor's resource rules:
/// the primary CMS resource is the one with a usage note, else the first
/// non-Qur'an resource.
SavePlanActionInput approvalInputFor(
  PlanAction action, {
  required String requestId,
  ActionReviewStatus reviewStatus = ActionReviewStatus.approved,
}) {
  final cms = action.linkedResources
      .where((resource) => !resource.id.startsWith('quran:'))
      .toList(growable: false);
  final noted = action.linkedResources
      .where((resource) => resource.usageNote?.isNotEmpty == true)
      .firstOrNull;
  return SavePlanActionInput(
    carePlanId: action.carePlanId,
    actionId: action.id,
    type: action.type,
    title: action.title,
    instruction: action.instruction,
    countTarget: action.countTarget,
    durationMinutes: action.durationMinutes,
    frequency: action.frequency,
    timeWindow: action.timeWindow,
    exactTime: action.exactTime,
    startDate: action.startDate,
    endDate: action.endDate,
    reviewStatus: reviewStatus,
    reminderEnabled: action.reminderEnabled,
    contentItemId: noted?.id ?? cms.firstOrNull?.id,
    resourceUsageNote: noted?.usageNote,
    requestId: requestId,
  );
}

/// One-tap approval from the plan builder. Uses the same repository calls
/// as the action editor so linked resources survive: saving an action keeps
/// only one CMS link, so additional links are restored afterwards exactly as
/// the editor does. Qur'an surah links live in a separate table and are not
/// touched by the save.
Future<PlanAction> approvePlanAction(
  CarePlansRepository repository,
  PlanAction action,
) async {
  const uuid = Uuid();
  final saved = await repository.saveAction(
    approvalInputFor(action, requestId: uuid.v4()),
  );
  final cmsIds = action.linkedResources
      .where((resource) => !resource.id.startsWith('quran:'))
      .map((resource) => resource.id)
      .toList(growable: false);
  if (cmsIds.length > 1) {
    await repository.replaceActionResources(
      actionId: saved.id,
      resourceIds: cmsIds,
      requestId: uuid.v4(),
    );
  }
  return saved;
}
