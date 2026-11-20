import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/notice_center/data/notice_center_providers.dart';
import 'package:sukun_life/features/notice_center/domain/amal_reminder.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_announcements_screen.dart';

void main() {
  final unseen = UniversalAnnouncement(
    id: '00000000-0000-4000-8000-000000000001',
    title: 'জুমার দিনের বিশেষ আমল',
    body: 'নোটিশের বিবরণ',
    status: 'published',
    publishedAt: DateTime.utc(2026, 11, 20, 8),
  );
  final amal = AmalReminder(
    kind: AmalReminderKind.personal,
    id: 'a1',
    title: 'সকালের জিকির',
    dueAt: DateTime(2026, 11, 20, 7, 30),
    route: '/my-routines/action/a1?fromReminder=1',
  );

  Future<void> pump(
    WidgetTester tester, {
    required AppSession session,
    required NoticeCenterSummary summary,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => Stream.value(session)),
          noticeCenterProvider.overrideWith((ref) async => summary),
          publishedAnnouncementsProvider.overrideWith((ref) async => [unseen]),
        ],
        child: const MaterialApp(home: UniversalAnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed-in user gets amal and Sukun Life notice sections', (
    tester,
  ) async {
    await pump(
      tester,
      session: const AppSession(role: UserRole.member, userId: 'member-1'),
      summary: NoticeCenterSummary(
        notices: [unseen],
        amalReminders: [amal],
        showsAmalSection: true,
      ),
    );

    expect(find.text('আমল রিমাইন্ডার'), findsOneWidget);
    expect(find.text('সুকুন লাইফ নোটিশ'), findsOneWidget);
    // One pending amal and one unseen notice, each counted on its own tab.
    expect(find.text('1'), findsNWidgets(2));
    expect(find.byKey(const Key('amal-reminder-a1')), findsOneWidget);
    expect(find.byKey(const Key('amal-complete-a1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('notice-tab-notices')));
    await tester.pumpAndSettle();
    expect(find.text('জুমার দিনের বিশেষ আমল'), findsOneWidget);
    expect(find.text('নতুন'), findsOneWidget);
  });

  testWidgets('guest sees only Sukun Life notices', (tester) async {
    await pump(
      tester,
      session: const AppSession.guest(),
      summary: NoticeCenterSummary(notices: [unseen]),
    );

    expect(find.text('সব নোটিশ'), findsOneWidget);
    expect(find.text('আমল রিমাইন্ডার'), findsNothing);
    expect(find.text('জুমার দিনের বিশেষ আমল'), findsOneWidget);
  });

  test('badge total adds unseen notices and pending amal', () {
    final summary = NoticeCenterSummary(
      notices: [unseen],
      amalReminders: [amal, amal],
      showsAmalSection: true,
    );
    expect(summary.total, 3);

    final seen = NoticeCenterSummary(
      notices: [unseen],
      seenNoticeKeys: {'${unseen.id}@${unseen.publishedAt!.toIso8601String()}'},
    );
    expect(seen.unseenNoticeCount, 0);
  });
}
