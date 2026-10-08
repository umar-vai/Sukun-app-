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

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

Set<String> _tokens(String value) =>
    value.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toSet();
