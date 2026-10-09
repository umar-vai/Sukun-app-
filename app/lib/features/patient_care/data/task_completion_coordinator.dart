import 'package:sukun_life/features/patient_care/data/completion_queue_store.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/domain/pending_task_completion.dart';

abstract interface class TaskCompletionRemote {
  Future<void> submit(PendingTaskCompletion event);
}

class TaskCompletionSyncException implements Exception {
  const TaskCompletionSyncException(this.message, {required this.retryable});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

final class TaskCompletionCoordinator {
  const TaskCompletionCoordinator({required this.store, required this.remote});

  final CompletionQueueStore store;
  final TaskCompletionRemote remote;

  Future<PatientTask> record({
    required String userId,
    required PatientTask task,
    required PatientTaskStatus status,
    required String clientEventId,
    required DateTime occurredAt,
    DateTime? snoozedUntil,
    String? skipReason,
  }) async {
    final event = PendingTaskCompletion(
      userId: userId,
      taskId: task.id,
      status: status,
      clientEventId: clientEventId,
      occurredAt: occurredAt,
      snoozedUntil: snoozedUntil,
      skipReason: skipReason,
    );
    await store.enqueue(event);
    try {
      await remote.submit(event);
      await store.remove(userId, clientEventId);
      return event.applyTo(task, pendingSync: false);
    } on TaskCompletionSyncException catch (error) {
      if (!error.retryable) {
        await store.remove(userId, clientEventId);
        rethrow;
      }
      return event.applyTo(task, pendingSync: true);
    }
  }

  Future<void> flush(String userId) async {
    final events = await store.readForUser(userId);
    for (final event in events) {
      // An updated action may supersede an item captured in this snapshot.
      // Avoid replaying a stale snooze after a newer completion was queued.
      final remaining = await store.readForUser(userId);
      if (!remaining.any((item) => item.clientEventId == event.clientEventId)) {
        continue;
      }
      try {
        await remote.submit(event);
        await store.remove(userId, event.clientEventId);
      } on TaskCompletionSyncException {
        // Keep the write-ahead event intact. A later refresh/app launch retries it.
        break;
      }
    }
  }

  Future<PatientDay> applyPending(String userId, PatientDay day) async {
    final events = await store.readForUser(userId);
    final latestByTask = <String, PendingTaskCompletion>{};
    for (final event in events) {
      final current = latestByTask[event.taskId];
      if (current == null || current.occurredAt.isBefore(event.occurredAt)) {
        latestByTask[event.taskId] = event;
      }
    }
    return PatientDay(
      activePlan: day.activePlan,
      tasks: [
        for (final task in day.tasks)
          latestByTask[task.id]?.applyTo(task, pendingSync: true) ?? task,
      ],
    );
  }
}
