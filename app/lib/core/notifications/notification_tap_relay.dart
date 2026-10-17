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

String patientTodayTaskRoute(String taskId) =>
    Uri(path: '/patient/today', queryParameters: {'task': taskId}).toString();

String? personalActionIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('personal_action:')) return null;
  final id = payload.substring('personal_action:'.length);
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}
  final StreamController<String> _opened = StreamController<String>.broadcast();
  String? _pending;
  String? _pendingPersonal;
  final StreamController<String> _openedPersonal = StreamController<String>.broadcast();
  Stream<String> get openedPersonalActionIds => _openedPersonal.stream;

  Stream<String> get openedTaskIds => _opened.stream;

  void accept(String? payload) {
    final taskId = careTaskIdFromPayload(payload);
    if (taskId == null) {
      final actionId = personalActionIdFromPayload(payload);
      if (actionId != null) {
        _pendingPersonal = actionId;
        _openedPersonal.add(actionId);
      }
      return;
    }
    _pending = taskId;
    _opened.add(taskId);
  }

  String? takePending() {
    final current = _pending;
    _pending = null;
    return current;
  }

  String? takePendingPersonalAction() {
    final current = _pendingPersonal;
    _pendingPersonal = null;
    return current;
  }

  void dispose() {
    _opened.close();
    _openedPersonal.close();
  }
}
,
  );
  return uuid.hasMatch(id) ? id.toLowerCase() : null;
}

String personalActionRoute(String actionId) =>
    '/my-routines/action/${Uri.encodeComponent(actionId)}';

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
