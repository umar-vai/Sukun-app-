import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/notification_coordinator.dart';
import 'package:sukun_life/core/notifications/notification_repository.dart';
import 'package:sukun_life/core/notifications/notification_state_store.dart';
import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

void main() {
  late _FakeRepository repository;
  late _FakeLocalNotifications local;
  late _FakePushMessaging push;
  late _MemoryStateStore store;
  late NotificationCoordinator coordinator;

  setUp(() {
    repository = _FakeRepository();
    local = _FakeLocalNotifications();
    push = _FakePushMessaging();
    store = _MemoryStateStore();
    coordinator = NotificationCoordinator(
      repository,
      local,
      push,
      store,
      platform: 'android',
      now: () => DateTime(2026, 10, 2, 8),
    );
  });

  tearDown(() => coordinator.dispose());

  test(
    'enable schedules care reminders and registers the device token',
    () async {
      repository.tasks = [_task('task-1', DateTime(2026, 10, 2, 9))];

      expect(await coordinator.enable(), isTrue);

      expect(local.scheduled.map((item) => item.taskId), ['task-1']);
      expect(repository.registeredToken, 'fresh-token');
      expect(repository.registeredInstallation, 'installation-id');
      expect(local.precisePermissionRequested, isTrue);
      expect(local.scheduledCalls.single.precise, isTrue);
    },
  );

  test(
    'denied precise timing safely falls back to inexact scheduling',
    () async {
      local.precisePermission = false;
      repository.tasks = [_task('task-1', DateTime(2026, 10, 2, 9))];

      expect(await coordinator.enable(), isTrue);

      expect(local.scheduledCalls.single.precise, isFalse);
      expect(repository.registeredToken, 'fresh-token');
    },
  );

  test('plan refresh cancels prior reminders before replacing them', () async {
    store.enabled = true;
    store.ids = {42};
    repository.tasks = [_task('new-task', DateTime(2026, 10, 2, 10))];

    await coordinator.syncIfEnabled();

    expect(local.cancelled, contains(42));
    expect(store.ids, {stableNotificationId('care:new-task')});
  });

  test('snooze replaces the task reminder at patient-selected time', () async {
    store.enabled = true;
    final task = _task('task-1', DateTime(2026, 10, 2, 9));
    final snoozeTime = DateTime(2026, 10, 2, 9, 30);

    await coordinator.scheduleSnooze(task, snoozeTime);

    expect(local.cancelled, [stableNotificationId('care:task-1')]);
    expect(local.scheduled.single.scheduledAt, snoozeTime);
  });

  test(
    'failed scheduling is reported for patient retry without blocking care',
    () async {
      repository.tasks = [_task('task-1', DateTime(2026, 10, 2, 9))];
      local.failScheduling = true;

      expect(await coordinator.enable(), isTrue);
      final status = await coordinator.status();

      expect(status.permissionGranted, isTrue);
      expect(status.lastSyncSucceeded, isFalse);

      local.failScheduling = false;
      await coordinator.syncIfEnabled();
      expect((await coordinator.status()).lastSyncSucceeded, isTrue);
    },
  );

  test('registered Web FCM token suppresses duplicate local timers', () async {
    repository.tasks = [_task('task-1', DateTime(2026, 10, 2, 9))];
    final browser = NotificationCoordinator(
      repository,
      local,
      push,
      store,
      platform: 'web',
      now: () => DateTime(2026, 10, 2, 8),
    );
    try {
      expect(await browser.enable(), isTrue);
      expect(repository.registeredToken, 'fresh-token');
      expect(local.scheduled, isEmpty);
      expect(store.ids, isEmpty);
    } finally {
      await browser.dispose();
    }
  });

  test(
    'Web Push token unavailable retains active-tab reminder fallback',
    () async {
      push.token = null;
      repository.tasks = [_task('task-1', DateTime(2026, 10, 2, 9))];
      final browser = NotificationCoordinator(
        repository,
        local,
        push,
        store,
        platform: 'web',
        now: () => DateTime(2026, 10, 2, 8),
      );
      try {
        expect(await browser.enable(), isTrue);
        expect(local.scheduled.map((r) => r.taskId), ['task-1']);
        expect(repository.registeredToken, isNull);
      } finally {
        await browser.dispose();
      }
    },
  );

  test('browser coordinator is accepted without native exact alarms', () async {
    final browser = NotificationCoordinator(
      repository,
      local,
      push,
      store,
      platform: 'web',
    );
    try {
      await browser.initialize();
      expect(await browser.status(), isA<CareNotificationStatus>());
    } finally {
      await browser.dispose();
    }
  });

  test(
    'only valid care reminder Firebase task UUIDs reach tap relay',
    () async {
      final opened = <String?>[];
      const validTaskId = 'a4ba5d60-81df-4688-81c8-b1064f7cf45e';
      final listener = NotificationCoordinator(
        repository,
        local,
        push,
        store,
        platform: 'android',
        onTaskOpened: opened.add,
      );
      await listener.initialize();
      push.emit(
        const RemotePushMessage(
          type: 'care_reminder',
          title: 'Sukun',
          body: 'Care task',
          taskId: validTaskId,
        ),
      );
      push.emit(
        const RemotePushMessage(
          type: 'care_reminder',
          title: 'Sukun',
          body: 'Ignore untrusted target',
          taskId: 'https://evil.test',
        ),
      );
      push.emit(
        const RemotePushMessage(
          type: 'plan_updated',
          title: 'Sukun',
          body: 'Not a care task',
          taskId: validTaskId,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['care_task:$validTaskId']);
      await listener.dispose();
    },
  );

  test('foreground push opens only its validated care task', () async {
    const taskId = 'a4ba5d60-81df-4688-81c8-b1064f7cf45e';
    await coordinator.initialize();
    push.emitForeground(
      const RemotePushMessage(
        type: 'care_reminder',
        title: 'Untrusted provider title',
        body: 'Untrusted patient text',
        taskId: taskId,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(local.lastRemotePayload, 'care_task:$taskId');
    push.emitForeground(
      const RemotePushMessage(
        type: 'care_reminder',
        title: 'Ignore',
        body: 'Ignore',
        taskId: 'https://evil.test',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(local.lastRemotePayload, isNull);
  });

  test('Guest foreground and tap public notice work without care token registration', () async {
    const noticeId = 'a1b2c3d4-a123-4fff-8aaa-123456789abc';
    final opened = <String>[];
    final guest = NotificationCoordinator(
      repository,
      local,
      push,
      store,
      platform: 'android',
      onTaskOpened: opened.add,
    );
    try {
      await guest.initialize();
      expect(store.enabled, isFalse);
      expect(repository.registeredToken, isNull);
      push.emitForeground(
        const RemotePushMessage(
          type: 'universal_announcement',
          title: 'Public campaign',
          body: 'Test only',
          announcementId: noticeId,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(local.lastRemotePayload, 'universal_notice:$noticeId');

      push.emit(
        const RemotePushMessage(
          type: 'universal_announcement',
          title: 'Public campaign',
          body: 'Test only',
          announcementId: noticeId,
        ),
      );
      push.emit(
        const RemotePushMessage(
          type: 'universal_announcement',
          title: 'Do not redirect',
          body: 'Untrusted',
          announcementId: 'https://evil.example',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['universal_notice:$noticeId']);
    } finally {
      await guest.dispose();
    }
  });

  test('cold-start public FCM message is validated and routed once', () async {
    const noticeId = 'a1b2c3d4-a123-4fff-8aaa-123456789abc';
    push.initial = const RemotePushMessage(
      type: 'universal_announcement',
      title: 'Public notice',
      body: 'Test',
      announcementId: noticeId,
    );
    final opened = <String>[];
    final guest = NotificationCoordinator(
      repository,
      local,
      push,
      store,
      platform: 'android',
      onTaskOpened: opened.add,
    );
    try {
      await guest.initialize();
      expect(opened, ['universal_notice:$noticeId']);
    } finally {
      await guest.dispose();
    }
  });

  test('disable cancels reminders and removes the registered device', () async {
    store.enabled = true;
    store.ids = {7, 8};

    await coordinator.disable();

    expect(local.cancelled, containsAll([7, 8]));
    expect(repository.removedInstallation, 'installation-id');
    expect(push.deleted, isTrue);
    expect(store.enabled, isFalse);
  });
}

PatientTask _task(String id, DateTime scheduledAt) => PatientTask(
  id: id,
  patientId: 'patient-id',
  occurrenceDate: DateTime(
    scheduledAt.year,
    scheduledAt.month,
    scheduledAt.day,
  ),
  scheduledAt: scheduledAt,
  status: PatientTaskStatus.pending,
  action: PlanAction(
    id: 'action-$id',
    carePlanId: 'plan-id',
    type: 'recitation',
    title: 'Care action',
    frequency: const ActionFrequency.daily(),
    startDate: DateTime(2026, 10, 2),
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: true,
    exactTime: DateTime(2000, 1, 1, scheduledAt.hour, scheduledAt.minute),
  ),
);

final class _FakeRepository implements NotificationRepository {
  List<PatientTask> tasks = [];
  String? registeredToken;
  String? registeredInstallation;
  String? removedInstallation;

  @override
  Future<ReminderTaskWindow> getReminderTasks({
    required int horizonDays,
  }) async => ReminderTaskWindow(planId: 'plan-id', tasks: tasks);

  @override
  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String pushToken,
    required String timezone,
  }) async {
    registeredInstallation = installationId;
    registeredToken = pushToken;
  }

  @override
  Future<void> removeDevice(String installationId) async {
    removedInstallation = installationId;
  }
}

final class _FakeLocalNotifications implements LocalNotificationsGateway {
  final List<int> cancelled = [];
  bool permission = true;
  bool precisePermission = true;
  bool precisePermissionRequested = false;
  bool failScheduling = false;
  final List<({ReminderSchedule reminder, bool precise})> scheduledCalls = [];

  List<ReminderSchedule> get scheduled =>
      scheduledCalls.map((call) => call.reminder).toList(growable: false);

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<bool> isPermissionGranted() async => permission;

  @override
  Future<bool> requestPreciseSchedulingPermission() async {
    precisePermissionRequested = true;
    return precisePermission;
  }

  @override
  Future<bool> canSchedulePrecisely() async => precisePermission;

  @override
  Future<String> configureTimezone() async => 'Asia/Dhaka';

  @override
  Future<void> schedule(
    ReminderSchedule reminder, {
    required bool precise,
  }) async {
    if (failScheduling) throw StateError('fake local scheduling failure');
    scheduledCalls.add((reminder: reminder, precise: precise));
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }

  String? lastRemotePayload;

  @override
  Future<void> showRemote({
    required String title,
    required String body,
    String? payload,
  }) async {
    lastRemotePayload = payload;
  }
}

final class _FakePushMessaging implements PushMessagingGateway {
  bool deleted = false;
  String? token = 'fresh-token';
  RemotePushMessage? initial;

  @override
  bool get isAvailable => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  final StreamController<RemotePushMessage> _foreground =
      StreamController<RemotePushMessage>.broadcast();

  void emitForeground(RemotePushMessage message) => _foreground.add(message);

  @override
  Stream<RemotePushMessage> get foregroundMessages => _foreground.stream;

  final StreamController<RemotePushMessage> _opened =
      StreamController<RemotePushMessage>.broadcast();

  void emit(RemotePushMessage message) => _opened.add(message);

  @override
  Stream<RemotePushMessage> get openedMessages => _opened.stream;

  @override
  Future<RemotePushMessage?> getInitialMessage() async => initial;

  @override
  Future<void> deleteToken() async {
    deleted = true;
  }
}

final class _MemoryStateStore implements NotificationStateStore {
  bool enabled = false;
  Set<int> ids = {};

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<String> getOrCreateInstallationId() async => 'installation-id';

  @override
  Future<Set<int>> scheduledNotificationIds() async => {...ids};

  @override
  Future<void> setScheduledNotificationIds(Iterable<int> values) async {
    ids = values.toSet();
  }
}
