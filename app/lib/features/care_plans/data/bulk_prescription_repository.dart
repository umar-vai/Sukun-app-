import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final bulkPrescriptionRepositoryProvider = Provider<BulkPrescriptionRepository>(
  (ref) => BulkPrescriptionRepository(
    AppEnvironment.isSupabaseConfigured ? Supabase.instance.client : null,
  ),
);

class BulkPrescriptionRepository {
  const BulkPrescriptionRepository(this._client);
  final SupabaseClient? _client;

  Future<String?> practitionerName(String userId) async {
    final profile = await _client!
        .from('profiles')
        .select('display_name')
        .eq('id', userId)
        .maybeSingle();
    return profile?['display_name'] as String?;
  }

  Future<void> undoBatch(String planId, String requestId) async {
    await _client!.rpc<void>(
      'undo_prescription_draft_batch',
      params: {'p_plan_id': planId, 'p_request_id': requestId},
    );
  }

  Future<List<String>> expandSchedule({
    required String planId,
    required String actionId,
    required String requestId,
    List<int>? stageDays,
    List<String>? times,
  }) async {
    final ids = await _client!.rpc<List<dynamic>>(
      'expand_prescription_action_schedule',
      params: {
        'p_plan_id': planId,
        'p_action_id': actionId,
        'p_stage_days': stageDays,
        'p_times': times,
        'p_request_id': requestId,
      },
    );
    return ids.cast<String>();
  }

  Future<int> importTemplates(
    String planId,
    List<OfficialPrescriptionTemplate> templates,
    String requestId,
  ) async {
    return await _client!.rpc<int>(
      'import_official_plan_actions',
      params: {
        'p_plan_id': planId,
        'p_templates': [
          for (final template in templates)
            {
              'id': template.id,
              'title': template.title,
              'instruction': template.instruction,
            },
        ],
        'p_request_id': requestId,
      },
    );
  }

  Future<void> updateActions(
    String planId,
    Set<String> actionIds,
    Map<String, Object?> patch,
    String requestId,
  ) async {
    await _client!.rpc<void>(
      'update_prescription_draft_actions',
      params: {
        'p_plan_id': planId,
        'p_action_ids': actionIds.toList(),
        'p_patch': patch,
        'p_request_id': requestId,
      },
    );
  }
}
