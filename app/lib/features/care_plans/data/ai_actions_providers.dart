import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/care_plans/data/ai_actions_repository.dart';
import 'package:sukun_life/features/care_plans/data/supabase_ai_actions_repository.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final aiActionsRepositoryProvider = Provider<AiActionsRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableAiActionsRepository();
  }
  return SupabaseAiActionsRepository(Supabase.instance.client);
});

final class UnavailableAiActionsRepository implements AiActionsRepository {
  const UnavailableAiActionsRepository();

  @override
  Future<AiActionGenerationResult> generateActions({
    required String prescriptionId,
    required String carePlanId,
    required String requestId,
  }) async => throw const AiActionGenerationException(aiManualFallbackMessage);
}
