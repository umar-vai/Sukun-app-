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
    scheduledCalls.add((reminder: reminder, precise: precise));
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }

  @override
  Future<void> showRemote({
    required String title,
    required String body,
  }) async {}
}

final class _FakePushMessaging implements PushMessagingGateway {
  bool deleted = false;

  @override
  bool get isAvailable => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<String?> getToken() async => 'fresh-token';

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<RemotePushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();

  @override
  Future<RemotePushMessage?> getInitialMessage() async => null;

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
