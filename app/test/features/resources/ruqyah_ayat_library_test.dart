import 'package:flutter_test/flutter_test.dart';
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
}
