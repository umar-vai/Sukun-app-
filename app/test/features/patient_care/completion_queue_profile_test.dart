import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/data/completion_queue_store.dart';
import 'package:sukun_life/features/patient_care/data/task_completion_coordinator.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/domain/pending_task_completion.dart';

PatientTask _task(String id, String patientId) => PatientTask(
  id: id,
  patientId: patientId,
  occurrenceDate: DateTime(2026, 11, 20),
  status: PatientTaskStatus.pending,
  action: PlanAction(
    id: 'action-$id',
    carePlanId: 'plan-$patientId',
    type: 'recitation',
    title: 'Action $id',
    frequency: const ActionFrequency.daily(),
    startDate: DateTime(2026, 11, 1),
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: false,
  ),
);

PendingTaskCompletion _event(
  String taskId,
  String? patientId,
  String eventId, {
  String userId = 'login-1',
}) => PendingTaskCompletion(
  userId: userId,
  patientId: patientId,
  taskId: taskId,
  status: PatientTaskStatus.completed,
  clientEventId: eventId,
  occurredAt: DateTime.utc(2026, 11, 20, 8),
);

final class _Remote implements TaskCompletionRemote {
  final List<PendingTaskCompletion> submitted = [];
  bool offline = true;

  @override
  Future<void> submit(PendingTaskCompletion event) async {
    submitted.add(event);
    if (offline) {
      throw const TaskCompletionSyncException('offline', retryable: true);
    }
  }
}

final class _MemoryStore implements CompletionQueueStore {
  final List<PendingTaskCompletion> events = [];

  @override
  Future<void> enqueue(PendingTaskCompletion event) async {
    final next = stagePendingCompletion(events, event);
    events
      ..clear()
      ..addAll(next);
  }

  @override
  Future<List<PendingTaskCompletion>> readForPatient(
    String userId,
    String patientId,
  ) async => events.where((e) => e.belongsTo(userId, patientId)).toList();

  @override
  Future<void> remove(String userId, String clientEventId) async =>
      events.removeWhere(
        (e) => e.userId == userId && e.clientEventId == clientEventId,
      );
}

void main() {
  group('offline queue is keyed by patient profile', () {
    test('events carry the task\'s own patient id and round-trip JSON', () {
      final event = _event('t1', 'p-a', 'e1');
      expect(event.toJson()['patient_id'], 'p-a');
      expect(PendingTaskCompletion.fromJson(event.toJson()).patientId, 'p-a');
    });

    test('staging never coalesces the same task id across profiles', () {
      final staged = stagePendingCompletion([
        _event('same-task', 'p-a', 'a1'),
      ], _event('same-task', 'p-b', 'b1'));
      expect(staged.map((e) => e.clientEventId), ['a1', 'b1']);
      final replaced = stagePendingCompletion(
        staged,
        _event('same-task', 'p-a', 'a2'),
      );
      expect(replaced.map((e) => e.clientEventId), ['b1', 'a2']);
    });

    test(
      'a switch never moves one person\'s pending task to another',
      () async {
        final store = _MemoryStore();
        final remote = _Remote();
        final coordinator = TaskCompletionCoordinator(
          store: store,
          remote: remote,
        );

        // Offline: profile A completes their task.
        final taskA = _task('task-a', 'p-a');
        final saved = await coordinator.record(
          userId: 'login-1',
          task: taskA,
          status: PatientTaskStatus.completed,
          clientEventId: 'event-a',
          occurredAt: DateTime.utc(2026, 11, 20, 8),
        );
        expect(saved.isPendingSync, isTrue);
        expect(store.events.single.patientId, 'p-a');

        // Switch to B and come online: B's flush must not touch A's event.
        remote
          ..offline = false
          ..submitted.clear();
        await coordinator.flush('login-1', 'p-b');
        expect(remote.submitted, isEmpty);
        expect(await store.readForPatient('login-1', 'p-b'), isEmpty);
        expect(await store.readForPatient('login-1', 'p-a'), hasLength(1));

        // B's screen shows B's tasks unchanged.
        final dayB = PatientDay(tasks: [_task('task-b', 'p-b')]);
        final shownB = await coordinator.applyPending('login-1', 'p-b', dayB);
        expect(shownB.tasks.single.status, PatientTaskStatus.pending);
        expect(shownB.tasks.single.isPendingSync, isFalse);

        // A's screen shows A's pending completion.
        final dayA = PatientDay(tasks: [taskA]);
        final shownA = await coordinator.applyPending('login-1', 'p-a', dayA);
        expect(shownA.tasks.single.status, PatientTaskStatus.completed);
        expect(shownA.tasks.single.isPendingSync, isTrue);

        // Back on A: the original event id is replayed once and cleared.
        await coordinator.flush('login-1', 'p-a');
        expect(remote.submitted.map((e) => e.clientEventId), ['event-a']);
        expect(store.events, isEmpty);
      },
    );

    test('another login on the same device never sees these events', () async {
      final store = _MemoryStore()
        ..events.add(_event('t1', 'p-a', 'e1', userId: 'login-1'));
      expect(await store.readForPatient('login-2', 'p-a'), isEmpty);
    });

    test(
      'legacy unscoped events only ever apply to the task they name',
      () async {
        final store = _MemoryStore()
          ..events.add(_event('old-task', null, 'old'));
        final coordinator = TaskCompletionCoordinator(
          store: store,
          remote: _Remote()..offline = false,
        );
        final day = PatientDay(tasks: [_task('task-b', 'p-b')]);
        final shown = await coordinator.applyPending('login-1', 'p-b', day);
        expect(shown.tasks.single.status, PatientTaskStatus.pending);
        final owner = PatientDay(tasks: [_task('old-task', 'p-a')]);
        final shownOwner = await coordinator.applyPending(
          'login-1',
          'p-a',
          owner,
        );
        expect(shownOwner.tasks.single.status, PatientTaskStatus.completed);
      },
    );

    test(
      'secure storage keeps profiles apart and reads pre-family data',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          // Written by the app before family accounts: no patient_id key.
          'sukun.pending_task_completions.v1':
              '[{"user_id":"login-1","task_id":"legacy","status":"completed",'
              '"client_event_id":"legacy-event","occurred_at":"2026-11-20T08:00:00.000Z"}]',
        });
        final store = SecureCompletionQueueStore();
        await store.enqueue(_event('task-a', 'p-a', 'a1'));
        await store.enqueue(_event('task-b', 'p-b', 'b1'));

        final forA = await store.readForPatient('login-1', 'p-a');
        final forB = await store.readForPatient('login-1', 'p-b');
        expect(forA.map((e) => e.clientEventId), ['legacy-event', 'a1']);
        expect(forB.map((e) => e.clientEventId), ['legacy-event', 'b1']);
        expect(await store.readForPatient('login-2', 'p-a'), isEmpty);

        await store.remove('login-1', 'a1');
        expect(
          (await store.readForPatient(
            'login-1',
            'p-a',
          )).map((e) => e.clientEventId),
          ['legacy-event'],
        );
        expect(
          (await store.readForPatient(
            'login-1',
            'p-b',
          )).map((e) => e.clientEventId),
          ['legacy-event', 'b1'],
        );
      },
    );
  });
}
