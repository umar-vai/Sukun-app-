import 'dart:convert';

import 'package:http/http.dart' as http;

/// Quran text is fetched on demand; no verse corpus or audio is bundled.
class OnlineQuranRepository {
  const OnlineQuranRepository();

  static const _base = 'https://api.alquran.cloud/v1';

  Future<dynamic> _get(String path) async {
    final response = await http.get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) {
      throw StateError('Quran service returned HTTP ${response.statusCode}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic> || json['code'] != 200) {
      throw const FormatException('Unexpected Quran API response');
    }
    return json['data'];
  }

  Future<List<OnlineSurah>> allSurahs() async {
    final data = await _get('/surah');
    if (data is! List) throw const FormatException('Missing surah list');
    final chapters = data.map((item) =>
        OnlineSurah.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    if (chapters.length != 114) {
      throw StateError('Expected 114 surahs; received ${chapters.length}');
    }
    return chapters;
  }

  Future<OnlineSurahDetails> surah(int number) async {
    if (number < 1 || number > 114) throw RangeError.range(number, 1, 114);
    // One HTTP call returns aligned Arabic, Bangla translation, and
    // Mishary Alafasy verse-level audio. Audio is streamed, not stored.
    final data = await _get(
      '/surah/$number/editions/quran-uthmani,bn.bengali,ar.alafasy',
    );
    if (data is! List || data.length != 3) {
      throw const FormatException('Missing Quran editions');
    }
    final editions = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    List<dynamic> ayahs(int index) =>
        (editions[index]['ayahs'] as List<dynamic>? ?? const []);
    final ar = ayahs(0), bn = ayahs(1), audio = ayahs(2);
    if (ar.isEmpty || ar.length != bn.length || ar.length != audio.length) {
      throw const FormatException('Quran edition lengths disagree');
    }
    final verses = <OnlineVerse>[];
    for (var i = 0; i < ar.length; i++) {
      final arabic = Map<String, dynamic>.from(ar[i] as Map);
      final bangla = Map<String, dynamic>.from(bn[i] as Map);
      final recitation = Map<String, dynamic>.from(audio[i] as Map);
      final ayah = arabic['numberInSurah'] as int;
      if (ayah != bangla['numberInSurah'] ||
          ayah != recitation['numberInSurah']) {
        throw const FormatException('Mismatched verse numbering');
      }
      final audioUrl = recitation['audio'] as String?;
      verses.add(OnlineVerse(
        number: ayah,
        arabic: arabic['text'] as String? ?? '',
        translationBn: bangla['text'] as String? ?? '',
        audioUrl: audioUrl != null &&
                Uri.tryParse(audioUrl)?.scheme == 'https' ? audioUrl : null,
      ));
    }
    return OnlineSurahDetails(
      name: editions[0]['englishName'] as String? ?? 'Surah $number',
      verses: verses,
    );
  }
}

class OnlineSurah {
  const OnlineSurah({
    required this.number, required this.name,
    required this.arabicName, required this.verseCount,
  });
  factory OnlineSurah.fromJson(Map<String, dynamic> data) => OnlineSurah(
    number: data['number'] as int,
    name: data['englishName'] as String? ?? '',
    arabicName: data['name'] as String? ?? '',
    verseCount: data['numberOfAyahs'] as int? ?? 0,
  );
  final int number;
  final String name;
  final String arabicName;
  final int verseCount;
}

class OnlineSurahDetails {
  const OnlineSurahDetails({required this.name, required this.verses});
  final String name;
  final List<OnlineVerse> verses;
}

class OnlineVerse {
  const OnlineVerse({
    required this.number, required this.arabic,
    required this.translationBn, this.audioUrl,
  });
  final int number;
  final String arabic;
  final String translationBn;
  final String? audioUrl;
}
