import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

void main() {
  testWidgets('resources hub exposes every required top-level section', (
    tester,
  ) async {
    final repository = _FakeResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ResourcesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const [
      'কুরআন',
      'হাদিস',
      'দোয়া ও যিকর',
      'রুকইয়াহ',
      'বই ও আর্টিকেল',
      'ব্লগ',
      'অডিও',
      'ভিডিও',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('সাম্প্রতিক উপকরণ'), findsNothing);
    expect(find.text('আমার প্লেলিস্ট ও অফলাইন ডাউনলোড'), findsOneWidget);
    expect(find.text('রুকইয়াহ অডিও'), findsOneWidget);
    expect(find.text('রুকইয়াহর আয়াত পড়ুন'), findsNothing);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
    expect(find.text('Published resource'), findsNothing);
    expect(repository.browseCalls, 0);
  });

  testWidgets('hub stays compact and search remains on the hub', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ResourcesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.browseCalls, 0);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.mainAxisExtent, lessThanOrEqualTo(124));
    expect(delegate.crossAxisCount, 2);

    await tester.enterText(find.byType(TextField), 'আয়াতুল কুরসি');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    // The searchable catalog is loaded once, without a server-side query.
    expect(repository.browseCalls, 1);
    expect(repository.lastQuery, isEmpty);
    expect(repository.lastTypes, containsAll(['dua', 'audio', 'pdf']));
    expect(repository.lastTypes, isNot(contains('quran')));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('সাম্প্রতিক উপকরণ'), findsNothing);
    expect(find.text('বিষয় অনুযায়ী দেখুন'), findsOneWidget);
  });

  testWidgets('partial words show live suggestions and related results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ResourcesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'তাস');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    // Suggestions appear while still typing, before the word is complete.
    expect(find.byKey(const Key('live-search-suggestions')), findsOneWidget);
    expect(find.byKey(const Key('search-result-tasbih')), findsOneWidget);
    expect(find.byKey(const Key('search-result-resource-1')), findsNothing);
    expect(find.text('বিষয় অনুযায়ী দেখুন'), findsNothing);

    // A different spelling of the same word still finds it, instantly.
    await tester.enterText(find.byType(TextField), 'তাসবিহ');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-result-tasbih')), findsOneWidget);
    expect(repository.browseCalls, 1);

    // Type words find every item of that kind.
    await tester.enterText(find.byType(TextField), 'অডিও');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-result-kursi-audio')), findsOneWidget);
    expect(find.byKey(const Key('search-result-tasbih')), findsNothing);
    expect(repository.browseCalls, 1);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live-search-suggestions')), findsNothing);
    expect(find.text('বিষয় অনুযায়ী দেখুন'), findsOneWidget);
  });
}

final class _FakeResourcesRepository implements ResourcesRepository {
  String lastQuery = '';
  int browseCalls = 0;
  Set<String> lastTypes = const {};
  Set<String> lastCategoryPrefixes = const {};

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    browseCalls++;
    lastQuery = query;
    lastTypes = types;
    lastCategoryPrefixes = categoryPrefixes;
    return const [
      ContentResource(
        id: 'resource-1',
        type: 'article',
        title: 'Published resource',
        visibility: 'public',
        status: 'published',
      ),
      ContentResource(
        id: 'tasbih',
        type: 'dua',
        title: 'Tasbih',
        titleBn: 'ঘুমের আগে তাসবীহ',
        visibility: 'public',
        status: 'published',
      ),
      ContentResource(
        id: 'kursi-audio',
        type: 'audio',
        title: 'Ayatul Kursi ruqyah',
        titleBn: 'আয়াতুল কুরসির রুকইয়াহ',
        mediaUrl: 'https://example.org/kursi.mp3',
        visibility: 'public',
        status: 'published',
      ),
    ];
  }

  @override
  Future<ContentResource?> getResource(String resourceId) async => null;

  @override
  Future<List<QuranSurahSummary>> browseSurahs() async => const [];

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) async => const [];

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) async => const [];

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) async => const [];

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) async =>
      null;
}
