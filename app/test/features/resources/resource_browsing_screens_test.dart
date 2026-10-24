import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/presentation/blog_article_body.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/presentation/resource_browse_screens.dart';

void main() {
  test('resource hub shows merged Books & Articles and independent Blog', () {
    expect(
      resourceSections.map((section) => section.slug),
      contains('books-articles'),
    );
    expect(resourceSections.map((section) => section.slug), contains('blog'));
    expect(
      resourceSections.map((section) => section.slug),
      isNot(contains('books-pdfs')),
    );
    expect(
      resourceSections.map((section) => section.slug),
      isNot(contains('articles-guides')),
    );
    expect(resourceSectionBySlug('books-pdfs')?.slug, 'books-articles');
    expect(resourceSectionBySlug('articles-guides')?.slug, 'books-articles');
    expect(
      resourceSectionBySlug('books-articles')?.types,
      containsAll(['pdf', 'book', 'article', 'guide']),
    );
    expect(isBlogResourceSlug('blog-a-first-post'), isTrue);
    expect(isBlogResourceSlug('article-a-first-post'), isFalse);
  });

  testWidgets('blog displays actual headings and written paragraphs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BlogArticleBody(
            content: '# শিরোনাম\n\n## উপশিরোনাম\nসম্পূর্ণ ব্লগের লেখা',
          ),
        ),
      ),
    );
    expect(find.text('শিরোনাম'), findsOneWidget);
    expect(find.text('উপশিরোনাম'), findsOneWidget);
    expect(find.text('সম্পূর্ণ ব্লগের লেখা'), findsOneWidget);
  });

  testWidgets(
    'Quran browser renders Surahs and the canonical collection entry',
    (tester) async {
      await tester.pumpWidget(
        _testApp(const QuranBrowserScreen(), const _BrowsingRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected & Ruqyah Ayat'), findsOneWidget);
      expect(find.text('আল-ফাতিহা'), findsOneWidget);
      expect(find.text('1 · Al-Fatihah · 2 আয়াত'), findsOneWidget);
    },
  );

  testWidgets('Dua groups open subcategory and detail route with Back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const fixtures = [
      ContentResource(
        id: 'morning-1',
        type: 'dua',
        title: 'Morning fixture',
        referenceText: 'Private source book · paragraph 1167',
        categorySlug: 'dua-azkar-morning',
        visibility: 'public',
        status: 'published',
      ),
      ContentResource(
        id: 'masnun-1',
        type: 'dua',
        title: 'Masnun fixture',
        categorySlug: 'dua-azkar-masnun',
        visibility: 'public',
        status: 'published',
      ),
    ];
    final repository = _BrowsingRepository(duaItems: fixtures);
    final router = _taxonomyRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_taxonomyApp(router, repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dua-group-card-time-based')), findsOneWidget);
    expect(find.byKey(const Key('dua-card-morning-1')), findsNothing);
    await tester.tap(find.byKey(const Key('dua-group-card-time-based')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/dua-azkar/time-based',
    );
    expect(
      find.byKey(const Key('dua-select-dua-azkar-morning')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dua-card-morning-1')), findsNothing);

    await tester.tap(find.byKey(const Key('dua-select-dua-azkar-morning')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/dua-azkar/time-based/dua-azkar-morning',
    );
    expect(find.byKey(const Key('dua-card-morning-1')), findsOneWidget);
    expect(find.text('Private source book · paragraph 1167'), findsNothing);
    expect(find.byKey(const Key('dua-card-masnun-1')), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/dua-azkar/time-based',
    );
    router.pop();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/dua-azkar',
    );
    await tester.ensureVisible(
      find.byKey(const Key('dua-group-card-everyday')),
    );
    await tester.tap(find.byKey(const Key('dua-group-card-everyday')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('dua-select-dua-azkar-masnun')),
      findsOneWidget,
    );
  });

  testWidgets('direct-linked Dua subcategory has a working Back button', (
    tester,
  ) async {
    final router = _taxonomyRouter(
      initialLocation: '/resources/dua-azkar/time-based/dua-azkar-morning',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_taxonomyApp(router, const _BrowsingRepository()));
    await tester.pumpAndSettle();
    expect(find.text('এই বিভাগে এখনো প্রকাশিত দোয়া নেই।'), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/dua-azkar/time-based',
    );
  });

  testWidgets('uncategorized public dua is on its own safe route', (
    tester,
  ) async {
    final router = _taxonomyRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _taxonomyApp(
        router,
        const _BrowsingRepository(
          duaItems: [
            ContentResource(
              id: 'uncategorized',
              type: 'dua',
              title: 'Published uncategorized fixture',
              visibility: 'public',
              status: 'published',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dua-unclassified')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('dua-unclassified')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dua-unclassified')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/dua-azkar/other/_unclassified',
    );
    expect(find.text('Published uncategorized fixture'), findsOneWidget);
  });

  testWidgets('Hadith browser hides reference subtitle', (tester) async {
    await tester.pumpWidget(
      _testApp(const HadithBrowserScreen(), const _BrowsingRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('আখলাক (1)'), findsOneWidget);
    expect(find.text('Approved Hadith fixture'), findsOneWidget);
    expect(
      find.text('Fixture collection • Fixture book • 42 • Sahih'),
      findsNothing,
    );
  });

  testWidgets('Ruqyah topic cards open dedicated content page', (tester) async {
    final router = _taxonomyRouter(initialLocation: '/resources/ruqyah');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _taxonomyApp(
        router,
        const _BrowsingRepository(
          duaItems: [
            ContentResource(
              id: 'eye',
              type: 'audio',
              title: 'বদনজরের রুকইয়াহ',
              categorySlug: 'ruqyah-audio',
              visibility: 'public',
              status: 'published',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('রুকইয়াহ আয়াত'), findsOneWidget);
    expect(find.text('সেলফ-রুকইয়াহ গাইড'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('ruqyah-filter-ruqyah-evil-eye')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ruqyah-filter-ruqyah-evil-eye')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/ruqyah/ruqyah-evil-eye',
    );
    expect(find.byKey(const Key('ruqyah-item-eye')), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ruqyah-filter-ruqyah-evil-eye')),
      findsOneWidget,
    );
  });

  testWidgets(
    'collection detail uses canonical resource IDs and ordered Ayat',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          const QuranCollectionDetailScreen(collectionId: 'collection-1'),
          const _BrowsingRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('নির্বাচিত আয়াত'), findsOneWidget);
      expect(find.text('Verified Ayah fixture'), findsOneWidget);
      expect(find.text('Qur’an 1:1'), findsNothing);
    },
  );

  testWidgets(
    'ayat collection index exposes sections without fake published ayat',
    (tester) async {
      await tester.pumpWidget(
        _testApp(const QuranCollectionsScreen(), const _BrowsingRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('বেসিক রুকইয়াহ'), findsOneWidget);
      expect(find.text('রুকইয়াহ আয়াত'), findsOneWidget);
      expect(find.text('যাচাইকৃত আয়াত প্রকাশের অপেক্ষায়'), findsWidgets);
    },
  );

  test('Ruqyah ayat sections include distinct named editorial categories', () {
    expect(ruqyahAyatIndex, hasLength(8));
    expect(ruqyahAyatIndex.map((e) => e.slug).toSet(), hasLength(8));
    expect(
      ruqyahAyatIndex.map((e) => e.titleBn),
      containsAll([
        'বদনজরের আয়াত',
        'সিহরের আয়াত',
        'আয়াতুশ শিফা',
        'আয়াতুল হারক',
        'আয়াতুল সাকিনাহ',
      ]),
    );
    expect(ruqyahAyatIndex.singleWhere((e) => e.isDua).titleBn, 'রুকইয়াহ দোয়া');
  });
}

GoRouter _taxonomyRouter({String initialLocation = '/resources/dua-azkar'}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/resources/dua-azkar',
          builder: (_, _) =>
              const TaxonomyBrowserScreen(kind: TaxonomyKind.duaAzkar),
          routes: [
            GoRoute(
              path: ':groupSlug',
              builder: (_, state) => TaxonomyBrowserScreen(
                kind: TaxonomyKind.duaAzkar,
                groupSlug: state.pathParameters['groupSlug'],
              ),
              routes: [
                GoRoute(
                  path: ':categorySlug',
                  builder: (_, state) => TaxonomyBrowserScreen(
                    kind: TaxonomyKind.duaAzkar,
                    groupSlug: state.pathParameters['groupSlug'],
                    categorySlug: state.pathParameters['categorySlug'],
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/resources/ruqyah',
          builder: (_, _) =>
              const TaxonomyBrowserScreen(kind: TaxonomyKind.ruqyah),
          routes: [
            GoRoute(
              path: ':topicSlug',
              builder: (_, state) => TaxonomyBrowserScreen(
                kind: TaxonomyKind.ruqyah,
                topicSlug: state.pathParameters['topicSlug'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/resources/:id',
          builder: (_, _) => const Scaffold(body: Text('Detail')),
        ),
      ],
    );

Widget _taxonomyApp(GoRouter router, ResourcesRepository repository) =>
    ProviderScope(
      overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    );

Widget _testApp(Widget home, ResourcesRepository repository) => ProviderScope(
  overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(home: home),
);

final class _BrowsingRepository implements ResourcesRepository {
  const _BrowsingRepository({this.duaItems = const []});

  final List<ContentResource> duaItems;

  static const quran = ContentResource(
    id: 'quran-1',
    type: 'quran',
    title: 'Verified Ayah fixture',
    referenceText: 'Qur’an 1:1',
    surahNumber: 1,
    surahName: 'Al-Fatihah',
    surahNameBn: 'আল-ফাতিহা',
    ayahNumber: 1,
    visibility: 'public',
    status: 'published',
  );

  static const hadith = ContentResource(
    id: 'hadith-1',
    type: 'hadith',
    title: 'Approved Hadith fixture',
    categoryId: 'topic-1',
    categorySlug: 'hadith-character',
    categoryName: 'Character',
    categoryNameBn: 'আখলাক',
    collectionName: 'Fixture collection',
    bookName: 'Fixture book',
    hadithNumber: '42',
    grade: 'Sahih',
    visibility: 'public',
    status: 'published',
  );

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    return types.contains('hadith') ? const [hadith] : duaItems;
  }

  @override
  Future<List<QuranSurahSummary>> browseSurahs() async => const [
    QuranSurahSummary(
      surahNumber: 1,
      name: 'Al-Fatihah',
      nameBn: 'আল-ফাতিহা',
      ayahCount: 2,
    ),
  ];

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) async => const [
    quran,
  ];

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) async => const [
    ResourceTopic(
      id: 'topic-1',
      slug: 'hadith-character',
      name: 'Character',
      nameBn: 'আখলাক',
      resourceCount: 1,
    ),
  ];

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) async => const [
    ContentCollection(
      id: 'collection-1',
      type: 'selected_ayat',
      title: 'Selected Ayat',
      titleBn: 'নির্বাচিত আয়াত',
      slug: 'selected-ayat',
      visibility: 'public',
      status: 'published',
    ),
  ];

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) async =>
      const ContentCollectionDetails(
        collection: ContentCollection(
          id: 'collection-1',
          type: 'selected_ayat',
          title: 'Selected Ayat',
          titleBn: 'নির্বাচিত আয়াত',
          slug: 'selected-ayat',
          visibility: 'public',
          status: 'published',
        ),
        items: [quran],
      );

  @override
  Future<ContentResource?> getResource(String resourceId) async => null;
}
