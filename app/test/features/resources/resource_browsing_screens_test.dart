import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/presentation/resource_browse_screens.dart';

void main() {
  testWidgets(
    'Quran browser renders Surahs and the canonical collection entry',
    (tester) async {
      await tester.pumpWidget(
        _testApp(const QuranBrowserScreen(), const _BrowsingRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected & Ruqyah Ayat'), findsOneWidget);
      expect(find.text('আল-ফাতিহা'), findsOneWidget);
      expect(find.text('1 · Al-Fatihah · 2 published Ayat'), findsOneWidget);
    },
  );

  testWidgets('all three dua groups contain their categorized resources', (
    tester,
  ) async {
    final filters = <Set<String>>[];
    final repository = _BrowsingRepository(
      onBrowse: filters.add,
      duaItems: const [
        ContentResource(
          id: 'morning-1',
          type: 'dua',
          title: 'Morning fixture',
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
        ContentResource(
          id: 'protection-1',
          type: 'dua',
          title: 'Protection fixture',
          categorySlug: 'dua-azkar-protection',
          visibility: 'public',
          status: 'published',
        ),
      ],
    );
    await tester.pumpWidget(
      _testApp(
        const TaxonomyBrowserScreen(kind: TaxonomyKind.duaAzkar),
        repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(filters.last, isEmpty);
    expect(find.text('Morning fixture'), findsNothing);

    await tester.tap(find.text('সকালের আযকার').first);
    await tester.pumpAndSettle();
    expect(find.text('Morning fixture'), findsOneWidget);
    expect(find.text('Masnun fixture'), findsNothing);

    await tester.ensureVisible(find.text('দৈনন্দিন মাসনূন দোয়া'));
    await tester.tap(find.text('দৈনন্দিন মাসনূন দোয়া'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('মাসনূন দুআ'));
    await tester.tap(find.text('মাসনূন দুআ'));
    await tester.pumpAndSettle();
    expect(find.text('Masnun fixture'), findsOneWidget);

    await tester.ensureVisible(find.text('সুরক্ষা ও দুশ্চিন্তার দোয়া'));
    await tester.tap(find.text('সুরক্ষা ও দুশ্চিন্তার দোয়া'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('সুরক্ষা').first);
    await tester.tap(find.text('সুরক্ষা').first);
    await tester.pumpAndSettle();
    expect(find.text('Protection fixture'), findsOneWidget);
  });

  testWidgets('uncategorized public dua remains visible as safe fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const TaxonomyBrowserScreen(kind: TaxonomyKind.duaAzkar),
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
    expect(find.text('বিভাগ নির্ধারণের অপেক্ষায়'), findsOneWidget);
    await tester.ensureVisible(find.text('বিভাগ নির্ধারণের অপেক্ষায়'));
    await tester.tap(find.text('বিভাগ নির্ধারণের অপেক্ষায়'));
    await tester.pumpAndSettle();
    expect(find.text('Published uncategorized fixture'), findsOneWidget);
  });

  testWidgets('Hadith browser exposes CMS-derived topics and references', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const HadithBrowserScreen(), const _BrowsingRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('আখলাক (1)'), findsOneWidget);
    expect(find.text('Approved Hadith fixture'), findsOneWidget);
    expect(
      find.text('Fixture collection • Fixture book • 42 • Sahih'),
      findsOneWidget,
    );
  });

  testWidgets('Dua and Ruqyah browsers expose the approved taxonomy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const TaxonomyBrowserScreen(kind: TaxonomyKind.duaAzkar),
        const _BrowsingRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('সময়ভিত্তিক আমল'), findsOneWidget);
    expect(find.text('সকালের আযকার'), findsOneWidget);
    expect(find.text('দৈনন্দিন মাসনূন দোয়া'), findsOneWidget);
    await tester.ensureVisible(find.text('দৈনন্দিন মাসনূন দোয়া'));
    await tester.tap(find.text('দৈনন্দিন মাসনূন দোয়া'));
    await tester.pumpAndSettle();
    expect(find.text('মাসনূন দুআ'), findsOneWidget);
    expect(find.text('সফর'), findsOneWidget);

    await tester.pumpWidget(
      _testApp(
        const TaxonomyBrowserScreen(kind: TaxonomyKind.ruqyah),
        const _BrowsingRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('রুকইয়াহ আয়াত'), findsOneWidget);
    expect(find.text('সেলফ-রুকইয়াহ গাইড'), findsOneWidget);
    expect(find.text('বদনজর'), findsOneWidget);
    expect(find.text('সিহর'), findsOneWidget);
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
      expect(find.text('Qur’an 1:1'), findsOneWidget);
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

Widget _testApp(Widget home, ResourcesRepository repository) => ProviderScope(
  overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(home: home),
);

final class _BrowsingRepository implements ResourcesRepository {
  const _BrowsingRepository({this.onBrowse, this.duaItems = const []});

  final void Function(Set<String>)? onBrowse;
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
    onBrowse?.call(categoryPrefixes);
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
