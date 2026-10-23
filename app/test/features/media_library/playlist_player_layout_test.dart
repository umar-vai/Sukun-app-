import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/media_library/presentation/playlist_player_page.dart';

void main() {
  test('cover adapts to narrow and wide first viewports', () {
    expect(playlistCoverHeight(360, 500), closeTo(140, 0.001));
    expect(playlistCoverHeight(390, 700), closeTo(196, 0.001));
    expect(playlistCoverHeight(500, 900), 200);
    expect(playlistCoverHeight(200, 500), closeTo(140, 0.001));
  });

  test('playlist relative seek is bounded and never negative', () {
    expect(
      playlistSeekTarget(
        const Duration(seconds: 3),
        const Duration(seconds: 90),
        -10,
      ),
      Duration.zero,
    );
    expect(
      playlistSeekTarget(
        const Duration(seconds: 84),
        const Duration(seconds: 90),
        10,
      ),
      const Duration(seconds: 90),
    );
  });

  test('elapsed and total formats preserve long recordings', () {
    expect(playlistDurationLabel(const Duration(seconds: 41)), '0:41');
    expect(
      playlistDurationLabel(const Duration(minutes: 99, seconds: 7)),
      '1:39:07',
    );
  });

  testWidgets('real transport controls fit phone width and forward actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var rewind = 0;
    var forward = 0;
    var play = 0;
    var previous = 0;
    var next = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: PlaylistTransportControls(
                playing: false,
                busy: false,
                hasPrevious: true,
                hasNext: true,
                onPrevious: () => previous++,
                onRewind: () => rewind++,
                onPlayPause: () => play++,
                onForward: () => forward++,
                onNext: () => next++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('playlist-transport')), findsOneWidget);
    expect(find.byKey(const ValueKey('playlist-play-pause')), findsOneWidget);
    for (final label in const [
      'আগের অডিও',
      '১০ সেকেন্ড পেছনে',
      '১০ সেকেন্ড সামনে',
      'পরের অডিও',
    ]) {
      final control = find.byTooltip(label);
      expect(control, findsOneWidget);
      expect(tester.getBottomRight(control).dy, lessThan(750));
    }

    await tester.tap(find.byTooltip('আগের অডিও'));
    await tester.tap(find.byTooltip('১০ সেকেন্ড পেছনে'));
    await tester.tap(find.byKey(const ValueKey('playlist-play-pause')));
    await tester.tap(find.byTooltip('১০ সেকেন্ড সামনে'));
    await tester.tap(find.byTooltip('পরের অডিও'));
    expect([previous, rewind, play, forward, next], [1, 1, 1, 1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transport keeps unavailable skips disabled while buffering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaylistTransportControls(
            playing: false,
            busy: true,
            hasPrevious: false,
            hasNext: false,
            onPrevious: () {},
            onRewind: () {},
            onPlayPause: () {},
            onForward: () {},
            onNext: () {},
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('playlist-play-pause')), findsNothing);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(
        IconButton,
        Icons.skip_previous_rounded,
      )).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(
        IconButton,
        Icons.skip_next_rounded,
      )).onPressed,
      isNull,
    );
  });
}
