/// Live, partial-word search shared by the public Resources tab and the
/// Admin content library picker.
///
/// Typing only part of a word already matches ("তা" finds "তাসবিহ"), and
/// common Bangla spelling variants are folded so "তাসবীহ", "তাসবিহ" and
/// "তাসবিহ্‌" find the same items. This only filters records the caller
/// already loaded through RLS; it never widens what a person may see.
library;

/// Folds a string into a comparable search key: lower case, Bangla vowel
/// length and sibilant variants merged, zero-width joiners and hasanta at
/// word ends removed, Bangla digits turned into ASCII digits, and every run
/// of punctuation collapsed to one space.
String normalizeSearchText(String input) {
  if (input.isEmpty) return '';
  final buffer = StringBuffer();
  final lower = input.toLowerCase();
  final runes = lower.runes.toList(growable: false);
  for (var i = 0; i < runes.length; i++) {
    final rune = runes[i];
    // Decomposed nukta forms read the same as the single letters:
    // য + ় → য়, ড + ় → ড়, ঢ + ় → ঢ়.
    if (i + 1 < runes.length && runes[i + 1] == 0x09BC) {
      final composed = switch (rune) {
        0x09AF => 0x09DF,
        0x09A1 => 0x09A1,
        0x09A2 => 0x09A2,
        _ => null,
      };
      if (composed != null) {
        buffer.writeCharCode(composed);
        i++;
        continue;
      }
    }
    if (rune == 0x09BC) continue;
    final folded = _banglaFold[rune];
    if (folded != null) {
      if (folded.isNotEmpty) buffer.write(folded);
      continue;
    }
    if (rune >= 0x09E6 && rune <= 0x09EF) {
      buffer.writeCharCode(rune - 0x09E6 + 0x30);
      continue;
    }
    if (_isWordRune(rune)) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write(' ');
    }
  }
  return buffer
      .toString()
      // A trailing hasanta (্) changes nothing a person types to search.
      .replaceAll(RegExp('\u09CD(?=\\s|\$)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Bangla letters people commonly spell either way in search.
const _banglaFold = <int, String>{
  0x200C: '', // zero width non-joiner
  0x200D: '', // zero width joiner
  0x0981: '', // ঁ chandrabindu
  0x09C0: '\u09BF', // ী → ি
  0x09C2: '\u09C1', // ূ → ু
  0x0988: '\u0987', // ঈ → ই
  0x098A: '\u0989', // ঊ → উ
  0x09DC: '\u09A1', // ড় → ড
  0x09DD: '\u09A2', // ঢ় → ঢ
  0x09A3: '\u09A8', // ণ → ন
  0x09B6: '\u09B8', // শ → স
  0x09B7: '\u09B8', // ষ → স
  0x09CE: '\u09A4', // ৎ → ত
  0x09AF: '\u099C', // য → জ (যিকর / জিকর)
};

bool _isWordRune(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return true; // 0-9
  if (rune >= 0x61 && rune <= 0x7A) return true; // a-z
  if (rune >= 0x0980 && rune <= 0x09FF) return true; // Bangla block
  if (rune >= 0x0600 && rune <= 0x06FF) return true; // Arabic
  if (rune >= 0x0750 && rune <= 0x077F) return true; // Arabic supplement
  if (rune >= 0x00C0 && rune <= 0x024F) return true; // Latin accents
  return false;
}

/// The terms of a query, already normalized. Empty when nothing to search.
List<String> searchTerms(String query) {
  final normalized = normalizeSearchText(query);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ').toSet().toList(growable: false);
}

/// Display words for each content type, so typing "অডিও" or "পিডিএফ" lists
/// every item of that kind.
String searchTypeLabel(String type) => switch (type) {
  'quran' => 'কুরআন quran',
  'hadith' => 'হাদিস hadith',
  'dua' => 'দোয়া দুআ dua যিকর জিকির আযকার',
  'amal' => 'আমল amal দোয়া যিকর',
  'audio' => 'অডিও audio',
  'video' => 'ভিডিও video',
  'pdf' => 'পিডিএফ pdf বই',
  'book' || 'book_chapter' => 'বই book',
  'article' => 'আর্টিকেল প্রবন্ধ article ব্লগ',
  'guide' => 'গাইড guide নির্দেশিকা',
  _ => type,
};

/// One searchable record, prepared once so each keystroke is cheap.
class SearchDocument<T> {
  SearchDocument({
    required this.item,
    required String title,
    String? altTitle,
    Iterable<String?> details = const [],
  }) : title = normalizeSearchText(title),
       altTitle = normalizeSearchText(altTitle ?? ''),
       details = normalizeSearchText(details.whereType<String>().join(' '));

  final T item;
  final String title;
  final String altTitle;
  final String details;

  /// 0 when the document does not contain every term; higher is better.
  int score(List<String> terms, String phrase) {
    if (terms.isEmpty) return 0;
    var total = 0;
    for (final term in terms) {
      final best = _termScore(term);
      if (best == 0) return 0;
      total += best;
    }
    if (phrase.isNotEmpty) {
      if (title == phrase || altTitle == phrase) {
        total += 200;
      } else if (title.startsWith(phrase) || altTitle.startsWith(phrase)) {
        total += 120;
      } else if (title.contains(phrase) || altTitle.contains(phrase)) {
        total += 60;
      }
    }
    return total;
  }

  int _termScore(String term) {
    int scoreIn(String field, int wordStart, int inside) {
      if (field.isEmpty) return 0;
      if (field.startsWith(term) || field.contains(' $term')) return wordStart;
      return field.contains(term) ? inside : 0;
    }

    final best = [
      scoreIn(title, 40, 20),
      scoreIn(altTitle, 40, 20),
      scoreIn(details, 10, 5),
    ];
    return best.reduce((a, b) => a > b ? a : b);
  }
}

/// Ranked matches for [query]. Ties keep the incoming (curated) order.
List<T> rankSearch<T>(List<SearchDocument<T>> documents, String query) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return const [];
  final phrase = normalizeSearchText(query);
  final scored = <(int, int, T)>[];
  for (var i = 0; i < documents.length; i++) {
    final score = documents[i].score(terms, phrase);
    if (score > 0) scored.add((score, i, documents[i].item));
  }
  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
  });
  return [for (final entry in scored) entry.$3];
}

/// Whether [query] matches the document at all (every term present).
bool searchMatches(SearchDocument<Object?> document, String query) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return true;
  return document.score(terms, normalizeSearchText(query)) > 0;
}

/// A suggestion shown under the search field while typing.
class SearchSuggestion<T> {
  const SearchSuggestion({
    required this.label,
    required this.kind,
    this.item,
    this.count = 0,
  });

  /// Text shown to the person (original spelling, not normalized).
  final String label;

  /// Short Bangla type label such as "অডিও" or "বিভাগ".
  final String kind;

  /// The matching record, or null when the suggestion is a word/category.
  final T? item;

  /// How many records the suggestion leads to, for category suggestions.
  final int count;
}

/// Up to [limit] distinct suggestions: matching category names first (they
/// lead to many items), then the best matching item titles.
List<SearchSuggestion<T>> buildSearchSuggestions<T>({
  required String query,
  required List<T> rankedMatches,
  required String Function(T item) titleOf,
  required String Function(T item) kindOf,
  String? Function(T item)? categoryOf,
  int limit = 6,
}) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return const [];
  final suggestions = <SearchSuggestion<T>>[];
  final seen = <String>{};
  if (categoryOf != null) {
    final counts = <String, int>{};
    for (final item in rankedMatches) {
      final category = categoryOf(item)?.trim();
      if (category == null || category.isEmpty) continue;
      final key = normalizeSearchText(category);
      if (!terms.every(key.contains)) continue;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    for (final entry in counts.entries.take(2)) {
      if (seen.add(normalizeSearchText(entry.key))) {
        suggestions.add(
          SearchSuggestion<T>(
            label: entry.key,
            kind: 'বিভাগ',
            count: entry.value,
          ),
        );
      }
    }
  }
  for (final item in rankedMatches) {
    if (suggestions.length >= limit) break;
    final title = titleOf(item).trim();
    if (title.isEmpty || !seen.add(normalizeSearchText(title))) continue;
    suggestions.add(
      SearchSuggestion<T>(label: title, kind: kindOf(item), item: item),
    );
  }
  return suggestions;
}

/// Short Bangla name of a content type for result badges.
String searchKindLabel(String type) => switch (type) {
  'quran' => 'কুরআন',
  'hadith' => 'হাদিস',
  'dua' => 'দোয়া',
  'amal' => 'আমল',
  'audio' => 'অডিও',
  'video' => 'ভিডিও',
  'pdf' => 'পিডিএফ',
  'book' || 'book_chapter' => 'বই',
  'article' => 'আর্টিকেল',
  'guide' => 'গাইড',
  _ => 'উপকরণ',
};

/// Result filter chips: the content kinds people pick between.
class SearchKindFilter {
  const SearchKindFilter(this.slug, this.label, this.types);

  final String slug;
  final String label;
  final Set<String> types;
}

const searchKindFilters = <SearchKindFilter>[
  SearchKindFilter('all', 'সব', {}),
  SearchKindFilter('dua', 'দোয়া ও আমল', {'dua', 'amal'}),
  SearchKindFilter('audio', 'অডিও', {'audio'}),
  SearchKindFilter('pdf', 'পিডিএফ ও বই', {'pdf', 'book', 'book_chapter'}),
  SearchKindFilter('read', 'আর্টিকেল ও গাইড', {'article', 'guide'}),
  SearchKindFilter('hadith', 'হাদিস', {'hadith'}),
  SearchKindFilter('video', 'ভিডিও', {'video'}),
];
