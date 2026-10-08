import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/video_load_phase.dart';
import 'package:sukun_life/features/resources/presentation/youtube_player_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  test('shows loading until the first playable YouTube state', () {
    expect(
      videoLoadPhase(YoutubePlayerValue(), hasLoaded: false),
      VideoLoadPhase.loading,
    );
    expect(
      videoLoadPhase(
        YoutubePlayerValue(playerState: PlayerState.buffering),
        hasLoaded: false,
      ),
      VideoLoadPhase.loading,
    );
    expect(
      videoLoadPhase(
        YoutubePlayerValue(playerState: PlayerState.cued),
        hasLoaded: false,
      ),
      VideoLoadPhase.ready,
    );
    expect(
      videoLoadPhase(
        YoutubePlayerValue(playerState: PlayerState.unStarted),
        hasLoaded: false,
      ),
      VideoLoadPhase.ready,
    );
  });

  test('handles buffering after readiness, then playback and pause', () {
    expect(
      videoLoadPhase(
        YoutubePlayerValue(playerState: PlayerState.buffering),
        hasLoaded: true,
      ),
      VideoLoadPhase.buffering,
    );
    for (final state in [
      PlayerState.playing,
      PlayerState.paused,
      PlayerState.ended,
    ]) {
      expect(
        videoLoadPhase(YoutubePlayerValue(playerState: state), hasLoaded: true),
        VideoLoadPhase.ready,
      );
    }
  });

  test('returns a failure for errors rather than an endless loader', () {
    expect(
      videoLoadPhase(
        YoutubePlayerValue(error: YoutubeError.notEmbeddable),
        hasLoaded: false,
      ),
      VideoLoadPhase.failed,
    );
  });

  testWidgets('loading overlay displays progress and explanatory text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            height: 192,
            child: SukunVideoLoadingOverlay(),
          ),
        ),
      ),
    );
    expect(find.text('ভিডিও লোড হচ্ছে…'), findsOneWidget);
    expect(find.text('অনুগ্রহ করে একটু অপেক্ষা করুন'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
