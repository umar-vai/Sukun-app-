import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/resource_detail_screen.dart';

void main() {
  testWidgets('assigned resource detail renders canonical text and reference', (
    tester,
  ) async {
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
    expect(find.text('Arabic'), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('Surah Al-Baqarah 2:255'), findsOneWidget);
  });
}

final class _FakeResourcesRepository implements ResourcesRepository {
  const _FakeResourcesRepository();

  @override
  Future<ContentResource?> getResource(String resourceId) async =>
      const ContentResource(
        id: 'resource-1',
        type: 'quran',
        title: 'Ayatul Kursi',
        arabicText: 'Canonical Arabic text from an approved source',
        referenceText: 'Surah Al-Baqarah 2:255',
        visibility: 'assigned_only',
        status: 'published',
      );
}
