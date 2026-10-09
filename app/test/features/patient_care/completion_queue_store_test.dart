import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/patient_care/data/completion_queue_store.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/domain/pending_task_completion.dart';

void main() {
  PendingTaskCompletion event(
    String userId,
    String taskId,
    String clientEventId, {
    PatientTaskStatus status = PatientTaskStatus.snoozed,
  }) => PendingTaskCompletion(
    userId: userId,
    taskId: taskId,
    status: status,
    clientEventId: clientEventId,
    occurredAt: DateTime.utc(2026, 10, 10, 8),
  );

  test('supersedes stale pending statuses for the same patient task', () {
    final initial = [
      event('user-1', 'task-1', 'snooze'),
      event('user-1', 'task-2', 'another'),
    ];
    final updated = stagePendingCompletion(
      initial,
      event('user-1', 'task-1', 'done', status: PatientTaskStatus.completed),
    );

    expect(updated.map((value) => value.clientEventId), ['another', 'done']);
    expect(initial.map((value) => value.clientEventId), ['snooze', 'another']);
  });

  test(
    'same event ID does not add a duplicate while preserving retry identity',
    () {
      final original = event('user-1', 'task-1', 'once');
      final updated = stagePendingCompletion([original], original);

      expect(updated, hasLength(1));
      expect(updated.single.clientEventId, 'once');
    },
  );

  test('different patients and tasks cannot replace one another', () {
    final existing = [
      event('user-2', 'shared-task', 'other-user'),
      event('user-1', 'different-task', 'other-task'),
    ];
    final updated = stagePendingCompletion(
      existing,
      event('user-1', 'shared-task', 'current'),
    );

    expect(updated.map((value) => value.clientEventId), [
      'other-user',
      'other-task',
      'current',
    ]);
  });
}
