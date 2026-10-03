import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/presentation/resource_detail_screen.dart';

void main() {
  testWidgets('assigned resource detail renders canonical text and reference', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourcesRepositoryProvider.overrideWithValue(
            const _FakeResourcesRepository(),
          ),
        ],
        child: const MaterialApp(
          home: ResourceDetailScreen(resourceId: 'resource-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayatul Kursi'), findsOneWidget);
    expect(find.text('ARABIC'), findsOneWidget);
    expect(find.text('REFERENCE'), findsOneWidget);
    expect(find.text('Surah Al-Baqarah 2:255'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeResourcesRepository implements ResourcesRepository {
  const _FakeResourcesRepository();

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async => const [];

  @override
  Future<ContentResource?> getResource(String resourceId) async =>
      const ContentResource(
        id: 'resource-1',
        type: 'quran',
        title: 'Ayatul Kursi',
        arabicText: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ',
        referenceText: 'Surah Al-Baqarah 2:255',
        visibility: 'assigned_only',
        status: 'published',
      );

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
