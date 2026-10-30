import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';

void main() {
  test('canonical Surah IDs resolve to safe reader numbers', () {
    expect(quranNumberFromRef('quran:1'), 1);
    expect(quranNumberFromRef('quran:2'), 2);
    expect(quranNumberFromRef('quran:114'), 114);
  });

  test('specific Quran ayah deep links resolve safely', () {
    expect(quranNumberFromRef('quran:2:255'), 2);
    expect(quranAyahNumberFromRef('quran:2:255'), 255);
    expect(quranNumberFromRef('quran:114:6'), 114);
    expect(quranAyahNumberFromRef('quran:114:6'), 6);
    expect(quranAyahNumberFromRef('quran:2'), isNull);
    for (final bad in ['quran:2:0', 'quran:2:287', 'quran:115:1']) {
      expect(quranNumberFromRef(bad), isNull);
      expect(quranAyahNumberFromRef(bad), isNull);
    }
  });

  test('malformed or out-of-range references never become links', () {
    for (final invalid in [
      null,
      '',
      'quran:0',
      'quran:115',
      'quran:../admin',
      'quran:2?redirect=evil',
      'quran:-1',
      'quran:1/../../admin',
      'http://evil.test',
      'hadith:2',
    ]) {
      expect(quranNumberFromRef(invalid), isNull);
    }
  });
}
