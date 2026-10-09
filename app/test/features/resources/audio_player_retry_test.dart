import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';

void main() {
  const first = LinkedResource(
    id: 'audio-1',
    title: 'First audio',
    type: 'audio',
    mediaSourceType: 'direct_audio_url',
    mediaUrl: 'https://cdn.example.org/first.mp3',
  );
  const refreshed = LinkedResource(
    id: 'audio-1',
    title: 'Updated audio',
    type: 'audio',
    mediaSourceType: 'direct_audio_url',
    mediaUrl: 'https://cdn.example.org/refreshed.mp3',
  );

  testWidgets('a broken media link displays safe retry and retries on tap', (
    tester,
  ) async {
    var attempts = 0;
    Future<void> unavailable(LinkedResource _) async {
      attempts++;
      throw const AudioPlaybackException('private-source-token');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: AudioPlayerScreen(
          resource: first,
          loadResource: unavailable,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.text('আবার চেষ্টা করুন'), findsOneWidget);
    expect(find.textContaining('private-source-token'), findsNothing);

    await tester.tap(find.text('আবার চেষ্টা করুন'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('আবার চেষ্টা করুন'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same screen reloads a refreshed audio URL', (tester) async {
    final requests = <String?>[];
    Future<void> unavailable(LinkedResource resource) async {
      requests.add(resource.mediaUrl);
      throw const AudioPlaybackException('not playable');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: AudioPlayerScreen(
          resource: first,
          loadResource: unavailable,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: AudioPlayerScreen(
          resource: refreshed,
          loadResource: unavailable,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, [
      'https://cdn.example.org/first.mp3',
      'https://cdn.example.org/refreshed.mp3',
    ]);
    expect(find.text('আবার চেষ্টা করুন'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
