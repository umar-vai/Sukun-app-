import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';
import 'package:sukun_life/features/resources/presentation/sukun_static_waveform.dart';

void main() {
  test('cover stays compact within short mobile viewports', () {
    final height = audioCoverHeightForViewport(360, 520);
    expect(height, closeTo(140.4, 0.01));
    expect(height, lessThan(150));
    expect(audioCoverHeightForViewport(320, 400), 108);
  });

  test('cover remains bounded for tablets and tiny browser widths', () {
    expect(audioCoverHeightForViewport(430, 900), 220);
    expect(audioCoverHeightForViewport(250, 900), 218);
    expect(audioCoverHeightForViewport(360, 900), 220);
  });

  testWidgets('mobile full player has first-viewport transport and tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const resource = LinkedResource(
      id: 'synthetic-audio-layout',
      title: 'পরীক্ষামূলক রুকইয়াহ অডিও',
      type: 'audio',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://example.org/test.mp3',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AudioPlayerScreen(
            resource: resource,
            loadResource: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in const [
      'audio-player-first-viewport',
      'audio-progress-slider',
      'audio-primary-actions',
      'audio-play-pause',
      'audio-playlist-add',
      'audio-download',
      'audio-secondary-actions',
      'audio-speed-menu',
      'audio-sleep-timer',
      'audio-repeat-toggle',
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: 'Missing $key');
      expect(
        tester.getBottomRight(finder).dy,
        lessThanOrEqualTo(640),
        reason: '$key is below the first mobile viewport',
      );
    }
    expect(tester.takeException(), isNull);
  });

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
