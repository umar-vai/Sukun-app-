import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/features/media_library/presentation/playlist_player_page.dart';

class _MemoryPositionStore implements PlaybackPositionStore {
  @override
  Future<Duration?> read(String resourceId) async => null;
  @override
  Future<void> write(String resourceId, Duration position) async {}
  @override
  Future<void> clear(String resourceId) async {}
}

void main() {
  test('cover adapts to narrow and wide first viewports', () {
    expect(playlistCoverHeight(360, 500), 140);
    expect(playlistCoverHeight(390, 700), 196);
    expect(playlistCoverHeight(500, 900), 200);
    expect(playlistCoverHeight(200, 500), 140);
  });

  test('playlist relative seek is bounded and never negative', () {
    expect(
      playlistSeekTarget(const Duration(seconds: 3),
          const Duration(seconds: 90), -10),
      Duration.zero,
    );
    expect(
      playlistSeekTarget(const Duration(seconds: 84),
          const Duration(seconds: 90), 10),
      const Duration(seconds: 90),
    );
  });

  test('elapsed and total formats preserve long recordings', () {
    expect(playlistDurationLabel(const Duration(seconds: 41)), '0:41');
    expect(playlistDurationLabel(const Duration(minutes: 99, seconds: 7)),
        '1:39:07');
  });

  testWidgets('focused playlist keeps playback tools above phone fold', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final audioPlayer = AudioPlayer();
    final controller = AudioPlaybackController(audioPlayer, _MemoryPositionStore());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlaybackControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: PlaylistPlayerPage()),
      ),
    );
    await tester.pump();
    for (final key in const <String>[
      'playlist-full-player',
      'playlist-progress',
      'playlist-transport',
      'playlist-play-pause',
      'playlist-extra-tools',
      'playlist-speed',
      'playlist-timer',
      'playlist-repeat',
      'playlist-rules',
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: 'Missing $key');
      expect(tester.getBottomRight(finder).dy, lessThan(750),
          reason: '$key should fit the first phone viewport');
    }
    expect(tester.takeException(), isNull);
  });
}
