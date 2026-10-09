import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/data/completion_queue_store.dart';
import 'package:sukun_life/features/patient_care/data/task_completion_coordinator.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/domain/pending_task_completion.dart';

void main() {
  test(
    'keeps a write-ahead event offline and flushes it with the same id',
    () async {
      final store = _MemoryCompletionQueueStore();
      final remote = _FakeCompletionRemote()..retryableFailure = true;
      final coordinator = TaskCompletionCoordinator(
        store: store,
        remote: remote,
      );
      final task = _task();

      final updated = await coordinator.record(
        userId: 'user-1',
        task: task,
        status: PatientTaskStatus.completed,
        clientEventId: 'event-1',
        occurredAt: DateTime.utc(2026, 10, 2, 10),
      );

      expect(updated.status, PatientTaskStatus.completed);
      expect(updated.isPendingSync, isTrue);
      expect(await store.readForUser('user-1'), hasLength(1));

      remote.retryableFailure = false;
      await coordinator.flush('user-1');

      expect(await store.readForUser('user-1'), isEmpty);
      expect(remote.submitted.map((event) => event.clientEventId), [
        'event-1',
        'event-1',
      ]);
    },
  );

  test('does not let one account flush another account queue', () async {
    final store = _MemoryCompletionQueueStore();
    final remote = _FakeCompletionRemote()..retryableFailure = true;
    final coordinator = TaskCompletionCoordinator(store: store, remote: remote);

    await coordinator.record(
      userId: 'user-1',
      task: _task(),
      status: PatientTaskStatus.skipped,
      clientEventId: 'event-user-1',
      occurredAt: DateTime.utc(2026, 10, 2, 10),
    );
    remote
      ..retryableFailure = false
      ..submitted.clear();

    await coordinator.flush('user-2');

    expect(remote.submitted, isEmpty);
    expect(await store.readForUser('user-1'), hasLength(1));
  });
  test(
    'offline snooze followed by Done only replays the latest task event',
    () async {
      final store = _MemoryCompletionQueueStore();
      final remote = _FakeCompletionRemote()..retryableFailure = true;
      final coordinator = TaskCompletionCoordinator(
        store: store,
        remote: remote,
      );
      final task = _task();
      final occurredAt = DateTime.utc(2026, 10, 10, 7);

      await coordinator.record(
        userId: 'user-1',
        task: task,
        status: PatientTaskStatus.snoozed,
        clientEventId: 'event-snooze',
        occurredAt: occurredAt,
        snoozedUntil: occurredAt.add(const Duration(minutes: 15)),
      );
      final updated = await coordinator.record(
        userId: 'user-1',
        task: task,
        status: PatientTaskStatus.completed,
        clientEventId: 'event-done',
        occurredAt: occurredAt.add(const Duration(minutes: 2)),
      );

      expect(updated.status, PatientTaskStatus.completed);
      expect(updated.isPendingSync, isTrue);
      expect(
        (await store.readForUser('user-1')).map((event) => event.clientEventId),
        ['event-done'],
      );
      remote
        ..submitted.clear()
        ..retryableFailure = false;
      await coordinator.flush('user-1');
      expect(remote.submitted.map((event) => event.clientEventId), [
        'event-done',
      ]);
      expect(await store.readForUser('user-1'), isEmpty);
    },
  );

  test(
    'same task identifier in a different patient queue is isolated',
    () async {
      final store = _MemoryCompletionQueueStore();
      final remote = _FakeCompletionRemote()..retryableFailure = true;
      final coordinator = TaskCompletionCoordinator(
        store: store,
        remote: remote,
      );
      final task = _task();
      final occurredAt = DateTime.utc(2026, 10, 10, 8);

      for (final userId in ['user-1', 'user-2']) {
        await coordinator.record(
          userId: userId,
          task: task,
          status: PatientTaskStatus.snoozed,
          clientEventId: 'event-$userId',
          occurredAt: occurredAt,
          snoozedUntil: occurredAt.add(const Duration(minutes: 15)),
        );
      }
      expect(await store.readForUser('user-1'), hasLength(1));
      expect(await store.readForUser('user-2'), hasLength(1));

      remote
        ..submitted.clear()
        ..retryableFailure = false;
      await coordinator.flush('user-1');

      expect(remote.submitted.map((event) => event.userId), ['user-1']);
      expect(await store.readForUser('user-1'), isEmpty);
      expect(await store.readForUser('user-2'), hasLength(1));
    },
  );

  test(
    'flush ignores a queued task event superseded during another upload',
    () async {
      final store = _MemoryCompletionQueueStore();
      final remote = _FakeCompletionRemote();
      final coordinator = TaskCompletionCoordinator(
        store: store,
        remote: remote,
      );
      final when = DateTime.utc(2026, 10, 10, 9);

      await store.enqueue(
        PendingTaskCompletion(
          userId: 'user-1',
          taskId: 'task-1',
          status: PatientTaskStatus.completed,
          clientEventId: 'event-first',
          occurredAt: when,
        ),
      );
      await store.enqueue(
        PendingTaskCompletion(
          userId: 'user-1',
          taskId: 'task-2',
          status: PatientTaskStatus.snoozed,
          clientEventId: 'event-stale',
          occurredAt: when,
          snoozedUntil: when.add(const Duration(minutes: 15)),
        ),
      );
      remote.onSubmit = (event) async {
        if (event.clientEventId == 'event-first') {
          await store.enqueue(
            PendingTaskCompletion(
              userId: 'user-1',
              taskId: 'task-2',
              status: PatientTaskStatus.completed,
              clientEventId: 'event-new',
              occurredAt: when.add(const Duration(minutes: 2)),
            ),
          );
        }
      };

      await coordinator.flush('user-1');
      expect(remote.submitted.map((event) => event.clientEventId), [
        'event-first',
      ]);
      expect(
        (await store.readForUser('user-1')).map((event) => event.clientEventId),
        ['event-new'],
      );
    },
  );
}

PatientTask _task() {
  final action = PlanAction(
    id: 'action-1',
    carePlanId: 'plan-1',
    type: 'amal',
    title: 'Morning Amal',
    frequency: const ActionFrequency.daily(),
    startDate: DateTime(2026, 10, 1),
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: false,
  );
  return PatientTask(
    id: 'task-1',
    patientId: 'patient-1',
    occurrenceDate: DateTime(2026, 10, 2),
    status: PatientTaskStatus.pending,
    action: action,
  );
}

final class _FakeCompletionRemote implements TaskCompletionRemote {
  bool retryableFailure = false;
  Future<void> Function(PendingTaskCompletion)? onSubmit;
  final List<PendingTaskCompletion> submitted = [];

  @override
  Future<void> submit(PendingTaskCompletion event) async {
    submitted.add(event);
    await onSubmit?.call(event);
    if (retryableFailure) {
      throw const TaskCompletionSyncException('offline', retryable: true);
    }
  }
}

final class _MemoryCompletionQueueStore implements CompletionQueueStore {
  final List<PendingTaskCompletion> events = [];

  @override
  Future<void> enqueue(PendingTaskCompletion event) async {
    final next = stagePendingCompletion(events, event);
    events
      ..clear()
      ..addAll(next);
  }

  @override
  Future<List<PendingTaskCompletion>> readForUser(String userId) async =>
      events.where((event) => event.userId == userId).toList();

  @override
  Future<void> remove(String userId, String clientEventId) async {
    events.removeWhere(
      (event) => event.userId == userId && event.clientEventId == clientEventId,
    );
  }
}
