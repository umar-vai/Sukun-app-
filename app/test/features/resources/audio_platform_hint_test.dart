import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';

void main() {
  testWidgets('audio capabilities are described truthfully on web and native', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                AudioPlaybackPlatformBadge(),
                AudioPlaybackPlatformHint(),
              ],
            ),
          ),
        ),
      ),
    );

    if (kIsWeb) {
      expect(find.text('ব্রাউজারে অডিও'), findsOneWidget);
      expect(
        find.textContaining('ব্রাউজারের নিয়মের ওপর নির্ভর করে'),
        findsOneWidget,
      );
      expect(find.text('পেছনেও চলবে'), findsNothing);
      expect(find.textContaining('ফোনের লকস্ক্রিন'), findsNothing);
    } else {
      expect(find.text('পেছনেও চলবে'), findsOneWidget);
      expect(find.textContaining('ফোনের লকস্ক্রিন'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
