import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';

Future<String?> showResourcePickerSheet({
  required BuildContext context,
  required List<ContentResourceOption> resources,
  required String selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ResourcePickerSheet(
      resources: resources,
      selectedId: selectedId,
    ),
  );
}

class ResourcePickerField extends StatelessWidget {
  const ResourcePickerField({
    super.key,
    required this.resources,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final List<ContentResourceOption> resources;
  final String selectedId;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = resources
        .where((resource) => resource.id == selectedId)
        .firstOrNull;
    final title = selected?.displayTitle ?? 'No linked resource';
    final subtitle = selected == null
        ? 'Browse all resources by category'
        : '${selected.categoryLabel} · ${_displayType(selected.type)}';

    return Semantics(
      button: true,
      label: 'Linked resource, $title',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: !enabled
            ? null
            : () async {
                final result = await showResourcePickerSheet(
                  context: context,
                  resources: resources,
                  selectedId: selectedId,
                );
                if (result != null) onChanged(result);
              },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : .55,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected == null ? Colors.white : SukunColors.mist,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected == null
                    ? SukunColors.border
                    : SukunColors.sukunBlue.withValues(alpha: .45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SukunColors.mist,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected == null
                        ? Icons.link_off_rounded
                        : _iconForType(selected.type),
                    color: SukunColors.deepTide,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Linked resource (optional)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: SukunColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: SukunColors.nightNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SukunColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: SukunColors.deepTide,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourcePickerSheet extends StatefulWidget {
  const _ResourcePickerSheet({
    required this.resources,
    required this.selectedId,
  });

  final List<ContentResourceOption> resources;
  final String selectedId;

  @override
  State<_ResourcePickerSheet> createState() => _ResourcePickerSheetState();
}

class _ResourcePickerSheetState extends State<_ResourcePickerSheet> {
  final _searchController = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories(widget.resources);
    final visible = _filteredResources();
    final grouped = _groupByCategory(visible);
    final selected = widget.resources
        .where((resource) => resource.id == widget.selectedId)
        .firstOrNull;

    return FractionallySizedBox(
      heightFactor: .92,
      child: Material(
        color: const Color(0xFFF7FBFD),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: SukunColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RESOURCE LIBRARY',
                              style: TextStyle(
                                color: SukunColors.deepTide,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Link a resource',
                              style: TextStyle(
                                color: SukunColors.nightNavy,
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Browse every admin resource by category. Only published patient-accessible resources can be linked.',
                              style: TextStyle(color: SukunColors.muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search title, Bangla title, type or category',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: 'All',
                          count: widget.resources.length,
                          selected: _categoryId == null,
                          onTap: () => setState(() => _categoryId = null),
                        ),
                        for (final category in categories) ...[
                          const SizedBox(width: 8),
                          _CategoryChip(
                            label: category.label,
                            count: category.count,
                            selected: _categoryId == category.id,
                            onTap: () =>
                                setState(() => _categoryId = category.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  _ClearResourceTile(selected: selected == null),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const _EmptyResources()
                  else
                    for (final entry in grouped.entries) ...[
                      _CategoryHeader(
                        label: entry.key,
                        count: entry.value.length,
                      ),
                      const SizedBox(height: 8),
                      for (final resource in entry.value) ...[
                        _ResourceTile(
                          resource: resource,
                          selected: resource.id == widget.selectedId,
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ContentResourceOption> _filteredResources() {
    final query = _searchController.text.trim().toLowerCase();
    return widget.resources.where((resource) {
      final categoryMatch = _categoryId == null
          ? true
          : _categoryId == '__uncategorized__'
          ? resource.categoryId == null
          : resource.categoryId == _categoryId;
      if (!categoryMatch) return false;
      if (query.isEmpty) return true;
      return [
        resource.title,
        resource.titleBn ?? '',
        resource.type,
        resource.categoryLabel,
        resource.status,
        resource.visibility,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  Map<String, List<ContentResourceOption>> _groupByCategory(
    List<ContentResourceOption> resources,
  ) {
    final grouped = <String, List<ContentResourceOption>>{};
    for (final resource in resources) {
      grouped.putIfAbsent(resource.categoryLabel, () => []).add(resource);
    }
    return grouped;
  }

  List<_CategoryInfo> _categories(List<ContentResourceOption> resources) {
    final categories = <String, _CategoryInfo>{};
    var uncategorized = 0;
    for (final resource in resources) {
      if (resource.categoryId == null) {
        uncategorized += 1;
        continue;
      }
      final current = categories[resource.categoryId!];
      categories[resource.categoryId!] = _CategoryInfo(
        id: resource.categoryId!,
        label: resource.categoryLabel,
        count: (current?.count ?? 0) + 1,
        sortOrder: resource.categorySortOrder,
      );
    }
    final result = categories.values.toList()
      ..sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0
            ? order
            : left.label.toLowerCase().compareTo(right.label.toLowerCase());
      });
    if (uncategorized > 0) {
      result.add(
        _CategoryInfo(
          id: '__uncategorized__',
          label: 'Uncategorized',
          count: uncategorized,
          sortOrder: 9999,
        ),
      );
    }
    return result;
  }
}

class _CategoryInfo {
  const _CategoryInfo({
    required this.id,
    required this.label,
    required this.count,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final int count;
  final int sortOrder;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text('$label · $count'),
      avatar: selected ? const Icon(Icons.check_rounded, size: 16) : null,
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: SukunColors.nightNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count resource${count == 1 ? '' : 's'}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: SukunColors.muted),
        ),
      ],
    ),
  );
}

class _ClearResourceTile extends StatelessWidget {
  const _ClearResourceTile({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => _PickerCard(
    selected: selected,
    enabled: true,
    onTap: () => Navigator.pop(context, ''),
    icon: Icons.link_off_rounded,
    title: 'No linked resource',
    subtitle: 'Keep this action text-only.',
    trailing: selected ? const _SelectedMark() : null,
  );
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.resource, required this.selected});

  final ContentResourceOption resource;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return _PickerCard(
      selected: selected,
      enabled: resource.isLinkable,
      onTap: resource.isLinkable
          ? () => Navigator.pop(context, resource.id)
          : null,
      icon: _iconForType(resource.type),
      title: resource.displayTitle,
      subtitle: resource.titleBn?.trim().isNotEmpty == true
          ? resource.title
          : resource.linkabilityMessage,
      meta: [
        _MetaBadge(label: _displayType(resource.type)),
        _MetaBadge(
          label: _displayStatus(resource.status),
          emphasized: resource.status == 'published',
        ),
        _MetaBadge(label: _displayVisibility(resource.visibility)),
      ],
      trailing: selected
          ? const _SelectedMark()
          : resource.isLinkable
          ? const Icon(Icons.chevron_right_rounded, color: SukunColors.muted)
          : const Icon(Icons.lock_outline_rounded, color: SukunColors.muted),
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.meta = const [],
    this.trailing,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> meta;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .62,
      child: Material(
        color: selected ? SukunColors.mist : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? SukunColors.sukunBlue : SukunColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SukunColors.mist,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: SukunColors.deepTide),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SukunColors.muted,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Wrap(spacing: 6, runSpacing: 6, children: meta),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: emphasized ? SukunColors.mist : const Color(0xFFF1F5F7),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: emphasized ? SukunColors.deepTide : SukunColors.muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _SelectedMark extends StatelessWidget {
  const _SelectedMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: const BoxDecoration(
      color: SukunColors.sukunBlue,
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.check_rounded, size: 17, color: Colors.white),
  );
}

class _EmptyResources extends StatelessWidget {
  const _EmptyResources();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
    child: Column(
      children: [
        const Icon(
          Icons.search_off_rounded,
          size: 42,
          color: SukunColors.muted,
        ),
        const SizedBox(height: 12),
        Text(
          'No resources found',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Try another search or category.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

IconData _iconForType(String type) => switch (type) {
  'audio' => Icons.headphones_rounded,
  'video' => Icons.play_circle_outline_rounded,
  'quran' => Icons.menu_book_rounded,
  'hadith' => Icons.auto_stories_rounded,
  'dua' => Icons.volunteer_activism_outlined,
  'amal' => Icons.task_alt_rounded,
  'pdf' => Icons.picture_as_pdf_outlined,
  'book' || 'book_chapter' => Icons.library_books_outlined,
  'article' || 'guide' => Icons.article_outlined,
  'external_link' => Icons.open_in_new_rounded,
  _ => Icons.library_books_outlined,
};

String _displayType(String value) => switch (value) {
  'quran' => 'Qur’an',
  'book_chapter' => 'Book chapter',
  'external_link' => 'External link',
  _ => value.isEmpty
      ? 'Resource'
      : '${value[0].toUpperCase()}${value.substring(1)}',
};

String _displayStatus(String value) => switch (value) {
  'published' => 'Published',
  'review' => 'In review',
  'verified' => 'Verified',
  'archived' => 'Archived',
  _ => 'Draft',
};

String _displayVisibility(String value) => switch (value) {
  'patient_only' => 'Patients',
  'assigned_only' => 'Assigned only',
  'staff_only' => 'Staff only',
  _ => 'Public',
};
