import 'package:sukun_life/core/notifications/notification_inbox_repository.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All rows are further restricted by the notification_events read policy,
/// which for a family login allows every linked profile. The selected profile
/// narrows the list to one person; the client never gains extra access.
final class SupabaseNotificationInboxRepository
    implements NotificationInboxRepository {
  const SupabaseNotificationInboxRepository(
    this._client, [
    this._activePatientId,
  ]);

  final SupabaseClient _client;
  final ActivePatientIdReader? _activePatientId;

  @override
  Future<List<PatientInboxMessage>> getRecentMessages() async {
    try {
      final patientId = await _activePatientId?.call();
      var query = _client
          .from('notification_events')
          .select('id,notification_type,status,scheduled_at,opened_at');
      if (patientId != null) query = query.eq('patient_id', patientId);
      final rows = await query
          .inFilter('status', ['sent', 'opened'])
          .lte('scheduled_at', DateTime.now().toUtc().toIso8601String())
          .order('scheduled_at', ascending: false)
          .limit(50);
      return rows.map(PatientInboxMessage.fromJson).toList(growable: false);
    } on Object {
      // No low-level provider error or patient metadata may surface in UI.
      throw const PatientInboxException();
    }
  }

  @override
  Future<void> markOpened(String notificationId) async {
    try {
      final result = await _client.rpc(
        'mark_patient_notification_opened',
        params: {'p_notification_id': notificationId},
      );
      if (result != true) throw const PatientInboxException();
    } on Object {
      throw const PatientInboxException();
    }
  }
}
