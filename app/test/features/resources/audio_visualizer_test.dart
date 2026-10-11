import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';
import 'package:sukun_life/features/resources/presentation/sukun_static_waveform.dart';

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

  testWidgets('decorative waveform is present and stable without playback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SukunStaticWaveform())),
    );
    expect(find.byType(SukunStaticWaveform), findsOneWidget);
    expect(find.byKey(const ValueKey('static-audio-waveform')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('static-audio-waveform')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('static waveform respects small layout and has no timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 280, child: SukunStaticWaveform()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SukunStaticWaveform), findsOneWidget);
  });
}
