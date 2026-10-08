import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/notifications/notification_inbox_repository.dart';
import 'package:sukun_life/core/notifications/supabase_notification_inbox_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationInboxRepositoryProvider =
    Provider<NotificationInboxRepository>((ref) {
      if (!AppEnvironment.isSupabaseConfigured) {
        return const UnavailableNotificationInboxRepository();
      }
      return SupabaseNotificationInboxRepository(Supabase.instance.client);
    });

final class UnavailableNotificationInboxRepository
    implements NotificationInboxRepository {
  const UnavailableNotificationInboxRepository();

  @override
  Future<List<PatientInboxMessage>> getRecentMessages() async =>
      throw const PatientInboxException();

  @override
  Future<void> markOpened(String notificationId) async =>
      throw const PatientInboxException();
}
