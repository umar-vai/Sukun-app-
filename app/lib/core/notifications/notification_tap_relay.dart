import 'dart:async';

/// Carries only a task identifier, never patient text or an untrusted URL.
/// The protected Patient Today route resolves the task through its own RLS
/// query before showing any linked resource.
String? careTaskIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('care_task:')) return null;
  final id = payload.substring('care_task:'.length);
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  return uuid.hasMatch(id) ? id.toLowerCase() : null;
}

String patientTodayTaskRoute(String taskId) => Uri(
  path: '/patient/today',
  queryParameters: {'task': taskId},
).toString();

final class NotificationTapRelay {
  final StreamController<String> _opened = StreamController<String>.broadcast();
  String? _pending;

  Stream<String> get openedTaskIds => _opened.stream;

  void accept(String? payload) {
    final taskId = careTaskIdFromPayload(payload);
    if (taskId == null) return;
    _pending = taskId;
    _opened.add(taskId);
  }

  String? takePending() {
    final current = _pending;
    _pending = null;
    return current;
  }

  void dispose() => _opened.close();
}
