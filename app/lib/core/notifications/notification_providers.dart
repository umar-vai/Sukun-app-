import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/notification_coordinator.dart';
import 'package:sukun_life/core/notifications/notification_repository.dart';
import 'package:sukun_life/core/notifications/notification_state_store.dart';
import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';
import 'package:sukun_life/core/notifications/supabase_notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String get _notificationPlatform {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

final notificationCoordinatorProvider = Provider<NotificationCoordinator>((
  ref,
) {
  final repository = AppEnvironment.isSupabaseConfigured
      ? SupabaseNotificationRepository(Supabase.instance.client)
      : const UnavailableNotificationRepository();
  final coordinator = NotificationCoordinator(
    repository,
    PluginLocalNotificationsGateway(),
    FirebasePushMessagingGateway(
      isAvailable: AppEnvironment.isFirebaseConfigured,
    ),
    const SharedPreferencesNotificationStateStore(),
    platform: _notificationPlatform,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final class UnavailableNotificationRepository
    implements NotificationRepository {
  const UnavailableNotificationRepository();

  Never _unavailable() => throw const NotificationException(
    'Connect Supabase to manage care reminders.',
  );

  @override
  Future<ReminderTaskWindow> getReminderTasks({
    required int horizonDays,
  }) async => _unavailable();

  @override
  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String pushToken,
    required String timezone,
  }) async => _unavailable();

  @override
  Future<void> removeDevice(String installationId) async => _unavailable();
}
