import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract interface class NotificationStateStore {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool value);
  Future<String> getOrCreateInstallationId();
  Future<Set<int>> scheduledNotificationIds();
  Future<void> setScheduledNotificationIds(Iterable<int> ids);
}

final class SharedPreferencesNotificationStateStore
    implements NotificationStateStore {
  const SharedPreferencesNotificationStateStore();

  static const _enabledKey = 'care_notifications_enabled';
  static const _installationIdKey = 'notification_installation_id';
  static const _scheduledIdsKey = 'care_notification_ids';

  @override
  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  @override
  Future<void> setEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, value);
  }

  @override
  Future<String> getOrCreateInstallationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_installationIdKey);
    if (existing?.isNotEmpty == true) return existing!;
    final created = const Uuid().v4();
    await preferences.setString(_installationIdKey, created);
    return created;
  }

  @override
  Future<Set<int>> scheduledNotificationIds() async {
    final values =
        (await SharedPreferences.getInstance()).getStringList(
          _scheduledIdsKey,
        ) ??
        const [];
    return values.map(int.tryParse).whereType<int>().toSet();
  }

  @override
  Future<void> setScheduledNotificationIds(Iterable<int> ids) async {
    final values = ids.map((id) => '$id').toList(growable: false)..sort();
    await (await SharedPreferences.getInstance()).setStringList(
      _scheduledIdsKey,
      values,
    );
  }
}
