import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/dua_azkar_browse_section.dart';

const _listItem = ContentResource(
  id: 'dua-1',
  type: 'dua',
  title: 'Protection dua 1',
  titleBn: 'হিফাজতের দোয়া ১',
  visibility: 'public',
  status: 'published',
  categorySlug: 'dua-azkar-morning',
);

class _FullTextRepository implements ResourcesRepository {
  @override
  Future<ContentResource?> getResource(String resourceId) async =>
      const ContentResource(
        id: 'dua-1',
        type: 'dua',
        title: 'Protection dua 1',
        titleBn: 'হিফাজতের দোয়া ১',
        visibility: 'public',
        status: 'published',
        banglaText: 'সকাল-সন্ধ্যায় দশবার পড়ুন',
        translation: 'আমি আল্লাহর নামে শুরু করছি',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('category page shows each dua with its text on the same page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourcesRepositoryProvider.overrideWithValue(_FullTextRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DuaAzkarBrowseSection(
                resources: [_listItem],
                groupSlug: 'time-based',
                categorySlug: 'dua-azkar-morning',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dua-card-dua-1')), findsOneWidget);
    expect(find.text('হিফাজতের দোয়া ১'), findsOneWidget);
    expect(find.text('সকাল-সন্ধ্যায় দশবার পড়ুন'), findsOneWidget);
    expect(find.text('আমি আল্লাহর নামে শুরু করছি'), findsOneWidget);
    // No audio is attached, so no play button is offered.
    expect(find.byKey(const Key('dua-audio-dua-1')), findsNothing);
  });
}
