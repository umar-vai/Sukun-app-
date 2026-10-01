import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabasePatientCareRepository implements PatientCareRepository {
  SupabasePatientCareRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PatientDay> getToday() async {
    final now = DateTime.now();
    final localDate = DateTime(now.year, now.month, now.day);
    try {
      await _client.rpc(
        'ensure_patient_tasks',
        params: {
          'p_local_date': _dateOnly(localDate),
          'p_timezone_offset_minutes': now.timeZoneOffset.inMinutes,
        },
      );
      final plan = await getActivePlan();
      if (plan == null) return const PatientDay(tasks: []);
      final response = await _client
          .from('task_instances')
          .select(
            '*,plan_actions!inner(*,plan_action_resources(usage_note,content_items(id,title,title_bn,type,visibility,status)))',
          )
          .eq('occurrence_date', _dateOnly(localDate))
          .eq('plan_actions.care_plan_id', plan.id)
          .order('scheduled_at', nullsFirst: false);
      final tasks = response.map(PatientTask.fromJson).toList();
      tasks.sort((left, right) {
        final leftTime = left.scheduledAt;
        final rightTime = right.scheduledAt;
        if (leftTime != null && rightTime != null) {
          final comparison = leftTime.compareTo(rightTime);
          if (comparison != 0) return comparison;
        } else if (leftTime != null) {
          return -1;
        } else if (rightTime != null) {
          return 1;
        }
        return left.action.sortOrder.compareTo(right.action.sortOrder);
      });
      return PatientDay(activePlan: plan, tasks: List.unmodifiable(tasks));
    } on PostgrestException catch (error) {
      throw PatientCareException(error.message);
    }
  }

  @override
  Future<CarePlan?> getActivePlan() async {
    final response = await _client
        .from('care_plans')
        .select()
        .eq('status', 'active')
        .maybeSingle();
    return response == null ? null : CarePlan.fromJson(response);
  }

  @override
  Future<List<PlanAction>> getActivePlanActions(String planId) async {
    final response = await _client
        .from('plan_actions')
        .select(
          '*,plan_action_resources(usage_note,content_items(id,title,title_bn,type,visibility,status))',
        )
        .eq('care_plan_id', planId)
        .eq('review_status', 'approved')
        .order('sort_order');
    return response.map(PlanAction.fromJson).toList(growable: false);
  }

  @override
  Future<List<Prescription>> getVisiblePrescriptions() async {
    final response = await _client
        .from('prescriptions')
        .select()
        .eq('visibility', 'patient')
        .order('created_at', ascending: false);
    return response.map(Prescription.fromJson).toList(growable: false);
  }

  @override
  Future<PatientTask> recordTask({
    required String taskId,
    required PatientTaskStatus status,
    required String clientEventId,
    DateTime? snoozedUntil,
    String? skipReason,
  }) async {
    try {
      await _client.rpc(
        'record_task_completion',
        params: {
          'p_task_id': taskId,
          'p_new_status': status.name,
          'p_client_event_id': clientEventId,
          'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
          'p_snoozed_until': snoozedUntil?.toUtc().toIso8601String(),
          'p_skip_reason': skipReason,
        },
      );
      final today = await getToday();
      return today.tasks.firstWhere((task) => task.id == taskId);
    } on PostgrestException catch (error) {
      throw PatientCareException(error.message);
    }
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
