import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/resource_matcher.dart';
import 'package:sukun_life/features/care_plans/domain/resource_picker_sections.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

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
    builder: (context) =>
        _ResourcePickerSheet(resources: resources, selectedId: selectedId),
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
    final title = selected?.displayTitle ?? 'লাইব্রেরি থেকে উপকরণ বাছুন';
    final subtitle = selected == null
        ? 'প্রকাশিত দুআ, অডিও, ভিডিও, আর্টিকেল ও পিডিএফ খুঁজুন'
        : '${selected.categoryLabel} · ${_displayType(selected.type)}';

    return Semantics(
      button: true,
      label: 'সহায়ক উপকরণ, $title',
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
                        'সহায়ক উপকরণ (ঐচ্ছিক)',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: SukunColors.muted),
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
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: SukunColors.muted),
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
  final _sectionController = PageController(viewportFraction: .72);
  int _sectionIndex = 0;
  DateTime? _lastWheelChange;

  @override
  void dispose() {
    _searchController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _showSection(int index, int sectionCount) {
    if (index < 0 || index >= sectionCount || index == _sectionIndex) return;
    setState(() => _sectionIndex = index);
    _sectionController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSectionWheel(PointerSignalEvent event, int sectionCount) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    final now = DateTime.now();
    if (_lastWheelChange != null &&
        now.difference(_lastWheelChange!) < const Duration(milliseconds: 170)) {
      return;
    }
    _lastWheelChange = now;
    _showSection(
      _sectionIndex + (event.scrollDelta.dy > 0 ? 1 : -1),
      sectionCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections(widget.resources);
    final currentSection =
        sections[_sectionIndex.clamp(0, sections.length - 1)];
    final visible = _filteredResources(currentSection);
    final grouped = currentSection.isOther
        ? <String, List<ContentResourceOption>>{currentSection.label: visible}
        : _groupByCategory(visible);
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
                              'উপকরণ লাইব্রেরি',
                              style: TextStyle(
                                color: SukunColors.deepTide,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'উপকরণ বাছুন',
                              style: TextStyle(
                                color: SukunColors.nightNavy,
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Public Resources-এর প্রকাশিত উপকরণ, ১১৪ সূরা ও '
                              'রুকইয়াহ আয়াত থেকে বাছুন। রোগীর মূল নির্দেশনার '
                              'সঙ্গে মিলিয়ে সহায়ক পাঠ বা অডিও দিন।',
                              style: TextStyle(color: SukunColors.muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'বন্ধ করুন',
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
                      hintText: 'নাম বা বিভাগ দিয়ে খুঁজুন',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'খোঁজার লেখা মুছুন',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'মূল বিভাগ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: SukunColors.nightNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('resource-section-previous'),
                        tooltip: 'আগের বিভাগ',
                        onPressed: _sectionIndex == 0
                            ? null
                            : () => _showSection(
                                _sectionIndex - 1,
                                sections.length,
                              ),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text('${_sectionIndex + 1}/${sections.length}'),
                      IconButton(
                        key: const Key('resource-section-next'),
                        tooltip: 'পরের বিভাগ',
                        onPressed: _sectionIndex == sections.length - 1
                            ? null
                            : () => _showSection(
                                _sectionIndex + 1,
                                sections.length,
                              ),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 76,
                    child: Listener(
                      onPointerSignal: (event) =>
                          _onSectionWheel(event, sections.length),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: PageView.builder(
                          key: const Key('resource-section-carousel'),
                          controller: _sectionController,
                          itemCount: sections.length,
                          onPageChanged: (index) =>
                              setState(() => _sectionIndex = index),
                          itemBuilder: (context, index) => _SectionCard(
                            key: Key(
                              'resource-section-${sections[index].slug}',
                            ),
                            section: sections[index],
                            selected: index == _sectionIndex,
                            onTap: () => _showSection(index, sections.length),
                          ),
                        ),
                      ),
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
                  if (currentSection.slug == 'quran' &&
                      !widget.resources.any(
                        (item) => item.canonicalSurahNumber != null,
                      )) ...[
                    const _EmptyQuranResources(),
                    const SizedBox(height: 12),
                  ],
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

  List<ContentResourceOption> _filteredResources(_PickerSection section) {
    final query = _searchController.text.trim().toLowerCase();
    return widget.resources
        .where((resource) {
          if (!section.matches(resource)) return false;
          if (query.isEmpty) return true;
          return resourceMatchesSearch(resource, query);
        })
        .toList(growable: false);
  }

  Map<String, List<ContentResourceOption>> _groupByCategory(
    List<ContentResourceOption> resources,
  ) {
    final grouped = <String, List<ContentResourceOption>>{};
    for (final resource in resources) {
      final label = resource.canonicalSurahNumber != null
          ? '১১৪ সূরার কুরআন'
          : resource.isEditorialRuqyahExcerpt
          ? resource.categoryLabel
          : resource.categoryId == null
          ? 'অন্যান্য · ${_displayType(resource.type)}'
          : resource.categoryLabel;
      grouped.putIfAbsent(label, () => []).add(resource);
    }
    return grouped;
  }

  List<_PickerSection> _sections(List<ContentResourceOption> resources) {
    final sections = <_PickerSection>[
      _PickerSection(
        slug: 'all',
        label: 'সব উপকরণ',
        icon: Icons.apps_rounded,
        count: resources.length,
      ),
      for (final section in resourceSections)
        _PickerSection(
          slug: section.slug,
          label: section.titleBn,
          icon: section.icon,
          count: resources
              .where(
                (resource) => resourceMatchesPickerSection(resource, section),
              )
              .length,
          section: section,
        ),
    ];
    final otherCount = resources
        .where((resource) => !resourceMatchesAnyPickerSection(resource))
        .length;
    if (otherCount > 0) {
      sections.add(
        _PickerSection(
          slug: 'other',
          label: 'অন্যান্য',
          icon: Icons.more_horiz_rounded,
          count: otherCount,
          isOther: true,
        ),
      );
    }
    return sections;
  }
}

class _PickerSection {
  const _PickerSection({
    required this.slug,
    required this.label,
    required this.icon,
    required this.count,
    this.section,
    this.isOther = false,
  });

  final String slug;
  final String label;
  final IconData icon;
  final int count;
  final ResourceSection? section;
  final bool isOther;

  bool matches(ContentResourceOption resource) {
    if (isOther) return !resourceMatchesAnyPickerSection(resource);
    final selectedSection = section;
    return selectedSection == null ||
        resourceMatchesPickerSection(resource, selectedSection);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _PickerSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Material(
        color: selected ? SukunColors.mist : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? SukunColors.sukunBlue : SukunColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(section.icon, color: SukunColors.deepTide, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: SukunColors.nightNavy,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text('${section.count}'),
              ],
            ),
          ),
        ),
      ),
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
          '$countটি উপকরণ',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SukunColors.muted),
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
    title: 'কোনো উপকরণ নয়',
    subtitle: 'করণীয়টি শুধু নির্দেশনা হিসেবে রাখুন।',
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
      subtitle: !resource.isLinkable
          ? _unavailableReason(resource)
          : resource.canonicalSurahNumber != null
          ? 'Public কুরআন পাঠে খুলবে · সূরা ${resource.canonicalSurahNumber}'
          : resource.isEditorialRuqyahExcerpt
          ? 'সম্পাদিত উৎস-উদ্ধৃতি · পূর্ণ যাচাইকৃত আয়াত নয়'
          : resource.titleBn?.trim().isNotEmpty == true
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
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: SukunColors.muted),
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

class _EmptyQuranResources extends StatelessWidget {
  const _EmptyQuranResources();

  @override
  Widget build(BuildContext context) => const _PickerCard(
    selected: false,
    enabled: false,
    onTap: null,
    icon: Icons.cloud_off_outlined,
    title: '১১৪ সূরার তালিকা আনা যায়নি',
    subtitle: 'কুরআন সংযোগ চালু হলে আবার খুলুন। তালিকা না এলে কোনো সূরা অনুমান করে যুক্ত করা হবে না।',
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
          'কোনো উপকরণ পাওয়া যায়নি',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'অন্য শব্দ দিয়ে খুঁজুন বা বিভাগ বদলান।',
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
  'quran' => 'কুরআন',
  'hadith' => 'হাদিস',
  'dua' => 'দোয়া',
  'amal' => 'আমল',
  'audio' => 'অডিও',
  'video' => 'ভিডিও',
  'pdf' => 'পিডিএফ',
  'book' => 'বই',
  'book_chapter' => 'বইয়ের অধ্যায়',
  'article' => 'আর্টিকেল',
  'guide' => 'গাইড',
  'external_link' => 'বাইরের লিংক',
  _ => 'উপকরণ',
};

String _displayStatus(String value) => switch (value) {
  'published' => 'প্রকাশিত',
  'review' => 'যাচাই চলছে',
  'verified' => 'যাচাইকৃত',
  'archived' => 'সংরক্ষিত',
  _ => 'খসড়া',
};

String _displayVisibility(String value) => switch (value) {
  'patient_only' => 'রোগীদের জন্য',
  'assigned_only' => 'নির্ধারিতদের জন্য',
  'staff_only' => 'শুধু কর্মীদের জন্য',
  _ => 'সবার জন্য',
};

String _unavailableReason(ContentResourceOption resource) {
  if (resource.status != 'published') {
    return 'প্রকাশের আগে রোগীর করণীয়তে যুক্ত করা যাবে না।';
  }
  if (!resource.isPatientAccessible) {
    return 'শুধু কর্মীদের উপকরণ রোগীর করণীয়তে যুক্ত করা যাবে না।';
  }
  return 'উৎস যাচাই ছাড়া কুরআনের উপকরণ যুক্ত করা যাবে না।';
}
