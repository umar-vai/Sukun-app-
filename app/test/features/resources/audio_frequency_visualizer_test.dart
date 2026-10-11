import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/media/audio_frequency_source.dart';
import 'package:sukun_life/features/resources/presentation/sukun_audio_visualizer.dart';

class _FakeFrequencySource implements AudioFrequencySource {
  int syncs = 0;
  int stops = 0;
  Uri? attached;
  AudioFrequencyFrame frame = const AudioFrequencyFrame(
    status: FrequencyStatus.active,
    bands: [0.95, 0.3, 0.5, 0.7],
    bass: 0.95,
  );

  @override
  void attach(Uri? url) => attached = url;
  @override
  void sync(Duration position, bool playing, double speed) {
    if (playing) syncs++;
  }

  @override
  AudioFrequencyFrame sample() => frame;
  @override
  void dispose() => stops++;
}

void main() {
  testWidgets('real FFT bars reflect sampled frequency source', (tester) async {
    final source = _FakeFrequencySource();
    const audioUrl = 'https://audio.example.org/voice.mp3';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SukunAudioVisualizer(
            playing: true,
            position: const Duration(seconds: 20),
            audioUrl: Uri.parse(audioUrl),
            source: source,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(source.attached.toString(), audioUrl);
    expect(source.syncs, greaterThan(0));
    expect(find.text('লাইভ Bass · Mid · Treble'), findsOneWidget);

    source.frame = const AudioFrequencyFrame(
      status: FrequencyStatus.blocked,
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.textContaining('অনুমতি দেয়নি'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SukunAudioVisualizer(
            playing: false,
            position: const Duration(seconds: 21),
            audioUrl: Uri.parse(audioUrl),
            source: source,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('লাইভ ফ্রিকোয়েন্সি বন্ধ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(source.stops, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit animation disable does not invent FFT spectrum', (
    tester,
  ) async {
    final source = _FakeFrequencySource();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SukunAudioVisualizer(
            playing: true,
            position: Duration.zero,
            animated: false,
            audioUrl: Uri.parse('https://audio.example.org/test.mp3'),
            source: source,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(source.syncs, 0);
    expect(find.text('লাইভ ফ্রিকোয়েন্সি বন্ধ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
