import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/domain/book_audio_source_catalog.dart';

void main() {
  Map<String, dynamic> candidate() => {
    'schema': 'sukun.ruqyahbd.external_audio_crosswalk.v1',
    'owner_authorization': {
      'basis': 'owner_attested',
      'attested_at': '2026-10-12',
    },
    'entries': [
      {
        'id': 'ruqyahbd-eight-surah',
        'title_bn': 'আট সুরার রুকইয়াহ',
        'original_page': 'https://ruqyahbd.org/download',
        'media_url':
            'https://files.ruqyahbd.org/audio/Ruqyah-8surah-ruqyahbd.org.mp3',
        'book_paragraph_indices': [259, 293],
        'licensing': 'owner_attested_for_sukun_life_app_2026_10_12',
        'publication_status': 'draft_review_only',
        'matching_status': 'title_and_book_reference_matched',
      },
    ],
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
    expect(draft.rightsNote, contains('Owner-attested'));
    expect(draft.validate(), isNull);
  });
  test(
    'all 19 real audio entries bind distinct IDs to distinct URLs',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final data = await rootBundle.loadString(
        'assets/data/ruqyahbd_book_audio_crosswalk.json',
      );
      final sources = parseBookAudioCatalog(data);
      expect(sources, hasLength(19));
      expect(sources.map((entry) => entry.id).toSet(), hasLength(19));
      expect(
        sources.map((entry) => entry.externalMediaUrl).toSet(),
        hasLength(19),
      );
      for (final entry in sources) {
        expect(entry.playbackResource.id, entry.id);
        expect(entry.playbackResource.mediaUrl, entry.externalMediaUrl);
        expect(entry.playbackResource.titleBn, entry.titleBn);
        expect(entry.playbackResource.mediaSourceType, 'direct_audio_url');
      }
    },
  );

  test('rejects untrusted domains and duplicate external IDs', () {
    final bad = candidate();
    (bad['entries'] as List).first['media_url'] =
        'https://evil.example/track.mp3';
    expect(() => parseBookAudioCatalog(jsonEncode(bad)), throwsFormatException);
    final dup = candidate();
    (dup['entries'] as List).add(
      Map<String, Object>.from((dup['entries'] as List).first),
    );
    expect(() => parseBookAudioCatalog(jsonEncode(dup)), throwsFormatException);
    final duplicateStream = candidate();
    (duplicateStream['entries'] as List).add({
      ...Map<String, Object>.from((duplicateStream['entries'] as List).first),
      'id': 'ruqyahbd-another-record',
    });
    expect(
      () => parseBookAudioCatalog(jsonEncode(duplicateStream)),
      throwsFormatException,
    );
  });
}
