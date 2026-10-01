import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseCarePlansRepository implements CarePlansRepository {
  SupabaseCarePlansRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CarePlan>> getPatientPlans(String patientId) async {
    final response = await _client
        .from('care_plans')
        .select()
        .eq('patient_id', patientId)
        .order('version', ascending: false);
    return response.map(CarePlan.fromJson).toList(growable: false);
  }

  @override
  Future<CarePlan?> getPlan(String planId) async {
    final response = await _client
        .from('care_plans')
        .select()
        .eq('id', planId)
        .maybeSingle();
    return response == null ? null : CarePlan.fromJson(response);
  }

  @override
  Future<List<PlanAction>> getActions(String planId) async {
    final response = await _client
        .from('plan_actions')
        .select(
          '*,plan_action_resources(usage_note,content_items(id,title,title_bn,type,visibility,status))',
        )
        .eq('care_plan_id', planId)
        .neq('review_status', 'rejected')
        .order('sort_order');
    return response.map(PlanAction.fromJson).toList(growable: false);
  }

  @override
  Future<List<ContentResourceOption>> getAvailableResources() async {
    final response = await _client
        .from('content_items')
        .select('id,title,title_bn,type,visibility,status')
        .eq('status', 'published')
        .order('title');
    return response
        .where((row) => row['visibility'] != 'staff_only')
        .map(ContentResourceOption.fromJson)
        .toList(growable: false);
  }

  @override
  Future<CarePlan> createDraft(CreateCarePlanInput input) async {
    return _rpcPlan('create_draft_care_plan', {
      'p_patient_id': input.patientId,
      'p_name': input.name.trim(),
      'p_start_date': _dateOnly(input.startDate),
      'p_end_date': input.endDate == null ? null : _dateOnly(input.endDate!),
      'p_prescription_id': input.prescriptionId,
      'p_copy_from_plan_id': input.copyFromPlanId,
      'p_request_id': input.requestId,
    });
  }

  @override
  Future<PlanAction> saveAction(SavePlanActionInput input) async {
    try {
      final response = await _client.rpc(
        'save_plan_action',
        params: {
          'p_care_plan_id': input.carePlanId,
          'p_type': input.type.trim(),
          'p_title': input.title.trim(),
          'p_frequency_rule': input.frequency.toJson(),
          'p_start_date': _dateOnly(input.startDate),
          'p_action_id': input.actionId,
          'p_instruction': _trimmedOrNull(input.instruction),
          'p_count_target': input.countTarget,
          'p_duration_minutes': input.durationMinutes,
          'p_time_window': input.timeWindow,
          'p_exact_time': input.exactTime == null
              ? null
              : _timeOnly(input.exactTime!),
          'p_end_date': input.endDate == null
              ? null
              : _dateOnly(input.endDate!),
          'p_review_status': input.reviewStatus.databaseValue,
          'p_reminder_enabled': input.reminderEnabled,
          'p_content_item_id': input.contentItemId,
          'p_resource_usage_note': _trimmedOrNull(input.resourceUsageNote),
          'p_request_id': input.requestId,
        },
      );
      return PlanAction.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw CarePlanWorkflowException(error.message);
    }
  }

  @override
  Future<List<PlanAction>> reorderActions(
    String planId,
    List<String> actionIds,
    String requestId,
  ) async {
    try {
      final response = await _client.rpc(
        'reorder_plan_actions',
        params: {
          'p_care_plan_id': planId,
          'p_action_ids': actionIds,
          'p_request_id': requestId,
        },
      );
      return (response as List<dynamic>)
          .map((row) => PlanAction.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw CarePlanWorkflowException(error.message);
    }
  }

  @override
  Future<void> rejectAction(String actionId, String requestId) async {
    try {
      await _client.rpc(
        'reject_plan_action',
        params: {'p_action_id': actionId, 'p_request_id': requestId},
      );
    } on PostgrestException catch (error) {
      throw CarePlanWorkflowException(error.message);
    }
  }

  @override
  Future<CarePlan> publishPlan(String planId, String requestId) {
    return _rpcPlan('publish_care_plan', {
      'p_care_plan_id': planId,
      'p_request_id': requestId,
    });
  }

  @override
  Future<CarePlan> archivePlan(String planId, String requestId) {
    return _rpcPlan('archive_care_plan', {
      'p_care_plan_id': planId,
      'p_request_id': requestId,
    });
  }

  Future<CarePlan> _rpcPlan(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _client.rpc(functionName, params: params);
      return CarePlan.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw CarePlanWorkflowException(error.message);
    }
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _timeOnly(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:00';

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed?.isEmpty == true ? null : trimmed;
}
