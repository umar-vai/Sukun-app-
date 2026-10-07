import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

class CreateCarePlanInput {
  const CreateCarePlanInput({
    required this.patientId,
    required this.name,
    required this.startDate,
    required this.requestId,
    this.endDate,
    this.prescriptionId,
    this.copyFromPlanId,
  });

  final String patientId;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final String? prescriptionId;
  final String? copyFromPlanId;
  final String requestId;
}

class SavePlanActionInput {
  const SavePlanActionInput({
    required this.carePlanId,
    required this.type,
    required this.title,
    required this.frequency,
    required this.startDate,
    required this.reviewStatus,
    required this.reminderEnabled,
    required this.requestId,
    this.actionId,
    this.instruction,
    this.countTarget,
    this.durationMinutes,
    this.timeWindow,
    this.exactTime,
    this.endDate,
    this.contentItemId,
    this.resourceUsageNote,
    this.aiRequestId,
    this.attachmentId,
    this.sourceEvidence,
    this.aiConfidence,
    this.aiAmbiguities = const [],
    this.humanEdited = false,
  });

  final String carePlanId;
  final String? actionId;
  final String type;
  final String title;
  final String? instruction;
  final int? countTarget;
  final int? durationMinutes;
  final ActionFrequency frequency;
  final String? timeWindow;
  final DateTime? exactTime;
  final DateTime startDate;
  final DateTime? endDate;
  final ActionReviewStatus reviewStatus;
  final bool reminderEnabled;
  final String? contentItemId;
  final String? resourceUsageNote;
  final String requestId;
  final String? aiRequestId;
  final String? attachmentId;
  final String? sourceEvidence;
  final double? aiConfidence;
  final List<String> aiAmbiguities;
  final bool humanEdited;

  bool get isAiSuggestion =>
      aiRequestId != null && sourceEvidence?.trim().isNotEmpty == true;
}

String? validatePlanName(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 2 || length > 160) {
    return 'Enter a plan name between 2 and 160 characters.';
  }
  return null;
}

String? validateActionRequired(String? value, String label) {
  if (value?.trim().isEmpty ?? true) return '$label is required.';
  return null;
}

String? validateOptionalPositiveInteger(String? value, String label) {
  if (value?.trim().isEmpty ?? true) return null;
  final parsed = int.tryParse(value!.trim());
  if (parsed == null || parsed <= 0) return '$label must be a positive number.';
  return null;
}
