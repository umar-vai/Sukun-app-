import 'package:sukun_life/core/notifications/notification_repository.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ReminderTaskWindow> getReminderTasks({
    required int horizonDays,
    String? patientId,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: horizonDays));
    try {
      await _client.rpc(
        'ensure_patient_reminder_tasks',
        params: {
          'p_start_date': _dateOnly(today),
          'p_end_date': _dateOnly(end),
          'p_timezone_offset_minutes': now.timeZoneOffset.inMinutes,
          'p_patient_id': ?patientId,
        },
      );
      var planQuery = _client.from('care_plans').select('id');
      if (patientId != null) planQuery = planQuery.eq('patient_id', patientId);
      final plan = await planQuery.eq('status', 'active').maybeSingle();
      if (plan == null) {
        return const ReminderTaskWindow(planId: null, tasks: []);
      }
      final planId = plan['id'] as String;
      var taskQuery = _client
          .from('task_instances')
          .select('*,plan_actions!inner(*)')
          .eq('plan_actions.care_plan_id', planId);
      if (patientId != null) taskQuery = taskQuery.eq('patient_id', patientId);
      final rows = await taskQuery
          .gte('occurrence_date', _dateOnly(today))
          .lte('occurrence_date', _dateOnly(end))
          .inFilter('status', ['pending', 'snoozed'])
          .order('scheduled_at');
      return ReminderTaskWindow(
        planId: planId,
        tasks: rows.map(PatientTask.fromJson).toList(growable: false),
      );
    } on PostgrestException {
      throw const NotificationException(
        'Care reminders could not be refreshed. Please try again.',
      );
    }
  }

  @override
  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String pushToken,
    required String timezone,
    String? patientId,
  }) async {
    try {
      await _client.rpc(
        'register_notification_device',
        params: {
          'p_installation_id': installationId,
          'p_platform': platform,
          'p_push_token': pushToken,
          'p_timezone': timezone,
          'p_patient_id': ?patientId,
        },
      );
    } on PostgrestException {
      throw const NotificationException(
        'This device could not be registered for plan updates.',
      );
    }
  }

  @override
  Future<void> removeDevice(String installationId) async {
    try {
      await _client.rpc(
        'remove_notification_device',
        params: {'p_installation_id': installationId},
      );
    } on PostgrestException {
      throw const NotificationException(
        'This device could not be removed from plan updates.',
      );
    }
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
