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

/// Prefill only a unique, exact, published and type-compatible match.
/// A fuzzy title match, unverified Qur'an, ambiguous duplicate or a listening
/// URL with no verified direct HTTPS source is NEVER silently assigned.
ContentResourceOption? exactReviewResource(
  List<ResourceMatch> matches, {
  required String actionType,
}) {
  final exact = matches
      .where((match) => match.score >= 0.999 && match.resource.isLinkable)
      .toList(growable: false);
  if (exact.length != 1) return null;
  final resource = exact.single.resource;
  final accepted = switch (actionType.toLowerCase().trim()) {
    'quran' || 'recitation' || 'verse' =>
      resource.type == 'quran' && resource.verificationStatus == 'verified',
    'dua' || 'supplication' => resource.type == 'dua',
    'amal' => resource.type == 'amal',
    'audio' || 'listening' =>
      resource.type == 'audio' &&
          resource.mediaSourceType == 'direct_audio_url' &&
          Uri.tryParse(resource.mediaUrl ?? '')?.scheme == 'https',
    _ => false,
  };
  return accepted ? resource : null;
}

// Preserve Bengali vowel signs and Arabic letters rather than stripping all
// combining marks. Normalize Bengali ya variants for consistent suggestions.
// This only ranks existing published resources; it never creates religious text
// or automatically assigns a content ID to a patient.
///
/// Search-only transliterations for *names*, not scriptural evidence.
/// This makes a published Bengali title discoverable from an English action.
/// Fuzzy matches still require explicit Admin selection; they are never
/// silently treated as verified Quran verses or complete routines.
String _normalize(String value) => value
    .toLowerCase()
    .replaceAll('য়', 'য়')
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
    .replaceAll(RegExp(r'\b(?:surah|sura|surat)\b'), 'সূরা')
    .replaceAll(RegExp(r'\b(?:al[-\s]*)?baqarah?\b'), 'বাকারা')
    .replaceAll(RegExp(r'\b(?:bedtime|sleeping|sleep)\b'), 'ঘুম')
    .replaceAll(RegExp(r'\b(?:masnun|masnoon)\b'), 'মাসনুন')
    .replaceAll(RegExp(r'(?:সুরা|সূরাহ)'), 'সূরা')
    .replaceAll('বাকারাহ', 'বাকারা')
    .replaceAll(RegExp(r'ঘুমানো|ঘুমানোর'), 'ঘুম')
    .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}]+', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The Admin picker and AI suggestion matcher share the same bilingual
/// title normalization. Only fields already returned by the approved library
/// are searched; this never creates or approves a content item.
bool resourceMatchesSearch(ContentResourceOption resource, String query) {
  final normalized = _normalize(query.trim());
  if (normalized.isEmpty) return true;
  return [
    resource.title,
    resource.titleBn ?? '',
    resource.type,
    resource.categoryLabel,
  ].any((label) => _normalize(label).contains(normalized));
}

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
