import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sleep timer only allows reviewed pause intervals', () {
    expect(AudioPlaybackController.supportedSleepMinutes, [0, 5, 15, 30, 60]);
  });

  test('3 or 4 sequential playlist tracks define safe stop boundaries', () {
    expect(
      playlistTrackLimitReached(startIndex: 0, currentIndex: 2, tracks: 3),
      isFalse,
    );
    expect(
      playlistTrackLimitReached(startIndex: 0, currentIndex: 3, tracks: 3),
      isTrue,
    );
    expect(
      playlistTrackLimitReached(startIndex: 1, currentIndex: 4, tracks: 4),
      isFalse,
    );
    expect(
      playlistTrackLimitReached(startIndex: 1, currentIndex: 5, tracks: 4),
      isTrue,
    );
    expect(
      playlistTrackLimitReached(startIndex: 1, currentIndex: 6, tracks: 0),
      isFalse,
    );
  });

  test('switching between audio resources requires a new source load', () {
    const first = LinkedResource(
      id: 'ruqyahbd-eight-surah',
      title: 'আট সুরা',
      type: 'audio',
      mediaSourceType: 'direct_audio_url',
      mediaUrl:
          'https://files.ruqyahbd.org/audio/Ruqyah-8surah-ruqyahbd.org.mp3',
    );
    const second = LinkedResource(
      id: 'ruqyahbd-three-kul',
      title: 'তিনকুল',
      type: 'audio',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://files.ruqyahbd.org/audio/Ruqyah-3Kul-ruqyahbd.org.mp3',
    );
    const wrongUrl = LinkedResource(
      id: 'ruqyahbd-three-kul',
      title: 'তিনকুল',
      type: 'audio',
      mediaSourceType: 'direct_audio_url',
      mediaUrl:
          'https://files.ruqyahbd.org/audio/Ruqyah-8surah-ruqyahbd.org.mp3',
    );

    expect(audioResourceNeedsReload(null, first), isTrue);
    expect(audioResourceNeedsReload(first, second), isTrue);
    expect(audioResourceNeedsReload(second, first), isTrue);
    expect(audioResourceNeedsReload(second, wrongUrl), isTrue);
    expect(audioResourceNeedsReload(first, first), isFalse);
  });

  test('playback position store persists and clears resume position', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesPlaybackPositionStore();

    expect(await store.read('audio-1'), isNull);

    await store.write('audio-1', const Duration(seconds: 73));
    expect(await store.read('audio-1'), const Duration(seconds: 73));

    await store.clear('audio-1');
    expect(await store.read('audio-1'), isNull);
  });
}
