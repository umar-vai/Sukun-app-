import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:just_audio_background/just_audio_background.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppEnvironment.isFirebaseConfigured) return;
  if (Firebase.apps.isEmpty) {
    await AppEnvironment.initialize();
  }
  if (message.data['type'] == 'plan_updated') {
    final container = ProviderContainer();
    try {
      await container.read(notificationCoordinatorProvider).syncIfEnabled();
    } finally {
      container.dispose();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.sukunlife.app.audio',
    androidNotificationChannelName: 'Sukun Life audio playback',
    androidNotificationOngoing: true,
  );
  await AppEnvironment.initialize();
  if (AppEnvironment.isFirebaseConfigured) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: SukunLifeApp()));
}
