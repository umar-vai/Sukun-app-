import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/widgets/audio_library_actions.dart';

void main() {
  test('library action routes use one canonical media destination', () {
    const id = 'audio/item?with spaces';
    expect(
      audioLibraryPath(AudioLibraryAction.playlist, id),
      '/my-media?add=audio%2Fitem%3Fwith+spaces',
    );
    expect(
      audioLibraryPath(AudioLibraryAction.download, id),
      '/my-media?download=audio%2Fitem%3Fwith+spaces',
    );
    expect(
      audioLibraryPath(AudioLibraryAction.library, id),
      '/my-media',
    );
  });

  testWidgets('audio menu exposes both actions and the unified library', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudioLibraryActions(resourceId: 'published-audio'),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const Key('audio-library-actions-published-audio')),
    );
    await tester.pumpAndSettle();
    expect(find.text('প্লেলিস্টে যুক্ত করুন'), findsOneWidget);
    expect(find.text('অফলাইনে ডাউনলোড'), findsOneWidget);
    expect(find.text('আমার লাইব্রেরি দেখুন'), findsOneWidget);
  });

  testWidgets('items without canonical IDs do not offer unsafe actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudioLibraryActions(resourceId: '  '),
        ),
      ),
    );
    expect(find.byType(PopupMenuButton<AudioLibraryAction>), findsNothing);
  });
}
