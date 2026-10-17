import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/review_resource_discovery.dart';

void main() {
  const audioCatalog = [
    ContentResourceOption(
      id: 'jinn',
      slug: 'sukun-ruqyahbd-jinn',
      title: 'জিনের আছরের রুকইয়াহ',
      type: 'audio',
      visibility: 'public',
      status: 'published',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://example.org/jinn.mp3',
    ),
    ContentResourceOption(
      id: 'harq',
      slug: 'sukun-ruqyahbd-harq',
      title: 'আয়াতুল হারক',
      type: 'audio',
      visibility: 'public',
      status: 'published',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://example.org/harq.mp3',
    ),
    ContentResourceOption(
      id: 'shifa-sakina',
      slug: 'sukun-ruqyahbd-shifa-sakina',
      title: 'শিফা ও সাকিনা রুকইয়াহ',
      type: 'audio',
      visibility: 'public',
      status: 'published',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://example.org/shifa.mp3',
    ),
  ];

  const amalCatalog = [
    ContentResourceOption(
      id: 'morning',
      slug: 'srg2024-aml-002',
      title: 'সকাল-সন্ধ্যার তিন কুল',
      type: 'amal',
      visibility: 'public',
      status: 'published',
    ),
    ContentResourceOption(
      id: 'sleep-wudu',
      slug: 'srg2024-aml-003',
      title: 'অজু করে ঘুমানো',
      type: 'amal',
      visibility: 'public',
      status: 'published',
    ),
    ContentResourceOption(
      id: 'bed',
      slug: 'srg2024-aml-004',
      title: 'বিছানা ঝাড়া',
      type: 'amal',
      visibility: 'public',
      status: 'published',
    ),
    ContentResourceOption(
      id: 'kursi',
      slug: 'srg2024-aml-005',
      title: 'আয়াতুল কুরসি',
      type: 'amal',
      visibility: 'public',
      status: 'published',
    ),
    ContentResourceOption(
      id: 'last2',
      slug: 'srg2024-aml-006',
      title: 'বাকারার শেষ আয়াত',
      type: 'amal',
      visibility: 'public',
      status: 'published',
    ),
    ContentResourceOption(
      id: 'three-kul',
      slug: 'srg2024-aml-007',
      title: 'তিন কুল',
      type: 'amal',
      visibility: 'public',
      status: 'published',
    ),
    ContentResourceOption(
      id: 'bed-dua',
      slug: 'srg2024-dua-013',
      title: 'শোয়ার পর দোয়া',
      type: 'dua',
      visibility: 'public',
      status: 'published',
    ),
  ];

  test('explicit multi-audio request finds three real items and flags missing Qital', () {
    final result = discoverReviewResources(
      title: 'General Ruqyah Audio Session',
      instruction: 'জিনের আছরের রুকইয়াহ, আয়াতুল হারক, '
          'রুকইয়াহ তাদমির-কিতাল, শিফা-সাকিনা '
          'প্রতিটি অডিও ১৫-২০ মিনিট করে শুনবেন।',
      resourceMatchQuery: 'General Ruqyah',
      resources: audioCatalog,
    );
    expect(result.requiresManualSelection, isTrue);
    expect(result.matches.map((m) => m.resource.id), [
      'jinn',
      'harq',
      'shifa-sakina',
    ]);
    expect(result.missing, hasLength(1));
    expect(result.missing.single, contains('তাদমির/কিতাল'));
    expect(result.note, contains('Confirm'));
  });

  test('only published HTTPS playback items are suggested', () {
    const unsafe = ContentResourceOption(
      id: 'untrusted',
      slug: 'sukun-ruqyahbd-harq',
      title: 'হারক',
      type: 'audio',
      status: 'published',
      visibility: 'public',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'http://example.org/harq.mp3',
    );
    final result = discoverReviewResources(
      title: 'আয়াতুল হারক',
      instruction: 'অডিও শুনবেন',
      resourceMatchQuery: null,
      resources: [unsafe],
    );
    expect(result.matches, isEmpty);
    expect(result.missing, hasLength(1));
  });

  test('unpublished and staff-only tracks cannot become related suggestions', () {
    const privateTrack = ContentResourceOption(
      id: 'hidden',
      slug: 'sukun-ruqyahbd-jinn',
      title: 'জিনের আছরের রুকইয়াহ',
      type: 'audio',
      status: 'published',
      visibility: 'staff_only',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://example.org/hidden.mp3',
    );
    final result = discoverReviewResources(
      title: 'জিনের আছরের রুকইয়াহ',
      instruction: null,
      resourceMatchQuery: null,
      resources: [privateTrack],
    );
    expect(result.matches, isEmpty);
    expect(result.missing, hasLength(1));
  });

  test('morning and bedtime Masnun task proposes individual cards, not a full routine', () {
    final result = discoverReviewResources(
      title: 'সকাল সন্ধ্যা ঘুমানোর পূর্বে মাসনূন আমল',
      instruction: 'গুরুত্বসহকারে পালন করবেন',
      resourceMatchQuery: 'Masnun routine',
      resources: amalCatalog,
    );
    expect(result.requiresManualSelection, isTrue);
    expect(result.matches, hasLength(7));
    expect(result.missing, isEmpty);
    expect(result.note, contains('NOT a verified'));
  });

  test('plain bedtime statement does not invent a Masnun bundle', () {
    final result = discoverReviewResources(
      title: 'ঘুমের আগে পানি পান',
      instruction: null,
      resourceMatchQuery: null,
      resources: amalCatalog,
    );
    expect(result.requiresManualSelection, isFalse);
    expect(result.matches, isEmpty);
  });
}
