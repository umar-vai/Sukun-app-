import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/presentation/admin_announcements_screen.dart';

class _PreviewRepository implements AnnouncementRepository {
  int saves = 0;

  @override
  Future<List<UniversalAnnouncement>> adminList() async => [];

  @override
  Future<UniversalAnnouncement?> get(String id) async => null;

  @override
  String imageUrl(String path) => '';

  @override
  Future<List<UniversalAnnouncement>> published() async => [];

  @override
  Future<List<UniversalAnnouncement>> recentPublished() async => [];

  @override
  Future<UniversalAnnouncement> save(AnnouncementDraft draft) async {
    saves++;
    throw StateError('Preview must not save.');
  }

  @override
  Future<String> uploadImage({
    required String name,
    required List<int> bytes,
    required String mimeType,
  }) async => throw StateError('Preview must not upload.');
}

void main() {
  testWidgets('Admin previews unsaved notice before publishing', (
    tester,
  ) async {
    final repository = _PreviewRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AdminAnnouncementEditorScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('notice-title')),
      'পরীক্ষামূলক ঘোষণা',
    );
    await tester.enterText(
      find.byKey(const Key('notice-body')),
      'প্রকাশের আগের লেখা।',
    );
    await tester.ensureVisible(find.byKey(const Key('notice-preview')));
    await tester.tap(find.byKey(const Key('notice-preview')));
    await tester.pumpAndSettle();

    expect(find.text('প্রকাশের আগে নোটিশ দেখুন'), findsOneWidget);
    final preview = find.byType(Dialog);
    expect(
      find.descendant(of: preview, matching: find.text('পরীক্ষামূলক ঘোষণা')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('প্রকাশের আগের লেখা।')),
      findsOneWidget,
    );
    expect(repository.saves, 0);
    expect(find.byKey(const Key('notice-set-countdown')), findsOneWidget);
  });
}
