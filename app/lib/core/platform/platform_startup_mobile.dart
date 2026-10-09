import 'package:just_audio_background/just_audio_background.dart';

Future<void> initializePlatformServices() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.sukunlife.app.audio',
    androidNotificationChannelName: 'Sukun Life audio playback',
    androidNotificationOngoing: true,
  );
}
