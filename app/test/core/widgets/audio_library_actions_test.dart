import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    expect(audioLibraryPath(AudioLibraryAction.library, id), '/my-media');
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
        home: Scaffold(body: AudioLibraryActions(resourceId: '  ')),
      ),
    );
    expect(find.byType(PopupMenuButton<AudioLibraryAction>), findsNothing);
  });
  testWidgets('selecting Add opens the right CMS audio in the shared library', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: AudioLibraryActions(resourceId: 'public-123'),
          ),
        ),
        GoRoute(
          path: '/my-media',
          builder: (context, state) => Scaffold(
            body: Text('playlist: ${state.uri.queryParameters['add'] ?? ''}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('audio-library-actions-public-123')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('প্লেলিস্টে যুক্ত করুন'));
    await tester.pumpAndSettle();
    expect(find.text('playlist: public-123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting Download routes to the offline tab with the same ID', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: AudioLibraryActions(resourceId: 'public-456'),
          ),
        ),
        GoRoute(
          path: '/my-media',
          builder: (context, state) => Scaffold(
            body: Text('download: ${state.uri.queryParameters['download'] ?? ''}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('audio-library-actions-public-456')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('অফলাইনে ডাউনলোড'));
    await tester.pumpAndSettle();
    expect(find.text('download: public-456'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
