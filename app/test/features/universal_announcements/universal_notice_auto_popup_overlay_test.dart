import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_announcements_screen.dart';

class _PublicNoticeRepository implements AnnouncementRepository {
  const _PublicNoticeRepository(this.notice);
  final UniversalAnnouncement notice;

  @override
  Future<List<UniversalAnnouncement>> recentPublished() async => [notice];

  @override
  Future<List<UniversalAnnouncement>> published() async => [notice];

  @override
  Future<UniversalAnnouncement?> get(String id) async =>
      id == notice.id ? notice : null;

  @override
  Future<List<UniversalAnnouncement>> adminList() async => [];

  @override
  Future<UniversalAnnouncement> save(AnnouncementDraft draft) async =>
      throw UnsupportedError('Read-only QA fixture');

  @override
  Future<String> uploadImage({
    required String name,
    required List<int> bytes,
    required String mimeType,
  }) async => throw UnsupportedError('Read-only QA fixture');

  @override
  String imageUrl(String path) => 'https://example.invalid/notices/safe.jpg';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'published guest auto-popup has Overlay and closes without error',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notice = UniversalAnnouncement(
        id: 'b6f2057f-a924-4422-853f-d4c0fa851799',
        title: 'QA popup overlay notice',
        body: 'Public test message.',
        status: 'published',
        publishedAt: DateTime.utc(2026, 10, 26, 17),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith(
              (ref) => Stream.value(const AppSession.guest()),
            ),
            announcementRepositoryProvider.overrideWithValue(
              _PublicNoticeRepository(notice),
            ),
          ],
          child: const SukunLifeApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UniversalNoticePanel), findsOneWidget);
      expect(find.text('QA popup overlay notice'), findsOneWidget);
      expect(find.byType(Overlay), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('নোটিশ বন্ধ করুন'));
      await tester.pumpAndSettle();
      expect(find.text('QA popup overlay notice'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
