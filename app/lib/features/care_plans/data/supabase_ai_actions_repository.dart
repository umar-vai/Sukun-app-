import 'package:sukun_life/features/care_plans/data/ai_actions_repository.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAiActionsRepository implements AiActionsRepository {
  SupabaseAiActionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AiActionReviewSeed?> loadStoredActions({
    required String prescriptionId,
    required String carePlanId,
  }) async {
    try {
      final row = await _client
          .from('prescription_attachments')
          .select('id,normalized_result,processed_at')
          .eq('prescription_id', prescriptionId)
          .eq('care_plan_id', carePlanId)
          .eq('extraction_status', 'succeeded')
          .order('processed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final normalized = row['normalized_result'];
      if (normalized is! Map) return null;
      final json = Map<String, dynamic>.from(normalized);
      final requestId = json['request_id'];
      if (requestId is! String || requestId.isEmpty) return null;

      return AiActionReviewSeed(
        result: AiActionGenerationResult.fromJson(
          json,
          expectedRequestId: requestId,
        ),
        attachmentId: row['id'] as String?,
      );
    } on AiActionSchemaException {
      return null;
    } catch (_) {
      return null;
    }
  }

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
  401 => 'করণীয় তৈরির আগে আবার লগইন করুন।',
  403 => 'করণীয় তৈরি করতে সুপার অ্যাডমিন অনুমতি লাগবে।',
  400 => 'বাছাই করা প্রেসক্রিপশনের সাথে যুক্ত খসড়া পরিকল্পনা ব্যবহার করুন।',
  404 => 'মূল প্রেসক্রিপশনটি পাওয়া যায়নি।',
  409 => 'করণীয় তৈরি ইতিমধ্যে চলছে। একটু পরে আবার চেষ্টা করুন।',
  _ => aiManualFallbackMessage,
};
