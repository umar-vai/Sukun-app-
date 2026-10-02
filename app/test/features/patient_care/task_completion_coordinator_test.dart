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
  final List<PendingTaskCompletion> submitted = [];

  @override
  Future<void> submit(PendingTaskCompletion event) async {
    submitted.add(event);
    if (retryableFailure) {
      throw const TaskCompletionSyncException('offline', retryable: true);
    }
  }
}

final class _MemoryCompletionQueueStore implements CompletionQueueStore {
  final List<PendingTaskCompletion> events = [];

  @override
  Future<void> enqueue(PendingTaskCompletion event) async {
    if (!events.any(
      (item) =>
          item.userId == event.userId &&
          item.clientEventId == event.clientEventId,
    )) {
      events.add(event);
    }
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
