import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.sukunlife.app.audio',
    androidNotificationChannelName: 'Sukun Life audio playback',
    androidNotificationOngoing: true,
  );
  await AppEnvironment.initialize();
  runApp(const ProviderScope(child: SukunLifeApp()));
}
