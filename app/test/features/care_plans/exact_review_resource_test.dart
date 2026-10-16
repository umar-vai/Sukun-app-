import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/resource_matcher.dart';

void main() {
  const verifiedAyat = ContentResourceOption(
    id: 'verified-ayat',
    title: 'Ayatul Kursi',
    type: 'quran',
    status: 'published',
    visibility: 'public',
    verificationStatus: 'verified',
    surahNumber: 2,
    ayahNumber: 255,
  );
  const approvedDua = ContentResourceOption(
    id: 'dua-1',
    title: 'Morning Dua',
    type: 'dua',
    status: 'published',
    visibility: 'public',
  );
  const approvedAudio = ContentResourceOption(
    id: 'audio-1',
    title: 'Ayatul Kursi',
    type: 'audio',
    status: 'published',
    visibility: 'public',
    mediaSourceType: 'direct_audio_url',
    mediaUrl: 'https://example.org/canonical-recording.mp3',
  );

  test('exact verified ayah can be preselected for recitation', () {
    final matches = matchResources('2:255', [verifiedAyat, approvedDua]);
    expect(
      exactReviewResource(matches, actionType: 'recitation')?.id,
      'verified-ayat',
    );
  });

  test('an exact Quran title cannot auto-fill the wrong action type', () {
    final matches = matchResources('2:255', [verifiedAyat]);
    expect(exactReviewResource(matches, actionType: 'amal'), isNull);
    expect(exactReviewResource(matches, actionType: 'audio'), isNull);
  });

  test('a reading instruction never auto-links an audio recording', () {
    final matches = matchResources('Ayatul Kursi', [approvedAudio]);
    expect(exactReviewResource(matches, actionType: 'recitation'), isNull);
    expect(exactReviewResource(matches, actionType: 'audio')?.id, 'audio-1');
  });

  test(
    'verified HTTPS audio still requires direct source and an exact title',
    () {
      const unsafeAudio = ContentResourceOption(
        id: 'unsafe',
        title: 'Morning Dua',
        type: 'audio',
        status: 'published',
        visibility: 'public',
      );
      final matches = matchResources('Morning Dua', [unsafeAudio]);
      expect(exactReviewResource(matches, actionType: 'audio'), isNull);
    },
  );

  test('ambiguous identical resources must be picked manually', () {
    const duplicate = ContentResourceOption(
      id: 'dua-2',
      title: 'Morning Dua',
      type: 'dua',
      status: 'published',
      visibility: 'public',
    );
    final matches = matchResources('Morning Dua', [approvedDua, duplicate]);
    expect(exactReviewResource(matches, actionType: 'dua'), isNull);
  });

  test('draft and staff-only items must not be automatically assigned', () {
    const draft = ContentResourceOption(
      id: 'draft',
      title: 'Morning Dua',
      type: 'dua',
      status: 'draft',
      visibility: 'public',
    );
    const staff = ContentResourceOption(
      id: 'staff',
      title: 'Morning Dua',
      type: 'dua',
      status: 'published',
      visibility: 'staff_only',
    );
    final matches = matchResources('Morning Dua', [draft, staff]);
    expect(exactReviewResource(matches, actionType: 'dua'), isNull);
  });

  test('fuzzy resource matches remain suggestions and cannot auto-assign', () {
    final matches = matchResources('Morning', [approvedDua]);
    expect(matches, isNotEmpty);
    expect(exactReviewResource(matches, actionType: 'dua'), isNull);
  });
}
