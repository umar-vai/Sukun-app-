import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/features/resources/domain/resource_search.dart';

/// The list of live suggestions shown right under a search field while the
/// person is still typing. Shared by the Resources tab and the Admin library.
class LiveSearchSuggestionList<T> extends StatelessWidget {
  const LiveSearchSuggestionList({
    super.key,
    required this.query,
    required this.suggestions,
    required this.totalMatches,
    required this.onSelect,
    required this.onShowAll,
    this.iconFor,
  });

  final String query;
  final List<SearchSuggestion<T>> suggestions;
  final int totalMatches;
  final ValueChanged<SearchSuggestion<T>> onSelect;
  final VoidCallback onShowAll;
  final IconData Function(SearchSuggestion<T> suggestion)? iconFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Part of the search field's tap region: tapping a suggestion must not
    // first unfocus the field (and hide the list) on web and desktop.
    return TextFieldTapRegion(child: _panel(context, theme, scheme));
  }

  Widget _panel(BuildContext context, ThemeData theme, ColorScheme scheme) {
    return Material(
      key: const Key('live-search-suggestions'),
      color: scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (suggestions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  'কোনো মিল পাওয়া যায়নি। অন্য বানানে লিখে দেখুন।',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (var i = 0; i < suggestions.length; i++)
              InkWell(
                key: Key('live-search-suggestion-$i'),
                onTap: () => onSelect(suggestions[i]),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                  child: Row(
                    children: [
                      Icon(
                        iconFor?.call(suggestions[i]) ??
                            (suggestions[i].item == null
                                ? Icons.folder_open_rounded
                                : Icons.north_west_rounded),
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HighlightedText(
                          text: suggestions[i].label,
                          query: query,
                          style: SukunTypography.banglaBody(
                            textStyle: theme.textTheme.bodyMedium,
                          ),
                          highlight: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        suggestions[i].item == null && suggestions[i].count > 0
                            ? '${suggestions[i].kind} · ${suggestions[i].count}'
                            : suggestions[i].kind,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (totalMatches > 0) ...[
              Divider(height: 1, color: scheme.outlineVariant),
              InkWell(
                key: const Key('live-search-show-all'),
                onTap: onShowAll,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '“$query” সম্পর্কিত সব $totalMatchesটি ফলাফল দেখুন',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bolds the first part of [text] that matches the query, so the person
/// sees why a suggestion appeared. Falls back to plain text.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlight,
  });

  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlight;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final index = needle.isEmpty ? -1 : text.toLowerCase().indexOf(needle);
    if (index < 0) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + needle.length),
            style: highlight,
          ),
          TextSpan(text: text.substring(index + needle.length)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Horizontal kind filter chips (সব, দোয়া ও আমল, অডিও, পিডিএফ ...). Only
/// kinds that have at least one match are shown, with their counts.
class SearchKindChips extends StatelessWidget {
  const SearchKindChips({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  /// Matches per filter slug; 'all' holds the total.
  final Map<String, int> counts;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = [
      for (final filter in searchKindFilters)
        if (filter.slug == 'all' || (counts[filter.slug] ?? 0) > 0) filter,
    ];
    return SingleChildScrollView(
      key: const Key('search-kind-chips'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              key: Key('search-kind-${filter.slug}'),
              label: Text('${filter.label} (${counts[filter.slug] ?? 0})'),
              selected: selected == filter.slug,
              onSelected: (_) => onSelected(filter.slug),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Counts of [types] per kind filter, for [SearchKindChips].
Map<String, int> searchKindCounts(Iterable<String> types) {
  final counts = <String, int>{'all': 0};
  for (final type in types) {
    counts['all'] = counts['all']! + 1;
    for (final filter in searchKindFilters) {
      if (filter.types.contains(type)) {
        counts[filter.slug] = (counts[filter.slug] ?? 0) + 1;
      }
    }
  }
  return counts;
}

/// Whether [type] passes the kind filter [slug].
bool searchKindAccepts(String slug, String type) {
  if (slug == 'all') return true;
  for (final filter in searchKindFilters) {
    if (filter.slug == slug) return filter.types.contains(type);
  }
  return true;
}
