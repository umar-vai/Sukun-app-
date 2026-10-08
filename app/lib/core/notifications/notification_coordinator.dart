import 'dart:async';

import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/notification_repository.dart';
import 'package:sukun_life/core/notifications/notification_state_store.dart';
import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

class CareNotificationStatus {
  const CareNotificationStatus({
    required this.enabled,
    required this.permissionGranted,
    required this.preciseTimingAvailable,
    this.lastSyncSucceeded = true,
  });

  final bool enabled;
  final bool permissionGranted;
  final bool preciseTimingAvailable;
  /// Whether the most recent schedule refresh completed without an error.
  final bool lastSyncSucceeded;
}

final class NotificationCoordinator {
  NotificationCoordinator(
    this._repository,
    this._local,
    this._push,
    this._store, {
    DateTime Function()? now,
    this.platform = 'unknown',
  }) : _now = now ?? DateTime.now,
       assert(
         platform == 'android' || platform == 'ios' || platform == 'unknown',
       );

  final NotificationRepository _repository;
  final LocalNotificationsGateway _local;
  final PushMessagingGateway _push;
  final NotificationStateStore _store;
  final DateTime Function() _now;
  final String platform;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void>? _activeSync;
  bool _initialized = false;
  bool _lastSyncSucceeded = true;

  Future<void> initialize() async {
    if (_initialized) return;
    await _local.initialize();
    _subscriptions
      ..add(_push.tokenRefresh.listen(_registerRefreshedToken))
      ..add(_push.foregroundMessages.listen(_handleForegroundMessage))
      ..add(_push.openedMessages.listen(_handleOpenedMessage));
    _initialized = true;
    final initialMessage = await _push.getInitialMessage();
    if (initialMessage != null) {
      await _handleOpenedMessage(initialMessage);
    }
  }

  Future<CareNotificationStatus> status() async {
    await initialize();
    return CareNotificationStatus(
      enabled: await _store.isEnabled(),
      permissionGranted: await _local.isPermissionGranted(),
      preciseTimingAvailable: await _local.canSchedulePrecisely(),
      lastSyncSucceeded: _lastSyncSucceeded,
    );
  }

  Future<bool> enable() async {
    await initialize();
    final granted = await _local.requestPermission();
    if (!granted) {
      await _store.setEnabled(false);
      return false;
    }
    if (_push.isAvailable) {
      try {
        await _push.requestPermission();
      } on Object {
        // Local reminders remain available when remote delivery is unavailable.
      }
    }
    await _local.requestPreciseSchedulingPermission();
    await _store.setEnabled(true);
    await syncIfEnabled();
    return true;
  }

  Future<bool> requestPreciseTimingAccess() async {
    try {
      await initialize();
      final granted = await _local.requestPreciseSchedulingPermission();
      if (granted) await syncIfEnabled();
      return granted;
    } on Object {
      return false;
    }
  }

  Future<void> syncIfEnabled() {
    final existing = _activeSync;
    if (existing != null) return existing;
    final operation = _syncSafely();
    _activeSync = operation;
    return operation.whenComplete(() => _activeSync = null);
  }

  Future<void> _syncSafely() async {
    try {
      await initialize();
      if (!await _store.isEnabled() || !await _local.isPermissionGranted()) {
        return;
      }

      final timezone = await _local.configureTimezone();
      final window = await _repository.getReminderTasks(horizonDays: 30);
      final reminders = planCareReminders(tasks: window.tasks, now: _now());
      final precise = await _local.canSchedulePrecisely();
      final previousIds = await _store.scheduledNotificationIds();
      for (final id in previousIds) {
        await _local.cancel(id);
      }

      final scheduledIds = <int>[];
      for (final reminder in reminders) {
        await _local.schedule(reminder, precise: precise);
        scheduledIds.add(reminder.notificationId);
      }
      await _store.setScheduledNotificationIds(scheduledIds);
      await _registerCurrentToken(timezone);
      _lastSyncSucceeded = true;
    } on Object {
      _lastSyncSucceeded = false;
      // Scheduling must not block care tasks; the profile can now explain
      // the failure and offer a retry instead of silently showing success.
    }
  }

  Future<void> scheduleSnooze(PatientTask task, DateTime snoozedUntil) async {
    try {
      if (!await _store.isEnabled() ||
          !await _local.isPermissionGranted() ||
          !snoozedUntil.isAfter(_now())) {
        return;
      }
      final reminder = planSnoozeReminder(
        task: task,
        snoozedUntil: snoozedUntil,
      );
      final precise = await _local.canSchedulePrecisely();
      await _local.cancel(reminder.notificationId);
      await _local.schedule(reminder, precise: precise);
      final ids = await _store.scheduledNotificationIds()
        ..add(reminder.notificationId);
      await _store.setScheduledNotificationIds(ids);
    } on Object {
      // The server-side snooze state remains authoritative if scheduling fails.
    }
  }

  Future<void> cancelTask(PatientTask task) async {
    try {
      final id = stableNotificationId('care:${task.id}');
      await _local.cancel(id);
      final ids = await _store.scheduledNotificationIds()
        ..remove(id);
      await _store.setScheduledNotificationIds(ids);
    } on Object {
      // Completion state must not fail because a local notification was stale.
    }
  }

  Future<void> disable() async {
    try {
      for (final id in await _store.scheduledNotificationIds()) {
        await _local.cancel(id);
      }
      await _store.setScheduledNotificationIds(const []);
      final installationId = await _store.getOrCreateInstallationId();
      await _repository.removeDevice(installationId);
      await _push.deleteToken();
    } on Object {
      // Local state is disabled even if a remote device cleanup must retry later.
    } finally {
      await _store.setEnabled(false);
    }
  }

  Future<void> _registerCurrentToken(String timezone) async {
    final token = await _push.getToken();
    if (token == null || token.isEmpty) return;
    await _repository.registerDevice(
      installationId: await _store.getOrCreateInstallationId(),
      platform: platform,
      pushToken: token,
      timezone: timezone,
    );
  }

  Future<void> _registerRefreshedToken(String token) async {
    try {
      if (!await _store.isEnabled()) return;
      await _repository.registerDevice(
        installationId: await _store.getOrCreateInstallationId(),
        platform: platform,
        pushToken: token,
        timezone: await _local.configureTimezone(),
      );
    } on Object {
      // A later app refresh or token event retries registration.
    }
  }

  Future<void> _handleForegroundMessage(RemotePushMessage message) async {
    try {
      // Do not trust provider-supplied push copy on an unlocked or locked
      // device: it could accidentally contain patient/prescription details.
      await _local.showRemote(
        title: 'সুকুন লাইফ',
        body: 'আপনার জন্য নতুন একটি বার্তা এসেছে।',
      );
      if (message.type == 'plan_updated') await syncIfEnabled();
    } on Object {
      // Foreground display and refresh are best effort.
    }
  }

  Future<void> _handleOpenedMessage(RemotePushMessage message) async {
    if (message.type == 'plan_updated') await syncIfEnabled();
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
