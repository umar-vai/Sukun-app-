import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/book_audio_source_catalog.dart';
import 'package:sukun_life/features/content_admin/domain/private_resource_draft_batch.dart';
import 'package:sukun_life/features/content_admin/domain/source_heading_repair.dart';

void main() {
  const source = 'সেলফ রুকইয়াহ গাইড · paragraph 564';
  const rights = 'Sukun Life owner attested app-use rights';
  AdminContentItem old({
    String status = 'draft',
    String visibility = 'staff_only',
    String body = '১. সাধারণ গোসল',
    String sourceRef = source,
  }) => AdminContentItem(
    id: 'test-source-id',
    type: 'article',
    title: 'সাধারণ গোসল',
    titleBn: 'সাধারণ গোসল',
    slug: 'srg2024-ghs-001',
    visibility: visibility,
    status: status,
    verificationStatus: 'pending',
    body: body,
    sourceType: 'human_provided_book',
    sourceReference: sourceRef,
    rightsNote: rights,
  );

  PrivateResourceDraft replacement() => PrivateResourceDraft(
    sourceId: 'SRG2024-GHS-001',
    sourceCategory: 'ghusl',
    needsCanonicalReview: false,
    needsClinicalReview: true,
    input: const SaveContentInput(
      type: 'article',
      title: 'সাধারণ গোসল',
      titleBn: 'সাধারণ গোসল',
      slug: 'srg2024-ghs-001',
      visibility: 'staff_only',
      status: 'draft',
      requestId: 'fake-request-id',
      sourceType: 'human_provided_book',
      sourceReference: source,
      rightsNote: rights,
      body: 'সাধারণ গোসল: মূল বইয়ের বিস্তারিত প্রস্তুতি ও ধাপ—'
          'এই বাক্যগুলো টেস্টের জন্য লেখা, বাস্তব ধর্মীয় নির্দেশনা নয়। '
          'এখানে আরও অনেকগুলো কাল্পনিক বাক্য আছে।',
    ),
  );

  test('only intact source and title-only staff draft can be expanded', () {
    final result = prepareHeadingOnlySourceRepair(
      existing: old(),
      candidate: replacement(),
    );
    expect(result, isNotNull);
    expect(result!.contentItemId, 'test-source-id');
    expect(result.status, 'draft');
    expect(result.visibility, 'staff_only');
    expect(result.body, contains('কাল্পনিক'));
  });

  test('published, reviewed or staff-edited text cannot be overwritten', () {
    expect(prepareHeadingOnlySourceRepair(
      existing: old(status: 'published'),
      candidate: replacement(),
    ), isNull);
    expect(prepareHeadingOnlySourceRepair(
      existing: old(body: 'ম্যানুয়ালি যাচাই করা গুরুত্বপূর্ণ বিস্তারিত আলোচনা'),
      candidate: replacement(),
    ), isNull);
    expect(prepareHeadingOnlySourceRepair(
      existing: old(sourceRef: 'different source'),
      candidate: replacement(),
    ), isNull);
    expect(prepareHeadingOnlySourceRepair(
      existing: old(visibility: 'public'),
      candidate: replacement(),
    ), isNull);
  });

  Map<String, dynamic> candidate() => {
    'schema': 'sukun.ruqyahbd.external_audio_crosswalk.v1',
    'entries': [{
      'id': 'ruqyahbd-eight-surah',
      'title_bn': 'আট সুরার রুকইয়াহ',
      'original_page': 'https://ruqyahbd.org/download',
      'media_url': 'https://files.ruqyahbd.org/audio/Ruqyah-8surah-ruqyahbd.org.mp3',
      'book_paragraph_indices': [259, 293],
      'licensing': 'external_reference_only_no_rehosting_no_offline_copy',
      'publication_status': 'draft_review_only',
      'matching_status': 'title_and_book_reference_matched',
    }]
  };
  test('external audio source is staff-only CMS draft, never published', () {
    final sources = parseBookAudioCatalog(jsonEncode(candidate()));
    expect(sources, hasLength(1));
    final draft = sources.single.draftInput();
    expect(draft.type, 'audio');
    expect(draft.visibility, 'staff_only');
    expect(draft.status, 'draft');
    expect(draft.mediaSourceType, 'direct_audio_url');
    expect(draft.mediaUrl, contains('files.ruqyahbd.org'));
    expect(draft.rightsNote, contains('rights not independently verified'));
    expect(draft.validate(), isNull);
  });
  test('rejects untrusted domains and duplicate external IDs', () {
    final bad = candidate();
    (bad['entries'] as List).first['media_url'] = 'https://evil.example/track.mp3';
    expect(() => parseBookAudioCatalog(jsonEncode(bad)), throwsFormatException);
    final dup = candidate();
    (dup['entries'] as List).add(
      Map<String, dynamic>.from((dup['entries'] as List).first),
    );
    expect(() => parseBookAudioCatalog(jsonEncode(dup)), throwsFormatException);
  });
}
