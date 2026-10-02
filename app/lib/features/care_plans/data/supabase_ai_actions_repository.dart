import 'package:sukun_life/features/care_plans/data/ai_actions_repository.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAiActionsRepository implements AiActionsRepository {
  SupabaseAiActionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AiActionGenerationResult> generateActions({
    required String prescriptionId,
    required String carePlanId,
    required String requestId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'prescription-to-actions',
        body: {
          'prescription_id': prescriptionId,
          'care_plan_id': carePlanId,
          'request_id': requestId,
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const AiActionSchemaException('Invalid response.');
      }
      return AiActionGenerationResult.fromJson(
        Map<String, dynamic>.from(data),
        expectedRequestId: requestId,
      );
    } on FunctionException catch (error) {
      throw AiActionGenerationException(safeAiGenerationError(error.status));
    } on AiActionSchemaException {
      throw const AiActionGenerationException(aiManualFallbackMessage);
    } catch (_) {
      throw const AiActionGenerationException(aiManualFallbackMessage);
    }
  }
}

String safeAiGenerationError(int status) => switch (status) {
  401 => 'Please sign in again before generating actions.',
  403 => 'Super Admin access is required to generate actions.',
  400 => 'Use a draft care plan linked to the selected prescription.',
  404 => 'The source prescription could not be found.',
  409 => 'Action generation is already in progress. Please try again shortly.',
  _ => aiManualFallbackMessage,
};
