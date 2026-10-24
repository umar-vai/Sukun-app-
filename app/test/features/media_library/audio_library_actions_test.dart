import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/media_library/data/offline_byte_store.dart';
import 'package:sukun_life/features/media_library/data/offline_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/media_library/presentation/audio_library_actions.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

class _MemoryBytes implements OfflineByteStore {
  @override
  Future<void> write(String key, Uint8List bytes) async {}

  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> delete(String key) async {}
}

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
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
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
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
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
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio-download-public-123')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('audio-download-public-123')));
      await tester.pumpAndSettle();
      expect(find.text('library download=public-123'), findsOneWidget);
      expect(find.text('Parent opened'), findsNothing);
    },
  );

  testWidgets('saved track badge updates after removing local download', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sukun.offline.public.v1.guest': jsonEncode([
        {
          'id': 'public-123',
          'title': 'Published audio',
          'kind': 'audio',
          'size': 20,
          'sha256': 'synthetic-test-only',
          'saved': '2026-10-24T00:00:00.000Z',
        },
      ]),
    });
    final offline = OfflineLibrary(bytes: _MemoryBytes());
    await offline.open('guest');
    addTearDown(offline.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: AudioLibraryActions(resource: source)),
        ),
        GoRoute(
          path: '/my-media',
          builder: (_, _) => const Scaffold(body: Text('My downloads')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineLibraryProvider.overrideWithValue(offline)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ডাউনলোড হয়েছে'), findsOneWidget);
    await offline.remove('public-123');
    await tester.pumpAndSettle();
    expect(find.text('ডাউনলোড'), findsOneWidget);
    expect(find.text('ডাউনলোড হয়েছে'), findsNothing);
  });

  testWidgets('catalog card shows saved audio and updates after removal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sukun.offline.public.v1.guest': jsonEncode([
        {
          'id': 'public-123',
          'title': 'Sample published audio',
          'kind': 'audio',
          'size': 20,
          'sha256': 'synthetic-test-only',
          'saved': '2026-10-24T00:00:00.000Z',
        },
      ]),
    });
    final offline = OfflineLibrary(bytes: _MemoryBytes());
    await offline.open('guest');
    addTearDown(offline.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineLibraryProvider.overrideWithValue(offline)],
        child: MaterialApp(
          home: Scaffold(
            body: ResourceCard(
              resource: const ContentResource(
                id: 'public-123',
                type: 'audio',
                title: 'Sample published audio',
                status: 'published',
                visibility: 'public',
                mediaSourceType: 'direct_audio_url',
                mediaUrl: 'https://example.org/approved.mp3',
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('ডাউনলোড হয়েছে'), findsOneWidget);
    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);

    await offline.remove('public-123');
    await tester.pumpAndSettle();
    expect(find.byTooltip('ডাউনলোড'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.byTooltip('ডাউনলোড হয়েছে'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact audio cards keep both actions on a 360px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: ResourceCard(
                resource: const ContentResource(
                  id: 'public-123',
                  type: 'audio',
                  title: 'বাংলা অনুবাদসহ কমন রুকইয়াহ দীর্ঘ অডিও শিরোনাম',
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
        GoRoute(
          path: '/opened-audio',
          builder: (_, _) => const Scaffold(body: Text('Playing')),
        ),
        GoRoute(
          path: '/my-media',
          builder: (_, state) => Scaffold(
            body: Text('download=${state.uri.queryParameters['download']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audio-add-public-123')), findsOneWidget);
    expect(find.byKey(const Key('audio-download-public-123')), findsOneWidget);
    expect(find.byKey(const Key('audio-menu-public-123')), findsNothing);
    expect(tester.getSize(find.byType(ResourceCard)).height, lessThan(110));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('audio-download-public-123')));
    await tester.pumpAndSettle();
    expect(find.text('download=public-123'), findsOneWidget);
    expect(find.text('Playing'), findsNothing);
  });

  testWidgets('narrow audio card uses one menu without opening its parent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: ResourceCard(
                resource: const ContentResource(
                  id: 'public-123',
                  type: 'audio',
                  title: 'দীর্ঘ রুকইয়াহ অডিও শিরোনাম',
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
        GoRoute(
          path: '/opened-audio',
          builder: (_, _) => const Scaffold(body: Text('Playing')),
        ),
        GoRoute(
          path: '/my-media',
          builder: (_, state) =>
              Scaffold(body: Text('add=${state.uri.queryParameters['add']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audio-menu-public-123')), findsOneWidget);
    expect(find.byKey(const Key('audio-download-public-123')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('audio-menu-public-123')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('প্লেলিস্টে যোগ'));
    await tester.pumpAndSettle();
    expect(find.text('add=public-123'), findsOneWidget);
    expect(find.text('Playing'), findsNothing);
  });

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
