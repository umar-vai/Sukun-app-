import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sukun_life/features/resources/presentation/ruqyah_ayat_library.dart';

void main() {
  test('all 101 editorial Quran excerpts map exactly once', () {
    final counts = List<int>.filled(8, 0);
    for (var id = 1; id <= 101; id++) {
      final section = ruqyahSectionForSlug(
        'srg2024-qur-${id.toString().padLeft(3, '0')}',
      );
      expect(section, isNotNull, reason: 'Missing editorial excerpt $id');
      counts[section!] += 1;
    }
    expect(counts, [13, 47, 0, 10, 11, 6, 8, 6]);
  });

  test('23 Ruqyah/health/mercy Dua records remain in their own section', () {
    for (var id = 1; id <= 23; id++) {
      expect(
        ruqyahSectionForSlug('srg2024-dua-${id.toString().padLeft(3, '0')}'),
        2,
      );
    }
  });

  test('external and unpublished slugs never enter the reader', () {
    expect(ruqyahSectionForSlug('srg2024-qur-000'), isNull);
    expect(ruqyahSectionForSlug('srg2024-qur-102'), isNull);
    expect(ruqyahSectionForSlug('srg2024-col-001'), isNull);
    expect(ruqyahSectionForSlug('sukun-ruqyahbd-harq'), isNull);
    expect(ruqyahSections, hasLength(8));
  });

  test('section audio is described only as a full section recording', () {
    expect(ruqyahSections[2].audioSlug, isNull);
    expect(ruqyahSections[6].audioSlug, 'sukun-ruqyahbd-harq');
    expect(ruqyahSections[7].audioSlug, 'sukun-ruqyahbd-shifa-sakina');
  });

  test('editorial indexes are not passed off as canonical ayah numbers', () {
    expect(
      ruqyahDisplayTitle('প্রাথমিক রুকইয়াহ আয়াত — আয়াত/অংশ 13'),
      'প্রাথমিক রুকইয়াহ আয়াত',
    );
    expect(
      ruqyahDisplayTitle('আউযুবিল্লাহ ও বিসমিল্লাহ (ভূমিকা)'),
      'আউযুবিল্লাহ ও বিসমিল্লাহ (ভূমিকা)',
    );
  });

  test('a real source reference uses Bengali surah and ayah names', () {
    expect(
      ruqyahCitation(surahNumber: 114, ayahNumber: 1),
      'সূরা আন-নাস · আয়াত ১ থেকে নির্বাচিত পাঠ',
    );
    expect(
      ruqyahCitation(surahNumber: 113, ayahNumber: 1, ayahEndNumber: 5),
      'সূরা আল-ফালাক · আয়াত ১–৫',
    );
  });

  test('missing/unknown references never create a false surah title', () {
    expect(ruqyahCitation(surahNumber: null, ayahNumber: null), isNull);
    expect(ruqyahCitation(surahNumber: 2, ayahNumber: null), isNull);
    expect(ruqyahCitation(surahNumber: 0, ayahNumber: 1), isNull);
    expect(ruqyahCitation(surahNumber: 11, ayahNumber: 1), isNull);
  });

  test('Bengali numerals are derived from references, not card order', () {
    expect(ruqyahBanglaNumber(255), '২৫৫');
    expect(ruqyahBanglaNumber(114), '১১৪');
  });

  test('verse audio must come from attributed Quran CDN over HTTPS', () {
    expect(
      ruqyahTrustedVerseAudioUrl({
        'url': 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3',
      }),
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3',
    );
    expect(
      ruqyahTrustedVerseAudioUrl({
        'url': 'https://cdn.alquran.cloud/media/audio/001.mp3',
      }),
      isNotNull,
    );
    for (final url in [
      'http://cdn.islamic.network/quran/audio/1.mp3',
      'https://attacker.example/verse.mp3',
      'https://cdn.islamic.network@attacker.example/verse.mp3',
      'javascript:alert(1)',
    ]) {
      expect(ruqyahTrustedVerseAudioUrl({'url': url}), isNull);
    }
    expect(ruqyahTrustedVerseAudioUrl(null), isNull);
    expect(ruqyahTrustedVerseAudioUrl({'text': 'verse'}), isNull);
  });

  test('Ruqyah audio uses native-safe MediaItem metadata', () {
    const url = 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3';
    final source = ruqyahTaggedAudioSource(
      url: url,
      id: 'ruqyah-start-114-1',
      title: 'সূরা আন-নাস · আয়াত ১',
    );

    final taggedSource = source as UriAudioSource;
    expect(taggedSource.uri.toString(), url);
    expect(taggedSource.tag, isA<MediaItem>());
    final media = taggedSource.tag as MediaItem;
    expect(media.id, 'ruqyah-start-114-1');
    expect(media.title, contains('আন-নাস'));
    expect(media.album, 'Sukun Life');
  });

  test('Ruqyah player rejects malformed or insecure source URLs', () {
    for (final url in <String>[
      'http://cdn.islamic.network/verse.mp3',
      'javascript:alert(1)',
      'https://user@cdn.islamic.network/verse.mp3',
    ]) {
      expect(
        () => ruqyahTaggedAudioSource(url: url, id: 'x', title: 'x'),
        throwsFormatException,
      );
    }
  });

  test('unverified editorial introductions cannot acquire guessed ayat', () {
    expect(ruqyahSectionForSlug('srg2024-qur-001'), 0);
    expect(ruqyahSectionForSlug('srg2024-qur-047'), 4);
    expect(ruqyahCitation(surahNumber: null, ayahNumber: null), isNull);
  });
}
