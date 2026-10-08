import 'package:sukun_life/core/notifications/notification_inbox_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All rows are further restricted by notification_events_select_own_or_admin.
/// Never accept a patientId from the client; the server derives ownership.
final class SupabaseNotificationInboxRepository
    implements NotificationInboxRepository {
  const SupabaseNotificationInboxRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PatientInboxMessage>> getRecentMessages() async {
    try {
      final rows = await _client
          .from('notification_events')
          .select('id,notification_type,status,scheduled_at,opened_at')
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
