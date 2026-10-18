import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';

void main() {
  group('Universal announcement draft validation', () {
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
