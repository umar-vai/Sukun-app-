import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/widgets/global_audio_dock.dart';

void main() {
  testWidgets('floating audio dock occupies only its own height on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              AudioDockPositioner(
                child: SizedBox(
                  key: Key('mini-player'),
                  height: 76,
                  width: 550,
                  child: Text('Playing audio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final frame = find.byType(AudioDockPositioner);
    final layout = find.descendant(
      of: frame,
      matching: find.byType(Align),
    );
    expect(tester.getSize(layout).height, 76);
    expect(tester.getRect(layout).bottom, 888);
    expect(tester.getSize(find.byKey(const Key('mini-player'))).width, 550);
  });

  testWidgets('floating audio dock clears the mobile bottom navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              AudioDockPositioner(
                child: SizedBox(height: 160, child: Text('Expanded audio')),
              ),
            ],
          ),
        ),
      ),
    );

    final layout = find.descendant(
      of: find.byType(AudioDockPositioner),
      matching: find.byType(Align),
    );
    expect(tester.getSize(layout).height, 160);
    expect(tester.getRect(layout).bottom, 766);
  });

  test('inline speed presets cycle without a PopupMenu route', () {
    expect(nextAudioPlaybackSpeed(1.0), 1.25);
    expect(nextAudioPlaybackSpeed(1.25), 1.5);
    expect(nextAudioPlaybackSpeed(1.5), 2.0);
    expect(nextAudioPlaybackSpeed(2.0), 0.75);
    expect(nextAudioPlaybackSpeed(0.75), 1.0);
  });
}
