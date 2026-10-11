import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/presentation/resource_detail_screen.dart';
import 'package:sukun_life/features/resources/presentation/resource_category_screen.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

void main() {
  testWidgets('logout removes another patient resource detail in same tab', (
    tester,
  ) async {
    final sessionChanges = StreamController<AppSession>.broadcast(sync: true);
    addTearDown(sessionChanges.close);
    final repository = _ViewerAwareResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionChanges.stream),
          resourcesRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: ResourceDetailScreen(resourceId: 'patient-resource'),
        ),
      ),
    );
    sessionChanges.add(
      const AppSession(role: UserRole.patient, userId: 'synthetic-patient-a'),
    );
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE FOR PATIENT A'), findsOneWidget);

    // The public route stays open as the browser switches accounts.
    repository.viewer = 'guest';
    sessionChanges.add(const AppSession.guest());
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE FOR PATIENT A'), findsNothing);
    expect(find.text('উপকরণটি পাওয়া যায়নি'), findsOneWidget);
    expect(repository.getCalls, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource route ID change never leaves old resource visible', (
    tester,
  ) async {
    final repository = _ViewerAwareResourcesRepository();
    repository.viewer = 'guest';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(const AppSession.guest()),
          ),
          resourcesRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: ResourceDetailScreen(resourceId: 'public-a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Public A'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(const AppSession.guest()),
          ),
          resourcesRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: ResourceDetailScreen(resourceId: 'public-b'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Public A'), findsNothing);
    expect(find.text('Synthetic Public B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category reloads after logout and removes patient-only tile', (
    tester,
  ) async {
    final sessionChanges = StreamController<AppSession>.broadcast(sync: true);
    addTearDown(sessionChanges.close);
    final repository = _ViewerAwareResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionChanges.stream),
          resourcesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: ResourceCategoryScreen(
            section: resourceSectionBySlug('audio')!,
          ),
        ),
      ),
    );
    sessionChanges.add(
      const AppSession(role: UserRole.patient, userId: 'synthetic-patient-a'),
    );
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE AUDIO FOR PATIENT A'), findsOneWidget);

    repository.viewer = 'guest';
    sessionChanges.add(const AppSession.guest());
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE AUDIO FOR PATIENT A'), findsNothing);
    expect(find.text('কোনো উপকরণ পাওয়া যায়নি'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _ViewerAwareResourcesRepository implements ResourcesRepository {
  String viewer = 'patient-a';
  int getCalls = 0;

  @override
  Future<ContentResource?> getResource(String resourceId) async {
    getCalls++;
    if (resourceId == 'patient-resource') {
      if (viewer != 'patient-a') return null;
      return const ContentResource(
        id: 'patient-resource',
        type: 'article',
        title: 'PRIVATE FOR PATIENT A',
        body: 'Synthetic test text, no clinical or religious advice.',
        visibility: 'assigned_only',
        status: 'published',
      );
    }
    return ContentResource(
      id: resourceId,
      type: 'article',
      title: resourceId == 'public-a'
          ? 'Synthetic Public A'
          : 'Synthetic Public B',
      visibility: 'public',
      status: 'published',
    );
  }

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    if (viewer != 'patient-a') return const [];
    return const [
      ContentResource(
        id: 'private-audio',
        type: 'audio',
        title: 'PRIVATE AUDIO FOR PATIENT A',
        visibility: 'patient_only',
        status: 'published',
      ),
    ];
  }

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
