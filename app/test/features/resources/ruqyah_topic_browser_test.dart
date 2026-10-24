import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/ruqyah_topic_browser.dart';

void main() {
  ContentResource audio(String id, String title) => ContentResource(
    id: id,
    type: 'audio',
    title: title,
    categorySlug: 'ruqyah-audio',
    visibility: 'public',
    status: 'published',
  );

  testWidgets('Ruqyah index shows only categories, never inline audio cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audioItems = [
      audio('kursi', 'আয়াতুল কুরসির রুকইয়াহ'),
      audio('qul', 'তিনকুলের রুকইয়াহ'),
      audio('eye', 'বদনজরের রুকইয়াহ'),
    ];
    var openAyat = 0;
    final router = GoRouter(
      initialLocation: '/resources/ruqyah',
      routes: [
        GoRoute(
          path: '/resources/ruqyah',
          builder: (_, _) => _screen(audioItems, null, () => openAyat++),
          routes: [
            GoRoute(
              path: ':topicSlug',
              builder: (_, state) => _screen(
                audioItems,
                state.pathParameters['topicSlug'],
                () => openAyat++,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ruqyah-filter-ruqyah-recitation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ruqyah-item-kursi')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const Key('ruqyah-filter-ruqyah-recitation')),
    );
    await tester.tap(find.byKey(const Key('ruqyah-filter-ruqyah-recitation')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/ruqyah/ruqyah-recitation',
    );
    expect(find.byKey(const Key('ruqyah-item-kursi')), findsOneWidget);
    expect(find.byKey(const Key('ruqyah-item-qul')), findsOneWidget);
    expect(find.byKey(const Key('ruqyah-item-eye')), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/resources/ruqyah');
    expect(find.byKey(const Key('ruqyah-item-kursi')), findsNothing);
    expect(openAyat, 0);
  });

  testWidgets('Ruqyah ayat shortcut opens within the category page', (
    tester,
  ) async {
    var openAyat = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RuqyahTopicBrowser(
              resources: const [],
              topicSlug: 'ruqyah-ayat',
              onOpenResource: (_) {},
              onOpenAyat: () => openAyat++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ruqyah-open-ayat')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ruqyah-open-ayat')));
    expect(openAyat, 1);
  });
}

Widget _screen(
  List<ContentResource> resources,
  String? slug,
  VoidCallback onOpenAyat,
) => Scaffold(
  body: SingleChildScrollView(
    child: RuqyahTopicBrowser(
      resources: resources,
      topicSlug: slug,
      onOpenResource: (_) {},
      onOpenAyat: onOpenAyat,
    ),
  ),
);
