import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/notification_coordinator.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/notifications/notification_repository.dart';
import 'package:sukun_life/core/notifications/notification_state_store.dart';
import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/features/family/presentation/profile_scope.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

import '../../features/family/family_test_support.dart';

PatientTask _task(String id, String patientId, DateTime at) => PatientTask(
  id: id,
  patientId: patientId,
  occurrenceDate: DateTime(at.year, at.month, at.day),
  scheduledAt: at,
  status: PatientTaskStatus.pending,
  action: PlanAction(
    id: 'action-$id',
    carePlanId: 'plan-$patientId',
    type: 'recitation',
    title: 'Care action',
    frequency: const ActionFrequency.daily(),
    startDate: DateTime(2026, 11, 1),
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: true,
    exactTime: DateTime(2000, 1, 1, at.hour, at.minute),
  ),
);

final class _Repo implements NotificationRepository {
  final Map<String, List<PatientTask>> tasksByPatient = {};
  final List<String?> requestedFor = [];
  final List<String?> registeredFor = [];
  Completer<void>? gateFor;
  String? gatedPatient;

  @override
  Future<ReminderTaskWindow> getReminderTasks({
    required int horizonDays,
    String? patientId,
  }) async {
    requestedFor.add(patientId);
    if (patientId == gatedPatient) await gateFor?.future;
    return ReminderTaskWindow(
      planId: 'plan-$patientId',
      tasks: tasksByPatient[patientId] ?? const [],
    );
  }

  @override
  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String pushToken,
    required String timezone,
    String? patientId,
  }) async => registeredFor.add(patientId);

  @override
  Future<void> removeDevice(String installationId) async {}
}

/// Tracks what the OS would still hold: schedule adds, cancel removes.
final class _Local implements LocalNotificationsGateway {
  final Set<int> pending = {};
  final List<ReminderSchedule> scheduledCalls = [];
  final List<int> cancelled = [];

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  Future<bool> requestPreciseSchedulingPermission() async => true;
  @override
  Future<bool> canSchedulePrecisely() async => true;
  @override
  Future<String> configureTimezone() async => 'Asia/Dhaka';
  @override
  Future<Set<int>?> pendingNotificationIds() async => {...pending};
  @override
  Future<void> schedule(
    ReminderSchedule reminder, {
    required bool precise,
  }) async {
    scheduledCalls.add(reminder);
    pending.add(reminder.notificationId);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    pending.remove(notificationId);
  }

  @override
  Future<void> showRemote({
    required String title,
    required String body,
    String? payload,
  }) async {}
}

final class _Push implements PushMessagingGateway {
  @override
  bool get isAvailable => true;
  @override
  Future<void> requestPermission() async {}
  @override
  Future<String?> getToken() async => 'token';
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<RemotePushMessage> get foregroundMessages => const Stream.empty();
  @override
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();
  @override
  Future<RemotePushMessage?> getInitialMessage() async => null;
  @override
  Future<void> deleteToken() async {}
}

final class _State implements NotificationStateStore {
  bool enabled = true;
  Set<int> ids = {};
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
  @override
  Future<String> getOrCreateInstallationId() async => 'installation';
  @override
  Future<Set<int>> scheduledNotificationIds() async => {...ids};
  @override
  Future<void> setScheduledNotificationIds(Iterable<int> values) async =>
      ids = values.toSet();
}

int _idOf(String taskId) => stableNotificationId('care:$taskId');

void main() {
  final now = DateTime(2026, 11, 20, 8);
  late _Repo repo;
  late _Local local;
  late _State state;
  late String? activeId;
  late NotificationCoordinator coordinator;

  setUp(() {
    repo = _Repo()
      ..tasksByPatient['p-a'] = [
        _task('a1', 'p-a', DateTime(2026, 11, 20, 9)),
        _task('a2', 'p-a', DateTime(2026, 11, 20, 10)),
      ]
      ..tasksByPatient['p-b'] = [
        _task('b1', 'p-b', DateTime(2026, 11, 20, 11)),
      ];
    local = _Local();
    state = _State();
    activeId = 'p-a';
    coordinator = NotificationCoordinator(
      repo,
      local,
      _Push(),
      state,
      platform: 'android',
      now: () => now,
      activePatientId: () async => activeId,
    );
  });

  tearDown(() => coordinator.dispose());

  test(
    'sync loads reminders and registers the device for the active profile',
    () async {
      await coordinator.syncIfEnabled();
      expect(repo.requestedFor, ['p-a']);
      expect(repo.registeredFor, ['p-a']);
      expect(local.pending, {_idOf('a1'), _idOf('a2')});
    },
  );

  test('switching cancels the previous profile\'s reminders and schedules the new ones', () async {
    await coordinator.syncIfEnabled();

    activeId = 'p-b';
    await coordinator.resyncForActiveProfile();

    expect(local.pending, {_idOf('b1')});
    expect(local.cancelled, containsAll([_idOf('a1'), _idOf('a2')]));
    // Device re-registered with the new patient id.
    expect(repo.registeredFor, ['p-a', 'p-b']);
    expect(state.ids, {_idOf('b1')});
  });

  test('repeated switches never duplicate reminders', () async {
    await coordinator.syncIfEnabled();
    for (final next in ['p-b', 'p-a', 'p-b', 'p-a']) {
      activeId = next;
      await coordinator.resyncForActiveProfile();
    }
    expect(local.pending, {_idOf('a1'), _idOf('a2')});
    // Every notification id is held at most once by the OS.
    expect(local.pending.length, 2);
    expect(state.ids, {_idOf('a1'), _idOf('a2')});
  });

  test(
    'a refresh still loading for the old profile cannot overwrite the new one',
    () async {
      repo
        ..gatedPatient = 'p-a'
        ..gateFor = Completer<void>();

      final oldRefresh = coordinator.syncIfEnabled();
      await Future<void>.delayed(Duration.zero);

      // The person switches while A's request is still in flight.
      activeId = 'p-b';
      final switched = coordinator.resyncForActiveProfile();
      repo.gateFor!.complete();
      await oldRefresh;
      await switched;

      expect(local.pending, {_idOf('b1')});
      expect(
        local.scheduledCalls.map((r) => r.taskId),
        isNot(contains('a1')),
        reason: 'A\'s reminders must never be scheduled after the switch',
      );
      expect(repo.registeredFor, ['p-b']);
    },
  );

  test(
    'reminder copy and payload stay generic, with no profile identity',
    () async {
      await coordinator.syncIfEnabled();
      for (final reminder in local.scheduledCalls) {
        expect(reminder.title, 'সুকুন লাইফ');
        expect(reminder.payload, 'care_task:${reminder.taskId}');
        expect(reminder.payload.contains('p-a'), isFalse);
        expect(reminder.body.contains('p-a'), isFalse);
      }
    },
  );

  testWidgets(
    'the app-level effect resyncs reminders when a profile is chosen',
    (tester) async {
      final localGateway = _Local();
      final repository = _Repo()
        ..tasksByPatient.addAll({
          'p-owner': [_task('o1', 'p-owner', DateTime(2026, 11, 20, 9))],
          'p-spouse': [_task('s1', 'p-spouse', DateTime(2026, 11, 20, 12))],
        });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...familyOverrides([
              profile('p-owner', 'Rahim', primary: true),
              profile('p-spouse', 'Amina', relationship: 'স্ত্রী', order: 1),
            ]),
            notificationCoordinatorProvider.overrideWith(
              (ref) => NotificationCoordinator(
                repository,
                localGateway,
                _Push(),
                _State(),
                platform: 'android',
                now: () => now,
                activePatientId: ref.read(activePatientIdReaderProvider),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ActiveProfileEffects(child: SizedBox()),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      // First load scheduled the owner's reminders.
      expect(localGateway.pending, {_idOf('o1')});
      expect(repository.registeredFor, ['p-owner']);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox)),
      );
      await tester.runAsync(
        () => container.read(activeProfileProvider.notifier).select('p-spouse'),
      );
      // Provider notifications and the resync chain interleave fake and
      // real time; give both a few turns to settle.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(localGateway.pending, {_idOf('s1')});
      expect(repository.registeredFor, ['p-owner', 'p-spouse']);
    },
  );
}
