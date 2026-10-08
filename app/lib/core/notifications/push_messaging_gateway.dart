import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class RemotePushMessage {
  const RemotePushMessage({
    required this.type,
    required this.title,
    required this.body,
  });

  final String? type;
  final String title;
  final String body;
}

abstract interface class PushMessagingGateway {
  bool get isAvailable;
  Future<void> requestPermission();
  Future<String?> getToken();
  Stream<String> get tokenRefresh;
  Stream<RemotePushMessage> get foregroundMessages;
  Stream<RemotePushMessage> get openedMessages;
  Future<RemotePushMessage?> getInitialMessage();
  Future<void> deleteToken();
}

final class FirebasePushMessagingGateway implements PushMessagingGateway {
  FirebasePushMessagingGateway({required this.isAvailable});

  @override
  final bool isAvailable;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<void> requestPermission() async {
    if (!isAvailable) return;
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  @override
  Future<String?> getToken() async {
    if (!isAvailable) return null;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        await _messaging.getAPNSToken() == null) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Stream<String> get tokenRefresh =>
      isAvailable ? _messaging.onTokenRefresh : const Stream.empty();

  @override
  Stream<RemotePushMessage> get foregroundMessages => isAvailable
      ? FirebaseMessaging.onMessage.map(_mapMessage)
      : const Stream.empty();

  @override
  Stream<RemotePushMessage> get openedMessages => isAvailable
      ? FirebaseMessaging.onMessageOpenedApp.map(_mapMessage)
      : const Stream.empty();

  @override
  Future<RemotePushMessage?> getInitialMessage() async {
    if (!isAvailable) return null;
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _mapMessage(message);
  }

  @override
  Future<void> deleteToken() async {
    if (isAvailable) await _messaging.deleteToken();
  }
}

RemotePushMessage _mapMessage(RemoteMessage message) => RemotePushMessage(
  type: message.data['type'] as String?,
  title: message.notification?.title ?? 'Sukun Life',
  body: message.notification?.body ?? 'Your care plan has been updated.',
);
