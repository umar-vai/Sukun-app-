import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_collections_screen.dart';

void main() {
  testWidgets('ayat collections screen is fully in Bangla', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(_EmptyRepository()),
        ],
        child: const MaterialApp(home: AdminContentCollectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('আয়াতের সংকলন'), findsOneWidget);
    expect(find.text('নতুন সংকলন'), findsOneWidget);
    expect(find.text('এখনো কোনো আয়াতের সংকলন নেই'), findsOneWidget);
    for (final english in ['Ayat collections', 'New collection']) {
      expect(find.text(english), findsNothing);
    }
  });
}

final class _EmptyRepository implements ContentAdminRepository {
  @override
  Future<List<AdminContentCollection>> listCollections() async => [];

  @override
  Future<List<AdminContentItem>> listContent({String query = ''}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
