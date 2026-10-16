// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js;

import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';

/// Optional Firebase Web client. It cannot activate without a fully vetted
/// public Firebase configuration and verified server-side sender/scheduler.
final class WebFirebasePushMessagingGateway implements PushMessagingGateway {
  WebFirebasePushMessagingGateway();

  Object? get _bridge => js.hasProperty(js.globalThis, 'sukunWebPush')
      ? js.getProperty<Object?>(js.globalThis, 'sukunWebPush')
      : null;

  @override
  bool get isAvailable {
    final bridge = _bridge;
    if (bridge == null) return false;
    return js.callMethod<bool>(bridge, 'isAvailable', []);
  }

  @override
  Future<void> requestPermission() async {
    // Local Web Notifications already acquired explicit browser permission.
    // Token registration remains separately guarded by .isAvailable.
  }

  @override
  Future<String?> getToken() async {
    if (!isAvailable) return null;
    final bridge = _bridge;
    if (bridge == null) return null;
    final promise = js.callMethod<Object>(bridge, 'getToken', []);
    final result = await js.promiseToFuture<Object?>(promise);
    return result is String && result.isNotEmpty ? result : null;
  }

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<RemotePushMessage> get foregroundMessages {
    if (!isAvailable) return const Stream.empty();
    return html.window.on['sukun-web-push-message'].map((event) {
      final data = (event as html.CustomEvent).detail;
      final detail = data == null
          ? null
          : js.dartify(data) as Map<Object?, Object?>?;
      return RemotePushMessage(
        type: detail?['type'] as String?,
        taskId: detail?['task_id'] as String?,
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
    final bridge = _bridge;
    if (bridge == null || !isAvailable) return;
    await js.promiseToFuture<Object>(
      js.callMethod<Object>(bridge, 'deleteToken', []),
    );
  }
}
