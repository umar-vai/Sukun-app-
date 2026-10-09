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
      'বই ও পিডিএফ',
      'আর্টিকেল ও গাইড',
      'অডিও',
      'ভিডিও',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('সাম্প্রতিক উপকরণ'), findsNothing);
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

    await tester.enterText(find.byType(TextField), 'আয়াতুল কুরসি Ayatul Kursi');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.lastQuery, 'আয়াতুল কুরসি Ayatul Kursi');
    expect(repository.lastTypes, isEmpty);
    expect(repository.browseCalls, 1);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('সাম্প্রতিক উপকরণ'), findsNothing);
  });

  testWidgets(
    'new search text hides stale previous query results immediately',
    (tester) async {
    final repository = _FakeResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ResourcesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'first search');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.browseCalls, 1);
    expect(find.text('Published resource'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'second search');
    await tester.pump();
    expect(repository.browseCalls, 1);
    expect(find.text('Published resource'), findsNothing);
    expect(find.text('অনুসন্ধান করা হচ্ছে…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.browseCalls, 2);
    expect(repository.lastQuery, 'second search');
    expect(find.text('Published resource'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Published resource'), findsNothing);
    expect(find.text('বিষয় অনুযায়ী দেখুন'), findsOneWidget);
    expect(repository.browseCalls, 2);
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
