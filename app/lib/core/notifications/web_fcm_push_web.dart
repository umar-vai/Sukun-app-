// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';

import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';

@JS('sukunWebPush')
external JSObject? get _sukunPushBridge;
@JS('sukunWebPush.isAvailable')
external JSBoolean _pushAvailable();
@JS('sukunWebPush.getToken')
external JSPromise<JSString?> _requestPushToken();
@JS('sukunWebPush.deleteToken')
external JSPromise<JSAny?> _removePushToken();

/// Optional, scoped FCM client. Does not initialize native Firebase on Web.
final class WebFirebasePushMessagingGateway implements PushMessagingGateway {
  WebFirebasePushMessagingGateway();

  @override
  bool get isAvailable =>
      _sukunPushBridge != null && _pushAvailable().toDart;

  @override
  Future<void> requestPermission() async {
    // Browser local-notification consent is already requested by coordinator.
  }

  @override
  Future<String?> getToken() async {
    if (!isAvailable) return null;
    final token = await _requestPushToken().toDart;
    final value = token?.toDart;
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<RemotePushMessage> get foregroundMessages {
    if (!isAvailable) return const Stream.empty();
    return html.window.on['sukun-web-push-message'].map((event) {
      final raw = (event as html.CustomEvent).detail;
      final data = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : <String, dynamic>{};
      return RemotePushMessage(
        type: data['type'] as String?,
        taskId: data['task_id'] as String?,
        title: 'Sukun Life',
        body: 'Your care reminder is ready.',
      );
    });
  }

  @override
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();

  @override
  Future<RemotePushMessage?> getInitialMessage() async => null;

  @override
  Future<void> deleteToken() async {
    if (!isAvailable) return;
    await _removePushToken().toDart;
  }
}
