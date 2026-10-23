import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';

/// Purely presentational: all entries remain sourced from the authorized repository.
class DuaAzkarBrowseSection extends StatefulWidget {
  const DuaAzkarBrowseSection({required this.resources, super.key});
  final List<ContentResource> resources;

  @override
  State<DuaAzkarBrowseSection> createState() => _DuaAzkarBrowseSectionState();
}

class _DuaAzkarBrowseSectionState extends State<DuaAzkarBrowseSection> {
  static const reviewSlug = '_unclassified';
  String? _openGroup = 'time-based';
  String? _selectedSlug = 'dua-azkar-morning';

  int _count(String slug) =>
      widget.resources.where((item) => item.categorySlug == slug).length;

  List<ContentResource> get _unclassified => widget.resources
      .where(
        (item) =>
            !duaAzkarTaxonomy.any((entry) => entry.slug == item.categorySlug),
      )
      .toList(growable: false);

  List<ContentResource> get _visible {
    if (_selectedSlug == null) return widget.resources;
    if (_selectedSlug == reviewSlug) return _unclassified;
    return widget.resources
        .where((item) => item.categorySlug == _selectedSlug)
        .toList(growable: false);
  }

  String get _heading {
    if (_selectedSlug == null) return 'সব দোয়া ও আযকার';
    if (_selectedSlug == reviewSlug) return 'বিভাগ নির্ধারণের অপেক্ষায়';
    for (final entry in duaAzkarTaxonomy) {
      if (entry.slug == _selectedSlug) return entry.titleBn;
    }
    return 'দোয়া ও আযকার';
  }

  IconData _icon(String slug) => switch (slug) {
    'time-based' => Icons.schedule_rounded,
    'everyday' => Icons.auto_stories_outlined,
    _ => Icons.health_and_safety_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'বিভাগ বাছাই করুন',
                style: SukunTypography.banglaBody(
                  textStyle: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            OutlinedButton(
              key: const Key('dua-show-all'),
              onPressed: () => setState(() => _selectedSlug = null),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: _selectedSlug == null
                      ? colors.primary
                      : colors.outlineVariant,
                ),
              ),
              child: Text('সব (${widget.resources.length})'),
            ),
          ],
        ),
        // Give the three parent groups a visible, consistent rhythm.
        const SizedBox(height: 16),
        for (final group in duaAzkarNavigationGroups) ...[
          _groupCard(group, context),
          const SizedBox(height: 16),
        ],
        if (_unclassified.isNotEmpty) ...[
          ListTile(
            key: const Key('dua-unclassified'),
            title: const Text('বিভাগ নির্ধারণের অপেক্ষায়'),
            subtitle: Text(
              '${_unclassified.length}টি প্রকাশিত দোয়া যাচাই প্রয়োজন',
            ),
            onTap: () => setState(() {
              _openGroup = null;
              _selectedSlug = reviewSlug;
            }),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            tileColor: colors.surfaceContainerLow,
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _heading,
                key: const Key('dua-results-title'),
                style: SukunTypography.banglaBody(
                  textStyle: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${visible.length}টি',
                style: text.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'এই বিভাগে এখনো প্রকাশিত দোয়া নেই।',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          )
        else
          for (final resource in visible) ...[
            _resourceCard(context, resource),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _groupCard(DuaAzkarNavigationGroup group, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final open = _openGroup == group.slug;
    final count = widget.resources
        .where((item) => group.categorySlugs.contains(item.categorySlug))
        .length;
    return Material(
      key: Key('dua-group-card-${group.slug}'),
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: open
                ? colors.primary.withValues(alpha: 0.4)
                : colors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              key: Key('dua-group-${group.slug}'),
              onTap: () =>
                  setState(() => _openGroup = open ? null : group.slug),
              child: Semantics(
                button: true,
                expanded: open,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _icon(group.slug),
                          size: 22,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.titleBn,
                              style: SukunTypography.banglaBody(
                                textStyle: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${group.categorySlugs.length}টি বিভাগ · $countটি দোয়া/আমল',
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        open
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: open ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1, color: colors.outlineVariant),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  children: [
                    for (final entry in duaAzkarTaxonomy.where(
                      (entry) => group.categorySlugs.contains(entry.slug),
                    ))
                      _subcategoryRow(context, entry),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subcategoryRow(BuildContext context, ResourceTaxonomyEntry entry) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = _selectedSlug == entry.slug;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.13)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('dua-select-${entry.slug}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedSlug = entry.slug),
        child: Semantics(
          button: true,
          selected: selected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.titleBn,
                    style: SukunTypography.banglaBody(
                      textStyle: text.bodyMedium?.copyWith(
                        color: selected ? colors.primary : colors.onSurface,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_count(entry.slug)}',
                  style: text.labelMedium?.copyWith(
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 9),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  size: 19,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resourceCard(BuildContext context, ContentResource resource) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final match = duaAzkarTaxonomy.where(
      (entry) => entry.slug == resource.categorySlug,
    );
    final subtitle = resource.referenceText?.trim().isNotEmpty == true
        ? resource.referenceText!
        : match.isNotEmpty
        ? match.first.titleBn
        : 'দোয়া পড়ুন';
    return Material(
      key: Key('dua-card-${resource.id}'),
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/resources/${resource.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  resource.type == 'amal'
                      ? Icons.checklist_rounded
                      : Icons.menu_book_outlined,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.titleBn ?? resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SukunTypography.banglaBody(
                        textStyle: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
