import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/presentation/resource_category_screen.dart';

void main() {
  testWidgets('category hides outdated results while search is debouncing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _SearchResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: ResourceCategoryScreen(
            section: resourceSectionBySlug('audio')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Result for all'), findsOneWidget);
    expect(repository.calls, 1);

    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump();
    expect(find.text('Result for all'), findsNothing);
    expect(find.text('অনুসন্ধান করা হচ্ছে…'), findsOneWidget);
    expect(repository.calls, 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Result for first'), findsOneWidget);
    expect(repository.calls, 2);

    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump();
    expect(find.text('Result for first'), findsNothing);
    expect(find.text('অনুসন্ধান করা হচ্ছে…'), findsOneWidget);
    expect(repository.calls, 2);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Result for second'), findsOneWidget);
    expect(repository.calls, 3);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Result for second'), findsNothing);
    expect(find.text('Result for all'), findsOneWidget);
    expect(repository.calls, 4);
    expect(tester.takeException(), isNull);
  });
}

final class _SearchResourcesRepository implements ResourcesRepository {
  int calls = 0;

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    calls++;
    if (!types.contains('audio')) {
      throw StateError('Expected the audio category filter.');
    }
    return [
      ContentResource(
        id: 'qa-result',
        type: 'audio',
        title: 'Result for ${query.isEmpty ? 'all' : query}',
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
