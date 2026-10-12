import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';

class ResourceMatch {
  const ResourceMatch({required this.resource, required this.score});

  final ContentResourceOption resource;
  final double score;
}

List<ResourceMatch> matchResources(
  String? query,
  List<ContentResourceOption> resources, {
  int limit = 3,
}) {
  final normalizedQuery = _normalize(query ?? '');
  if (normalizedQuery.isEmpty || limit <= 0) return const [];
  // A numeric Qur'an citation is an exact identifier, not fuzzy search.
  // Never substitute a similarly named ayah or an unverified draft.
  final reference = _parseVerseReference(query?.trim() ?? '');
  if (reference != null) {
    final result = resources
        .where((resource) {
          if (!resource.isLinkable ||
              resource.surahNumber != reference.$1 ||
              resource.ayahNumber != reference.$2 ||
              (resource.ayahEndNumber ?? resource.ayahNumber) != reference.$3) {
            return false;
          }
          if (resource.type == 'quran') return true;
          final uri = Uri.tryParse(resource.mediaUrl ?? '');
          return resource.type == 'audio' &&
              resource.mediaSourceType == 'direct_audio_url' &&
              uri?.scheme == 'https' &&
              uri?.host.isNotEmpty == true;
        })
        .map((resource) => ResourceMatch(resource: resource, score: 1.0))
        .take(limit)
        .toList(growable: false);
    return List.unmodifiable(result);
  }
  if (RegExp(r'[0-9০-৯]+\s*:').hasMatch(query ?? '')) {
    return const []; // Invalid numeric citation must not fuzzy-match.
  }
  final queryTokens = _tokens(normalizedQuery);
  final matches = <ResourceMatch>[];
  for (final resource in resources) {
    if (!resource.isLinkable) continue;
    final labels = [
      resource.title,
      if (resource.titleBn != null) resource.titleBn!,
    ];
    var bestScore = 0.0;
    for (final label in labels) {
      final normalizedLabel = _normalize(label);
      if (normalizedLabel == normalizedQuery) {
        bestScore = 1;
        break;
      }
      if (normalizedLabel.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedLabel)) {
        bestScore = bestScore < 0.85 ? 0.85 : bestScore;
      }
      final labelTokens = _tokens(normalizedLabel);
      final union = {...queryTokens, ...labelTokens};
      if (union.isNotEmpty) {
        final overlap =
            queryTokens.intersection(labelTokens).length / union.length;
        if (overlap > bestScore) bestScore = overlap;
      }
    }
    if (bestScore >= 0.34) {
      matches.add(ResourceMatch(resource: resource, score: bestScore));
    }
  }
  matches.sort((left, right) {
    final scoreOrder = right.score.compareTo(left.score);
    return scoreOrder != 0
        ? scoreOrder
        : left.resource.title.compareTo(right.resource.title);
  });
  return List.unmodifiable(matches.take(limit));
}

// Preserve Bengali vowel signs and Arabic letters rather than stripping all
// combining marks. Normalize Bengali ya variants for consistent suggestions.
// This only ranks existing published resources; it never creates religious text
// or automatically assigns a content ID to a patient.
String _normalize(String value) => value
    .toLowerCase()
    .replaceAll('য়', 'য়')
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}]+', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Set<String> _tokens(String value) =>
    value.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toSet();

// Numeric references are supplied by the conservative AI parser as e.g.
// "2:255", "Surah 2 Ayah 255", or "সূরা ২ আয়াত ২৫৫".
// Return (surah, first ayah, last ayah) only for an unambiguous citation.
(int, int, int)? _parseVerseReference(String value) {
  final candidate = value.toLowerCase().trim();
  final match = RegExp(
    r'^(?:(?:surah|sura|surat|সূরা|সূরাহ|quran|কুরআন)\s*)?'
    r'([0-9০-৯]{1,3})\s*(?::|[,\s]+(?:ayah|ayat|আয়াত)\s*)'
    r'([0-9০-৯]{1,3})(?:\s*[-–]\s*([0-9০-৯]{1,3}))?$',
  ).firstMatch(candidate);
  if (match == null) return null;

  int digits(String input) => int.parse(
    input.split('').map((digit) {
      final code = digit.codeUnitAt(0);
      return code >= 0x09E6 && code <= 0x09EF
          ? String.fromCharCode(code - 0x09E6 + 0x30)
          : digit;
    }).join(),
  );
  final surah = digits(match.group(1)!);
  final start = digits(match.group(2)!);
  final end = match.group(3) == null ? start : digits(match.group(3)!);
  if (surah < 1 || surah > 114 || start < 1 || end < start || end > 286) {
    return null;
  }
  return (surah, start, end);
}
