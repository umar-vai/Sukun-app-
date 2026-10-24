import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';

/// Distinct route pages: group index → group categories → published content.
/// Every page displays only records provided by the authorized repository.
class DuaAzkarBrowseSection extends StatelessWidget {
  const DuaAzkarBrowseSection({
    required this.resources,
    this.groupSlug,
    this.categorySlug,
    super.key,
  });

  final List<ContentResource> resources;
  final String? groupSlug;
  final String? categorySlug;

  static const reviewSlug = '_unclassified';

  List<ContentResource> get _unclassified => resources
      .where(
        (item) =>
            !duaAzkarTaxonomy.any((entry) => entry.slug == item.categorySlug),
      )
      .toList(growable: false);

  int _count(String slug) =>
      resources.where((item) => item.categorySlug == slug).length;

  DuaAzkarNavigationGroup? get _group {
    for (final group in duaAzkarNavigationGroups) {
      if (group.slug == groupSlug) return group;
    }
    return null;
  }

  ResourceTaxonomyEntry? get _category {
    for (final entry in duaAzkarTaxonomy) {
      if (entry.slug == categorySlug) return entry;
    }
    return null;
  }

  static String titleFor(String? groupSlug, String? categorySlug) {
    if (categorySlug == reviewSlug) return 'অন্যান্য দোয়া';
    for (final category in duaAzkarTaxonomy) {
      if (category.slug == categorySlug) return category.titleBn;
    }
    if (groupSlug == 'all') return 'সব দোয়া ও আযকার';
    for (final group in duaAzkarNavigationGroups) {
      if (group.slug == groupSlug) return group.titleBn;
    }
    return 'দোয়া ও আযকার';
  }

  IconData _icon(String slug) => switch (slug) {
    'time-based' => Icons.schedule_rounded,
    'everyday' => Icons.auto_stories_outlined,
    'support' => Icons.health_and_safety_outlined,
    _ => Icons.menu_book_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (groupSlug == null) return _index(context);
    if (groupSlug == 'all') return _items(context, resources);
    final group = _group;
    if (group == null) return _empty(context);
    if (categorySlug == null) return _subcategories(context, group);
    if (categorySlug == reviewSlug) {
      return groupSlug == 'other'
          ? _items(context, _unclassified)
          : _empty(context);
    }
    final category = _category;
    if (category == null || !group.categorySlugs.contains(category.slug)) {
      return _empty(context);
    }
    return _items(
      context,
      resources.where((item) => item.categorySlug == category.slug).toList(),
    );
  }

  Widget _index(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'বিভাগ নির্বাচন করুন',
        style: SukunTypography.banglaBody(
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 16),
      for (final group in duaAzkarNavigationGroups) ...[
        _categoryCard(
          context,
          key: Key('dua-group-card-${group.slug}'),
          title: group.titleBn,
          subtitle:
              '${group.categorySlugs.length}টি বিভাগ · ${resources.where((item) => group.categorySlugs.contains(item.categorySlug)).length}টি দোয়া/আমল',
          icon: _icon(group.slug),
          onTap: () => context.push('/resources/dua-azkar/${group.slug}'),
        ),
        const SizedBox(height: 16),
      ],
      _categoryCard(
        context,
        key: const Key('dua-show-all'),
        title: 'সব দোয়া ও আযকার',
        subtitle: '${resources.length}টি দোয়া/আমল',
        icon: Icons.library_books_outlined,
        onTap: () => context.push('/resources/dua-azkar/all'),
      ),
      if (_unclassified.isNotEmpty) ...[
        const SizedBox(height: 16),
        _categoryCard(
          context,
          key: const Key('dua-unclassified'),
          title: 'অন্যান্য দোয়া',
          subtitle: '${_unclassified.length}টি দোয়া/আমল',
          icon: Icons.book_outlined,
          onTap: () => context.push('/resources/dua-azkar/other/$reviewSlug'),
        ),
      ],
    ],
  );

  Widget _subcategories(BuildContext context, DuaAzkarNavigationGroup group) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'বিভাগ নির্বাচন করুন',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          for (final category in duaAzkarTaxonomy.where(
            (entry) => group.categorySlugs.contains(entry.slug),
          )) ...[
            _categoryCard(
              context,
              key: Key('dua-select-${category.slug}'),
              title: category.titleBn,
              subtitle: '${_count(category.slug)}টি দোয়া/আমল',
              icon: Icons.auto_stories_outlined,
              onTap: () => context.push(
                '/resources/dua-azkar/${group.slug}/${category.slug}',
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );

  Widget _items(BuildContext context, List<ContentResource> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (items.isEmpty)
        _empty(context)
      else
        for (final item in items) ...[
          Material(
            key: Key('dua-card-${item.id}'),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(
                item.titleBn?.trim().isNotEmpty == true
                    ? item.titleBn!
                    : item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SukunTypography.banglaBody(
                  textStyle: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              subtitle: item.referenceText?.trim().isNotEmpty == true
                  ? Text(
                      item.referenceText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(
                '/resources/${Uri.encodeComponent(item.id)}',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
    ],
  );

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      'এই বিভাগে এখনো প্রকাশিত দোয়া নেই।',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _categoryCard(
    BuildContext context, {
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SukunTypography.banglaBody(
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
