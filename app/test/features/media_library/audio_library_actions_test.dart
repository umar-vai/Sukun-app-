import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/media_library/presentation/audio_library_actions.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

void main() {
  const source = LinkedResource(
    id: 'public-123',
    type: 'audio',
    title: 'Published audio',
    mediaSourceType: 'direct_audio_url',
    mediaUrl: 'https://example.org/approved.mp3',
  );

  testWidgets('audio card actions deep-link into one shared media library', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: AudioLibraryActions(resource: source)),
        ),
        GoRoute(
          path: '/my-media',
          builder: (_, state) => Scaffold(
            body: Text(
              'add=${state.uri.queryParameters['add']} '
              'download=${state.uri.queryParameters['download']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('প্লেলিস্টে যোগ করুন'), findsOneWidget);
    expect(find.text('ডাউনলোড'), findsOneWidget);

    await tester.tap(find.byKey(const Key('audio-add-public-123')));
    await tester.pumpAndSettle();
    expect(find.text('add=public-123 download=null'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audio-download-public-123')));
    await tester.pumpAndSettle();
    expect(find.text('add=null download=public-123'), findsOneWidget);
  });

  testWidgets('central library shortcut is accessible without audio open', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: AudioLibraryShortcut()),
        ),
        GoRoute(
          path: '/my-media',
          builder: (_, _) =>
              const Scaffold(body: Text('My local media library')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-my-audio-library')));
    await tester.pumpAndSettle();
    expect(find.text('My local media library'), findsOneWidget);
  });

  testWidgets(
    'small audio catalog card opens the requested action, not parent card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ResourceCard(
                    resource: const ContentResource(
                      id: 'public-123',
                      type: 'audio',
                      title: 'Sample published audio',
                      status: 'published',
                      visibility: 'public',
                      mediaSourceType: 'direct_audio_url',
                      mediaUrl: 'https://example.org/approved.mp3',
                    ),
                    onTap: () => context.push('/opened-audio'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/opened-audio',
            builder: (_, _) => const Scaffold(body: Text('Parent opened')),
          ),
          GoRoute(
            path: '/my-media',
            builder: (_, state) => Scaffold(
              body: Text(
                'library download=${state.uri.queryParameters['download']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audio-download-public-123')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('audio-download-public-123')));
      await tester.pumpAndSettle();
      expect(find.text('library download=public-123'), findsOneWidget);
      expect(find.text('Parent opened'), findsNothing);
    },
  );

  test('no download/playlist options for non-audio linked content', () {
    expect(
      AudioLibraryActions.supports(
        const LinkedResource(id: 'pdf', type: 'pdf', title: 'Document'),
      ),
      isFalse,
    );
    expect(AudioLibraryActions.supports(source), isTrue);
  });
}
