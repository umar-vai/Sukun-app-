import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sukun_life/features/patient_care/domain/pending_task_completion.dart';

abstract interface class CompletionQueueStore {
  Future<List<PendingTaskCompletion>> readForUser(String userId);

  Future<void> enqueue(PendingTaskCompletion event);

  Future<void> remove(String userId, String clientEventId);
}

final class SecureCompletionQueueStore implements CompletionQueueStore {
  SecureCompletionQueueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'sukun.pending_task_completions.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<PendingTaskCompletion>> readForUser(String userId) async {
    final events = await _readAll();
    return events
        .where((event) => event.userId == userId)
        .toList(growable: false);
  }

  @override
  Future<void> enqueue(PendingTaskCompletion event) async {
    final events = await _readAll();
    final exists = events.any(
      (item) =>
          item.userId == event.userId &&
          item.clientEventId == event.clientEventId,
    );
    if (!exists) events.add(event);
    await _writeAll(events);
  }

  @override
  Future<void> remove(String userId, String clientEventId) async {
    final events = await _readAll();
    events.removeWhere(
      (event) => event.userId == userId && event.clientEventId == clientEventId,
    );
    await _writeAll(events);
  }

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
