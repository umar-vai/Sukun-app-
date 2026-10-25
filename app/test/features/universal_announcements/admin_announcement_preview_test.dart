import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/presentation/admin_announcements_screen.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_announcements_screen.dart';

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


class _PublishingRepository extends _PreviewRepository {
  _PublishingRepository(this.current);

  final UniversalAnnouncement current;
  AnnouncementDraft? publishedDraft;

  @override
  Future<UniversalAnnouncement?> get(String id) async =>
      id == current.id ? current : null;

  @override
  String imageUrl(String path) => 'https://example.invalid/$path';

  @override
  Future<UniversalAnnouncement> save(AnnouncementDraft draft) async {
    publishedDraft = draft;
    return UniversalAnnouncement(
      id: current.id,
      title: draft.title,
      body: draft.body,
      status: draft.status,
      imagePath: draft.imagePath,
      countdownEndsAt: draft.countdownEndsAt,
    );
  }
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
    expect(find.byKey(const Key('notice-set-countdown')), findsOneWidget);
    // The preview button may be behind a keyboard on a small viewport.
    // Invoke its actual callback to verify the non-saving preview flow.
    final previewButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('notice-preview')),
    );
    previewButton.onPressed!();
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
  });

  testWidgets('Admin previews and publishes existing image with deadline', (
    tester,
  ) async {
    const id = '33333333-3333-4333-8333-333333333333';
    final deadline = DateTime.now().add(const Duration(hours: 3));
    final repository = _PublishingRepository(
      UniversalAnnouncement(
        id: id,
        title: 'বিশেষ নোটিশ',
        body: 'প্রকাশ্য ঘোষণা',
        status: 'draft',
        imagePath: 'notices/safe-public.jpg',
        countdownEndsAt: deadline,
      ),
    );
    final router = GoRouter(
      initialLocation: '/admin/announcements/$id/edit',
      routes: [
        GoRoute(
          path: '/admin/announcements',
          builder: (context, state) =>
              const Scaffold(body: Text('Saved announcement list')),
        ),
        GoRoute(
          path: '/admin/announcements/:id/edit',
          builder: (context, state) => AdminAnnouncementEditorScreen(
            id: state.pathParameters['id'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ছবি পরিবর্তন করুন'), findsOneWidget);
    expect(find.byKey(const Key('notice-clear-countdown')), findsOneWidget);

    final previewButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('notice-preview')),
    );
    previewButton.onPressed!();
    await tester.pump();

    final panel = tester.widget<UniversalNoticePanel>(
      find.byType(UniversalNoticePanel),
    );
    expect(panel.isPreview, isTrue);
    expect(panel.image, isA<NetworkImage>());
    expect(panel.notice.countdownEndsAt, deadline);
    expect(find.byKey(const Key('universal-notice-countdown')), findsOneWidget);

    await tester.tap(find.byTooltip('নোটিশ বন্ধ করুন'));
    await tester.pump();
    final publishButton = tester.widget<FilledButton>(
      find.byKey(const Key('notice-publish')),
    );
    publishButton.onPressed!();
    await tester.pumpAndSettle();

    expect(repository.publishedDraft?.status, 'published');
    expect(repository.publishedDraft?.countdownEndsAt, deadline);
    expect(repository.publishedDraft?.imagePath, 'notices/safe-public.jpg');
    expect(find.text('Saved announcement list'), findsOneWidget);
  });
}
