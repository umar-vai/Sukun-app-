import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_preview_screen.dart';

/// The preview's workflow buttons must follow the real stored values
/// (draft/review/verified/published/archived and verified), not translated
/// labels. A past bulk translation had broken these comparisons.
void main() {
  Future<void> show(
    WidgetTester tester, {
    required String type,
    required String status,
    String verification = 'pending',
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            _OneItemRepository(
              AdminContentItem(
                id: 'c1',
                type: type,
                title: 'Test item',
                slug: 'test-item',
                visibility: 'public',
                status: status,
                verificationStatus: verification,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: AdminContentPreviewScreen(contentItemId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('published items can be unpublished and archived', (
    tester,
  ) async {
    await show(tester, type: 'audio', status: 'published');
    expect(find.text('প্রকাশ বন্ধ করুন'), findsOneWidget);
    expect(find.text('সংরক্ষণাগারে রাখুন'), findsOneWidget);
  });

  testWidgets('a verified Qur\'an item can finally be published', (
    tester,
  ) async {
    await show(
      tester,
      type: 'quran',
      status: 'verified',
      verification: 'verified',
    );
    expect(find.text('প্রকাশ করুন'), findsOneWidget);
    expect(find.text('মূল তথ্য যাচাই করুন'), findsNothing);
  });

  testWidgets('a Qur\'an item in review offers source approval', (
    tester,
  ) async {
    await show(tester, type: 'quran', status: 'review');
    expect(find.text('মূল তথ্য যাচাই করুন'), findsOneWidget);
    expect(find.text('সংশোধনের জন্য ফেরত দিন'), findsOneWidget);
    expect(find.text('প্রকাশ করুন'), findsNothing);
  });

  testWidgets('archived items cannot be archived again', (tester) async {
    await show(tester, type: 'audio', status: 'archived');
    expect(find.text('প্রকাশ বন্ধ করুন'), findsNothing);
    expect(find.text('সংরক্ষণাগারে রাখুন'), findsNothing);
  });
}

final class _OneItemRepository implements ContentAdminRepository {
  _OneItemRepository(this.item);

  final AdminContentItem item;

  @override
  Future<AdminContentItem?> getContent(String contentItemId) async => item;

  @override
  Future<List<ContentReview>> listReviews(String contentItemId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
