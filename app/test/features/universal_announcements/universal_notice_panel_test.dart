import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_announcements_screen.dart';

const _publicId = 'a1b2c3d4-a123-4fff-8aaa-123456789abc';
const _pixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+iXgAAAABJRU5ErkJggg==';

Widget _noticePanel(DateTime deadline, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: SizedBox(
      width: 380,
      height: 550,
      child: UniversalNoticePanel(
        notice: UniversalAnnouncement(
          id: _publicId,
          title: 'বিশেষ ঘোষণা',
          body: 'সবার জন্য',
          status: 'published',
          imagePath: 'notices/public.png',
          countdownEndsAt: deadline,
        ),
        image: MemoryImage(base64Decode(_pixelPng)),
        onClose: () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('public image and countdown render together in notice panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _noticePanel(DateTime.now().add(const Duration(hours: 3))),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('universal-notice-countdown')), findsOneWidget);
    expect(
      find.byKey(const Key('universal-notice-countdown-time')),
      findsOneWidget,
    );
    expect(find.text('সময় শেষ'), findsNothing);
  });

  testWidgets('notice title and countdown stay readable in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _noticePanel(
        DateTime.now().add(const Duration(hours: 3)),
        theme: ThemeData.dark(),
      ),
    );
    await tester.pump();
    final header = tester.widget<Text>(
      find.text('সুকুন লাইফ • গুরুত্বপূর্ণ নোটিশ'),
    );
    expect(header.style?.color, SukunColors.nightNavy);
    final countdown = tester.widget<Text>(
      find.byKey(const Key('universal-notice-countdown-time')),
    );
    expect(countdown.style?.color, SukunColors.nightNavy);
  });

  testWidgets('expired or changed countdown never shows negative seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _noticePanel(DateTime.now().add(const Duration(hours: 3))),
    );
    await tester.pumpWidget(
      _noticePanel(DateTime.now().subtract(const Duration(seconds: 2))),
    );
    await tester.pump();
    expect(find.text('সময় শেষ'), findsOneWidget);
    expect(find.textContaining('-00:'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
