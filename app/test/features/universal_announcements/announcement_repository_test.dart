import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';

void main() {
  group('Universal announcement draft validation', () {
    test(
      'serializes public countdown in UTC and rejects expired endpoints',
      () {
        final now = DateTime.utc(2026, 10, 25, 12);
        final future = now.add(const Duration(hours: 3));
        final draft = AnnouncementDraft(
          title: 'সীমিত সময়ের ঘোষণা',
          body: 'প্রকাশ্য প্রচারমূলক ঘোষণা',
          countdownEndsAt: future,
        );
        expect(draft.validate(now: now), isNull);
        expect(draft.toJson()['countdown_ends_at'], future.toIso8601String());
        expect(
          AnnouncementDraft(
            title: 'Past',
            body: 'Expired',
            countdownEndsAt: now.subtract(const Duration(seconds: 1)),
          ).validate(now: now),
          isNotNull,
        );
        expect(
          AnnouncementDraft(
            title: 'Too far',
            body: 'Excessive deadline',
            countdownEndsAt: now.add(const Duration(days: 31)),
          ).validate(now: now),
          isNotNull,
        );
      },
    );

    test('reads published countdown without leaking private fields', () {
      final notice = UniversalAnnouncement.fromJson({
        'id': '33333333-3333-4333-8333-333333333333',
        'title': 'বিশেষ ঘোষণা',
        'body': 'সবার জন্য',
        'status': 'published',
        'countdown_ends_at': '2026-10-28T12:00:00Z',
      });
      expect(notice.countdownEndsAt, DateTime.utc(2026, 10, 28, 12));
      expect(notice.remainingAt(DateTime.utc(2026, 10, 28, 11)).inHours, 1);
    });

    test('accepts copy without an image or external link', () {
      const draft = AnnouncementDraft(
        title: 'সুকুন লাইফ নোটিশ',
        body: 'সবার জন্য গুরুত্বপূর্ণ তথ্য।',
      );
      expect(draft.validate(), isNull);
      expect(draft.toJson()['status'], 'draft');
    });

    test('rejects unsafe and non-HTTPS destinations', () {
      for (final url in [
        'javascript:alert(1)',
        'http://example.com',
        'https://',
        'file:///tmp/password',
      ]) {
        final draft = AnnouncementDraft(
          title: 'Notice',
          body: 'Details',
          linkUrl: url,
        );
        expect(draft.validate(), isNotNull);
      }
    });

    test('enforces bounded copy and known publication state', () {
      expect(
        const AnnouncementDraft(title: ' ', body: 'text').validate(),
        isNotNull,
      );
      expect(
        AnnouncementDraft(
          title: 'Title',
          body: List.filled(5001, 'a').join(),
        ).validate(),
        isNotNull,
      );
      expect(
        const AnnouncementDraft(
          title: 'Title',
          body: 'Body',
          status: 'sent',
        ).validate(),
        isNotNull,
      );
    });

    test('normalizes empty optional link and retains image path', () {
      const draft = AnnouncementDraft(
        title: ' Title ',
        body: ' Details ',
        linkUrl: ' ',
        imagePath: 'notices/brand-image.jpg',
        status: 'published',
      );
      final json = draft.toJson();
      expect(json['title'], 'Title');
      expect(json['body'], 'Details');
      expect(json['image_path'], 'notices/brand-image.jpg');
      expect(json['link_url'], isNull);
    });
  });
}
