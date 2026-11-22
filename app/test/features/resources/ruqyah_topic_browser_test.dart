import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/ruqyah_topic_browser.dart';

void main() {
  ContentResource audio(
    String id,
    String title, {
    String category = 'ruqyah-lib-topic',
    int order = 0,
  }) => ContentResource(
    id: id,
    type: 'audio',
    title: title,
    categorySlug: category,
    sortOrder: order,
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
      audio('kursi', 'আয়াতুল কুরসির রুকইয়াহ', order: 20),
      audio('qul', 'তিনকুলের রুকইয়াহ', order: 10),
      audio('eye', 'বদনজরের রুকইয়াহ', category: 'ruqyah-lib-reciters'),
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
    // The index lists the main areas only, as RuqyahBD does; audio groups
    // live one level down under "রুকইয়াহ অডিও".
    expect(find.byKey(const Key('ruqyah-filter-ruqyah-audio')), findsOneWidget);
    expect(
      find.byKey(const Key('ruqyah-filter-ruqyah-lib-topic')),
      findsNothing,
    );
    expect(find.byKey(const Key('ruqyah-item-kursi')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('ruqyah-filter-ruqyah-self-guide')),
        matching: find.byIcon(Icons.menu_book_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('ruqyah-filter-ruqyah-ayat')),
        matching: find.byIcon(Icons.auto_stories_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('ruqyah-filter-ruqyah-audio')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/ruqyah/ruqyah-audio',
    );
    expect(
      find.byKey(const Key('ruqyah-filter-ruqyah-lib-topic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ruqyah-filter-ruqyah-lib-reciters')),
      findsOneWidget,
    );
    // Groups without audio and the ungrouped card stay hidden.
    expect(
      find.byKey(const Key('ruqyah-filter-ruqyah-lib-hibshi')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('ruqyah-filter-ruqyah-more-audio')),
      findsNothing,
    );
    expect(find.byKey(const Key('ruqyah-item-kursi')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('ruqyah-filter-ruqyah-lib-topic')),
        matching: find.byIcon(Icons.headphones_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const Key('ruqyah-filter-ruqyah-lib-topic')),
    );
    await tester.tap(find.byKey(const Key('ruqyah-filter-ruqyah-lib-topic')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/ruqyah/ruqyah-lib-topic',
    );
    expect(find.byKey(const Key('ruqyah-item-kursi')), findsOneWidget);
    expect(find.byKey(const Key('ruqyah-item-qul')), findsOneWidget);
    expect(find.byKey(const Key('ruqyah-item-eye')), findsNothing);
    // Admin-set order: the item with order 10 comes before order 20.
    expect(
      tester.getTopLeft(find.byKey(const Key('ruqyah-item-qul'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('ruqyah-item-kursi'))).dy,
      ),
    );
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
