import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/data/task_completion_coordinator.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/domain/pending_task_completion.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabasePatientCareRepository implements PatientCareRepository {
  SupabasePatientCareRepository(
    this._client,
    this._completionCoordinator,
    this._activePatientId,
  );

  final SupabaseClient _client;
  final TaskCompletionCoordinator _completionCoordinator;

  /// The profile this device is showing. Every read below filters by it, so
  /// a family login never mixes one profile's tasks, plan or numbers into
  /// another's. RLS still decides what the login may read at all.
  final ActivePatientIdReader _activePatientId;

  Future<String> _requirePatientId() async {
    final patientId = await _activePatientId();
    if (patientId == null) {
      throw const PatientCareException('A patient profile is required.');
    }
    return patientId;
  }

  @override
  Future<PatientDay> getToday() async {
    final now = DateTime.now();
    final localDate = DateTime(now.year, now.month, now.day);
    final userId = _currentUserId();
    final patientId = await _requirePatientId();
    try {
      await _completionCoordinator.flush(userId, patientId);
      await _client.rpc(
        'ensure_patient_tasks',
        params: {
          'p_local_date': _dateOnly(localDate),
          'p_timezone_offset_minutes': now.timeZoneOffset.inMinutes,
          'p_patient_id': patientId,
        },
      );
      final plan = await _activePlanFor(patientId);
      if (plan == null) return const PatientDay(tasks: []);
      final response = await _client
          .from('task_instances')
          .select(
            '*,plan_actions!inner(*,plan_action_resources(sort_order,usage_note,content_items(id,title,title_bn,type,visibility,status,media_source_type,media_url,youtube_video_id,thumbnail_url,rights_note)),plan_action_quran_surahs(surah_number,title,sort_order))',
          )
          .eq('patient_id', patientId)
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
      final day = PatientDay(activePlan: plan, tasks: List.unmodifiable(tasks));
      return await _completionCoordinator.applyPending(userId, patientId, day);
    } on PostgrestException catch (error) {
      throw PatientCareException(error.message);
    }
  }

  @override
  Future<CarePlan?> getActivePlan() async =>
      _activePlanFor(await _requirePatientId());

  Future<CarePlan?> _activePlanFor(String patientId) async {
    final response = await _client
        .from('care_plans')
        .select()
        .eq('patient_id', patientId)
        .eq('status', 'active')
        .maybeSingle();
    return response == null ? null : CarePlan.fromJson(response);
  }

  @override
  Future<List<PlanAction>> getActivePlanActions(String planId) async {
    final response = await _client
        .from('plan_actions')
        .select(
          '*,plan_action_resources(sort_order,usage_note,content_items(id,title,title_bn,type,visibility,status,media_source_type,media_url,youtube_video_id,thumbnail_url,rights_note)),plan_action_quran_surahs(surah_number,title,sort_order)',
        )
        .eq('care_plan_id', planId)
        .eq('review_status', 'approved')
        .order('sort_order', ascending: true);
    return response.map(PlanAction.fromJson).toList(growable: false);
  }

  @override
  Future<List<Prescription>> getVisiblePrescriptions() async {
    final patientId = await _requirePatientId();
    final response = await _client
        .from('prescriptions')
        .select()
        .eq('patient_id', patientId)
        .eq('visibility', 'patient')
        .order('created_at', ascending: false);
    return response.map(Prescription.fromJson).toList(growable: false);
  }

  @override
  Future<PatientTask> recordTask({
    required PatientTask task,
    required PatientTaskStatus status,
    required String clientEventId,
    DateTime? snoozedUntil,
    String? skipReason,
  }) async {
    return _completionCoordinator.record(
      userId: _currentUserId(),
      task: task,
      status: status,
      clientEventId: clientEventId,
      occurredAt: DateTime.now().toUtc(),
      snoozedUntil: snoozedUntil,
      skipReason: skipReason,
    );
  }

  String _currentUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const PatientCareException('Patient sign-in is required.');
    }
    return userId;
  }
}

final class SupabaseTaskCompletionRemote implements TaskCompletionRemote {
  const SupabaseTaskCompletionRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> submit(PendingTaskCompletion event) async {
    try {
      await _client.rpc(
        'record_task_completion',
        params: {
          'p_task_id': event.taskId,
          'p_new_status': event.status.name,
          'p_client_event_id': event.clientEventId,
          'p_occurred_at': event.occurredAt.toUtc().toIso8601String(),
          'p_snoozed_until': event.snoozedUntil?.toUtc().toIso8601String(),
          'p_skip_reason': event.skipReason,
        },
      );
    } on PostgrestException catch (error) {
      throw TaskCompletionSyncException(
        _isRetryable(error)
            ? 'Your update is saved on this device and will sync automatically.'
            : 'This task update could not be accepted.',
        retryable: _isRetryable(error),
      );
    } on Object {
      throw const TaskCompletionSyncException(
        'Your update is saved on this device and will sync automatically.',
        retryable: true,
      );
    }
  }
}

bool _isRetryable(PostgrestException error) {
  final code = error.code?.toUpperCase() ?? '';
  final message = error.message.toLowerCase();
  return code.startsWith('08') ||
      code.startsWith('53') ||
      code.startsWith('57P') ||
      code == 'PGRST000' ||
      code == 'PGRST001' ||
      message.contains('timeout') ||
      message.contains('temporarily unavailable') ||
      message.contains('connection');
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
