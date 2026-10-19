import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/widgets/global_audio_dock.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

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
    expect(tester.getRect(layout).bottom, 802);
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
    expect(tester.getRect(layout).bottom, 746);
  });

  testWidgets(
    'expanded seek slider stays compact instead of filling viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Duration? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(),
                AudioDockPositioner(
                  child: Material(
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 56,
                          child: Text('Playing audio'),
                        ),
                        AudioDockSeekSlider(
                          duration: const Duration(seconds: 120),
                          position: const Duration(seconds: 30),
                          onSeek: (value) => seekTarget = value,
                        ),
                        const SizedBox(
                          height: 54,
                          child: Text('Previous · Speed · Next'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final outerAlign = find.descendant(
        of: find.byType(AudioDockPositioner),
        matching: find.byType(Align),
      );
      expect(tester.getSize(outerAlign.first).height, 150);
      expect(tester.getSize(find.byType(Slider)).height, 40);
      expect(tester.getRect(outerAlign.first).top, greaterThan(600));

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();
      expect(seekTarget, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expanded seek slider stays bounded on a mobile viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Stack(
              children: [
                const SizedBox.expand(),
                AudioDockPositioner(
                  child: Material(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 56,
                          child: Text('Playing audio'),
                        ),
                        AudioDockSeekSlider(
                          duration: Duration.zero,
                          position: Duration.zero,
                          onSeek: (_) {},
                        ),
                        const SizedBox(height: 54, child: Text('Controls')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Slider)).height, 40);
    final outerAlign = find.descendant(
      of: find.byType(AudioDockPositioner),
      matching: find.byType(Align),
    );
    expect(tester.getSize(outerAlign.first).height, 150);
    expect(tester.getRect(outerAlign.first).bottom, 746);
  });

  testWidgets(
    'floating audio player never covers bottom navigation on desktop',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: SukunBottomNavigation(
                  selectedIndex: 0,
                  destinations: const [
                    SukunNavDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'হোম',
                    ),
                    SukunNavDestination(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: 'অ্যাকাউন্ট',
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ),
              const AudioDockPositioner(
                child: SizedBox(key: Key('playing'), height: 76),
              ),
            ],
          ),
        ),
      );
      final dock = tester.getRect(find.byKey(const Key('playing')));
      final bar = tester.getRect(find.byType(SukunBottomNavigation));
      expect(dock.bottom, lessThan(bar.top));
      expect(tester.takeException(), isNull);
    },
  );

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
    semantics.dispose();
  });

  test('inline speed presets cycle without a PopupMenu route', () {
    expect(nextAudioPlaybackSpeed(1.0), 1.25);
    expect(nextAudioPlaybackSpeed(1.25), 1.5);
    expect(nextAudioPlaybackSpeed(1.5), 2.0);
    expect(nextAudioPlaybackSpeed(2.0), 0.75);
    expect(nextAudioPlaybackSpeed(0.75), 1.0);
  });
}
