import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sukun_life/features/patient_care/domain/pending_task_completion.dart';

abstract interface class CompletionQueueStore {
  Future<List<PendingTaskCompletion>> readForUser(String userId);

  Future<void> enqueue(PendingTaskCompletion event);

  Future<void> remove(String userId, String clientEventId);
}

/// Preserve the last offline intention for a patient task.
///
/// The server deduplicates identical client event IDs. Distinct offline
/// updates to the *same* task must not replay a stale snooze after a newer
/// completion. Never coalesce another patient's task or another task ID.
List<PendingTaskCompletion> stagePendingCompletion(
  List<PendingTaskCompletion> queued,
  PendingTaskCompletion next,
) {
  if (queued.any(
    (item) =>
        item.userId == next.userId &&
        item.clientEventId == next.clientEventId,
  )) {
    return List<PendingTaskCompletion>.of(queued);
  }
  return [
    for (final item in queued)
      if (item.userId != next.userId || item.taskId != next.taskId) item,
    next,
  ];
}

final class SecureCompletionQueueStore implements CompletionQueueStore {
  SecureCompletionQueueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'sukun.pending_task_completions.v1';
  final FlutterSecureStorage _storage;

  // Storage uses read-modify-write. Serialize operations within this store
  // instance so rapid updates from separate tasks cannot overwrite each other.
  Future<void> _lastMutation = Future<void>.value();

  Future<void> _mutate(Future<void> Function() operation) {
    final result = _lastMutation.then((_) => operation());
    _lastMutation = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<List<PendingTaskCompletion>> readForUser(String userId) async {
    await _lastMutation;
    final events = await _readAll();
    return events
        .where((event) => event.userId == userId)
        .toList(growable: false);
  }

  @override
  Future<void> enqueue(PendingTaskCompletion event) => _mutate(() async {
    final events = await _readAll();
    await _writeAll(stagePendingCompletion(events, event));
  });

  @override
  Future<void> remove(String userId, String clientEventId) => _mutate(
    () async {
      final events = await _readAll();
      events.removeWhere(
        (event) =>
            event.userId == userId && event.clientEventId == clientEventId,
      );
      await _writeAll(events);
    },
  );

  Future<List<PendingTaskCompletion>> _readAll() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .map(
            (item) => PendingTaskCompletion.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on Object catch (error) {
      throw CompletionQueueStorageException(
        'Saved offline updates could not be read safely.',
        error,
      );
    }
  }

  Future<void> _writeAll(List<PendingTaskCompletion> events) {
    return _storage.write(
      key: _storageKey,
      value: jsonEncode(events.map((event) => event.toJson()).toList()),
    );
  }
}

class CompletionQueueStorageException implements Exception {
  const CompletionQueueStorageException(this.message, this.cause);

  final String message;
  final Object cause;

  @override
  String toString() => message;
}
