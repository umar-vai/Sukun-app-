import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';

/// Browser-only implementation is conditionally imported on Web.
final class WebFirebasePushMessagingGateway implements PushMessagingGateway {
  const WebFirebasePushMessagingGateway();

  @override
  bool get isAvailable => false;
  @override
  Future<void> requestPermission() async {}
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<RemotePushMessage> get foregroundMessages => const Stream.empty();
  @override
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();
  @override
  Future<RemotePushMessage?> getInitialMessage() async => null;
  @override
  Future<void> deleteToken() async {}
}
