import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';

abstract interface class AiActionsRepository {
  Future<AiActionGenerationResult> generateActions({
    required String prescriptionId,
    required String carePlanId,
    required String requestId,
  });
}

class AiActionGenerationException implements Exception {
  const AiActionGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
