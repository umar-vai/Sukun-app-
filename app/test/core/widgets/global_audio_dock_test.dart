import 'package:flutter/gestures.dart';
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
    final layout = find.descendant(of: frame, matching: find.byType(Align));
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
          body: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: Stack(
              children: [
                SizedBox.expand(),
                AudioDockPositioner(
                  child: SizedBox(height: 160, child: Text('Expanded audio')),
                ),
              ],
            ),
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

  testWidgets('hovering dock controls never creates a tooltip overlay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var clickedUnderDock = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: () => clickedUnderDock = true,
                  child: const Text('Under dock'),
                ),
              ),
              AudioDockPositioner(
                child: Material(
                  child: AudioDockIconAction(
                    label: 'বিরতি',
                    icon: Icons.pause_circle_filled_rounded,
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(AudioDockIconAction)));
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(Tooltip, skipOffstage: false), findsNothing);
    final align = find.descendant(
      of: find.byType(AudioDockPositioner),
      matching: find.byType(Align),
    );
    expect(tester.getSize(align.first).height, lessThan(70));

    await tester.tap(find.text('Under dock'));
    expect(clickedUnderDock, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dock icon button keeps accessible action name', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioDockIconAction(
            label: 'অডিও বন্ধ করুন',
            icon: Icons.close_rounded,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('অডিও বন্ধ করুন'), findsOneWidget);
    expect(find.byType(Tooltip, skipOffstage: false), findsNothing);
  });

  test('inline speed presets cycle without a PopupMenu route', () {
    expect(nextAudioPlaybackSpeed(1.0), 1.25);
    expect(nextAudioPlaybackSpeed(1.25), 1.5);
    expect(nextAudioPlaybackSpeed(1.5), 2.0);
    expect(nextAudioPlaybackSpeed(2.0), 0.75);
    expect(nextAudioPlaybackSpeed(0.75), 1.0);
  });
}
