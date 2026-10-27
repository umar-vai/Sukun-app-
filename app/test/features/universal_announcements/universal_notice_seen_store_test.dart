import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_seen_store.dart';

UniversalAnnouncement notice(
  String id, {
  String status = 'published',
  DateTime? publishedAt,
}) => UniversalAnnouncement(
  id: id,
  title: 'গুরুত্বপূর্ণ নোটিশ',
  body: 'নোটিশের বিস্তারিত',
  status: status,
  publishedAt: publishedAt,
);

void main() {
  final first = DateTime.utc(2026, 10, 18, 12);
  final second = first.add(const Duration(minutes: 2));

  test('published notice has a stable timezone-independent receipt key', () {
    final item = notice('notice-1', publishedAt: first);
    expect(
      universalNoticePublicationKey(item),
      'notice-1@2026-10-18T12:00:00.000Z',
    );
  });

  test('drafts and incomplete announcements never automatically pop up', () {
    expect(
      universalNoticePublicationKey(
        notice('draft', status: 'draft', publishedAt: first),
      ),
      isNull,
    );
    expect(universalNoticePublicationKey(notice('missing-date')), isNull);
  });

  test('skips previously seen publications and prefers newest', () {
    final notices = [
      notice('latest', publishedAt: second),
      notice('earlier', publishedAt: first),
    ];
    expect(nextUnseenUniversalNotice(notices, {}), same(notices.first));
    final seen = {universalNoticePublicationKey(notices.first)!};
    expect(nextUnseenUniversalNotice(notices, seen), same(notices.last));
    seen.add(universalNoticePublicationKey(notices.last)!);
    expect(nextUnseenUniversalNotice(notices, seen), isNull);
  });

  test('republication has a new receipt and appears exactly once again', () {
    final firstPublish = notice('same-id', publishedAt: first);
    final republished = notice('same-id', publishedAt: second);
    expect(
      universalNoticePublicationKey(republished),
      isNot(universalNoticePublicationKey(firstPublish)),
    );
    expect(
      nextUnseenUniversalNotice(
        [republished],
        {universalNoticePublicationKey(firstPublish)!},
      ),
      same(republished),
    );
  });

  test('local receipt check remains permission-free and owner-isolated', () async {
    SharedPreferences.setMockInitialValues({});
    const store = UniversalNoticeSeenStore(null);
    final item = notice('published-id', publishedAt: first);
    final key = universalNoticePublicationKey(item)!;

    expect(await store.readLocal(null), isEmpty);
    expect(await store.readLocal('member-a'), isEmpty);
    await store.mark(item, 'member-a');
    expect(await store.readLocal('member-a'), contains(key));
    expect(await store.readLocal('member-b'), isEmpty);
    expect(await store.readLocal(null), isEmpty);
    // A second local read cannot trigger network access or replay.
    expect(await store.readLocal('member-a'), contains(key));
  });

  test('guests and distinct users never share local seen identifiers', () {
    expect(
      UniversalNoticeSeenStore.storageKey(null),
      isNot(UniversalNoticeSeenStore.storageKey('account-a')),
    );
    expect(
      UniversalNoticeSeenStore.storageKey('account-a'),
      isNot(UniversalNoticeSeenStore.storageKey('account-b')),
    );
  });
}
