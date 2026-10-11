import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';
import 'package:sukun_life/features/resources/presentation/sukun_audio_visualizer.dart';

void main() {
  test('relative audio seeking stays inside the known track', () {
    expect(
      audioSeekTarget(
        const Duration(seconds: 4),
        const Duration(minutes: 2),
        -10,
      ),
      Duration.zero,
    );
    expect(
      audioSeekTarget(
        const Duration(seconds: 115),
        const Duration(minutes: 2),
        10,
      ),
      const Duration(minutes: 2),
    );
    expect(
      audioSeekTarget(
        const Duration(seconds: 48),
        const Duration(minutes: 2),
        10,
      ),
      const Duration(seconds: 58),
    );
    expect(
      audioSeekTarget(const Duration(seconds: 50), null, 10),
      const Duration(seconds: 60),
    );
  });

  testWidgets('spectrum animates during playback and stops on pause', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SukunAudioVisualizer(
            playing: true,
            position: Duration(seconds: 24),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(SukunAudioVisualizer), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SukunAudioVisualizer(
            playing: false,
            position: Duration(seconds: 25),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled motion remains accessible and deterministic', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SukunAudioVisualizer(
            playing: true,
            position: Duration(seconds: 5),
            animated: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SukunAudioVisualizer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
