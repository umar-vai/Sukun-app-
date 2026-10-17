import 'dart:async';

/// Carries only verified task/action identifiers, never untrusted URLs.
String? careTaskIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('care_task:')) return null;
  final id = payload.substring('care_task:'.length);
  return _validId(id);
}

String patientTodayTaskRoute(String taskId) =>
    Uri(path: '/patient/today', queryParameters: {'task': taskId}).toString();

String? personalActionIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('personal_action:')) return null;
  final id = payload.substring('personal_action:'.length);
  return _validId(id);
}

String? _validId(String value) {
  const pattern =
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' +
      r'$';
  return RegExp(pattern).hasMatch(value) ? value.toLowerCase() : null;
}

String personalActionRoute(String actionId) =>
    Uri(pathSegments: ['', 'my-routines', 'action', actionId]).toString();

final class NotificationTapRelay {
  final StreamController<String> _opened = StreamController<String>.broadcast();
  final StreamController<String> _openedPersonal =
      StreamController<String>.broadcast();
  String? _pending;
  String? _pendingPersonal;

  Stream<String> get openedTaskIds => _opened.stream;
  Stream<String> get openedPersonalActionIds => _openedPersonal.stream;

  void accept(String? payload) {
    final taskId = careTaskIdFromPayload(payload);
    if (taskId != null) {
      _pending = taskId;
      _opened.add(taskId);
      return;
    }
    final actionId = personalActionIdFromPayload(payload);
    if (actionId != null) {
      _pendingPersonal = actionId;
      _openedPersonal.add(actionId);
    }
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
