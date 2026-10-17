import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';

void main() {
  test('canonical Surah IDs resolve to safe reader numbers', () {
    expect(quranNumberFromRef('quran:1'), 1);
    expect(quranNumberFromRef('quran:2'), 2);
    expect(quranNumberFromRef('quran:114'), 114);
  });

  test('malformed or out-of-range references never become links', () {
    for (final invalid in [
      null,
      '',
      'quran:0',
      'quran:115',
      'quran:../admin',
      'quran:2?redirect=evil',
      'http://evil.test',
      'hadith:2',
    ]) {
      expect(quranNumberFromRef(invalid), isNull);
    }
  });
}
