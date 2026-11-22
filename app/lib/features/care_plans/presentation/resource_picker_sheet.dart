import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/resource_picker_sections.dart';
import 'package:sukun_life/features/resources/domain/resource_library_navigation.dart';
import 'package:sukun_life/features/resources/domain/resource_search.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/presentation/live_search_suggestions.dart';

/// A routine may supply the verified Quran picker without changing clinical
/// CMS selection behavior. A canonical reference has the form quran:N or quran:N:A.
typedef PickCanonicalQuranReference = Future<String?> Function(
  BuildContext context,
  bool wholeSurah,
);

Future<String?> showResourcePickerSheet({
  required BuildContext context,
  required List<ContentResourceOption> resources,
  required String selectedId,
  PickCanonicalQuranReference? onPickCanonicalQuran,
  bool includeOfficialTemplates = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ResourcePickerSheet(
      resources: resources,
      selectedId: selectedId,
      onPickCanonicalQuran: onPickCanonicalQuran,
      includeOfficialTemplates: includeOfficialTemplates,
    ),
  );
}

/// Grid picker where several library items can be ticked at once. Returns
/// the newly ticked ids in tap order, or null when closed without adding.
/// [alreadyLinked] items show as linked and cannot be ticked again.
Future<List<String>?> showResourceMultiPickerSheet({
  required BuildContext context,
  required List<ContentResourceOption> resources,
  Set<String> alreadyLinked = const {},
  int maxSelection = 16,
  PickCanonicalQuranReference? onPickCanonicalQuran,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ResourcePickerSheet(
      resources: resources,
      selectedId: '',
      multiSelect: true,
      alreadyLinked: alreadyLinked,
      maxSelection: maxSelection,
      onPickCanonicalQuran: onPickCanonicalQuran,
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
    this.onOfficialTemplateSelected,
  });

  final List<ContentResourceOption> resources;
  final String selectedId;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<OfficialPrescriptionTemplate>? onOfficialTemplateSelected;

  @override
  Widget build(BuildContext context) {
    final selected = resources
        .where((resource) => resource.id == selectedId)
        .firstOrNull;
    final title = selected?.displayTitle ?? 'লাইব্রেরি থেকে উপকরণ বাছুন';

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
                  includeOfficialTemplates: onOfficialTemplateSelected != null,
                );
                if (result != null) {
                  if (result.startsWith('official-template:')) {
                    final template = findOfficialTemplate(
                      result.substring('official-template:'.length),
                    );
                    if (template != null) {
                      onOfficialTemplateSelected?.call(template);
                    }
                  } else {
                    onChanged(result);
                  }
                }
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
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
    this.onPickCanonicalQuran,
    this.includeOfficialTemplates = false,
    this.multiSelect = false,
    this.alreadyLinked = const {},
    this.maxSelection = 16,
  });

  final List<ContentResourceOption> resources;
  final String selectedId;
  final PickCanonicalQuranReference? onPickCanonicalQuran;
  final bool includeOfficialTemplates;
  final bool multiSelect;
  final Set<String> alreadyLinked;
  final int maxSelection;

  @override
  State<_ResourcePickerSheet> createState() => _ResourcePickerSheetState();
}

/// Browses like the public library: a grid of sections first, then a grid
/// of items inside the opened section. Searching shows matching items from
/// every section (or the opened one) in the same grid.
class _ResourcePickerSheetState extends State<_ResourcePickerSheet> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  _PickerSection? _openSection;

  /// Navigation group inside the open section (e.g. "ঘুমের আগে ও পরে"),
  /// mirroring the public Resources tab.
  String? _openGroup;
  String? _openCategory;
  bool _showSuggestions = false;
  late final List<SearchDocument<ContentResourceOption>> _documents = [
    for (final resource in widget.resources) _pickerSearchDocument(resource),
  ];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _showSuggestions = _searchFocus.hasFocus);
    });
  }

  bool _choosingCanonical = false;

  /// Multi-select: ids ticked in this session, in tap order.
  final List<String> _picked = [];

  int get _room =>
      widget.maxSelection - widget.alreadyLinked.length - _picked.length;

  Future<void> _pickCanonical(bool wholeSurah) async {
    final picker = widget.onPickCanonicalQuran;
    if (picker == null || _choosingCanonical) return;
    setState(() => _choosingCanonical = true);
    try {
      final reference = await picker(context, wholeSurah);
      if (!mounted || reference == null) return;
      final parts = reference.split(':');
      final surah = parts.length >= 2 ? int.tryParse(parts[1]) : null;
      final ayah = parts.length == 3 ? int.tryParse(parts[2]) : null;
      if ((parts.length != 2 && parts.length != 3) ||
          parts.first != 'quran' ||
          surah == null ||
          surah < 1 ||
          surah > 114 ||
          (parts.length == 3 && (ayah == null || ayah < 1 || ayah > 286))) {
        throw const FormatException('Invalid Quran reference');
      }
      if (widget.multiSelect) {
        setState(() {
          if (_room > 0 && !_picked.contains(reference)) {
            _picked.add(reference);
          }
        });
        return;
      }
      Navigator.pop(context, reference);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'কুরআনের আয়াত নির্বাচন করা যায়নি। আবার চেষ্টা করুন।',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _choosingCanonical = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onResourceTap(ContentResourceOption resource) {
    if (!widget.multiSelect) {
      Navigator.pop(context, resource.id);
      return;
    }
    if (widget.alreadyLinked.contains(resource.id)) return;
    setState(() {
      if (!_picked.remove(resource.id) && _room > 0) {
        _picked.add(resource.id);
      }
    });
  }

  bool get _showsCanonicalQuran =>
      widget.onPickCanonicalQuran != null &&
      (_openSection == null ||
          _openSection!.slug == 'quran' ||
          _openSection!.slug == 'all');

  @override
  Widget build(BuildContext context) {
    final sections = _sections(widget.resources);
    final query = _searchController.text.trim();
    final open = _openSection;
    final browsing = open == null && query.isEmpty;

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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                            const SizedBox(height: 5),
                            const Text(
                              'উপকরণ বাছুন',
                              style: TextStyle(
                                color: SukunColors.nightNavy,
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'বন্ধ করুন',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: SukunColors.nightNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('resource-picker-search'),
                    controller: _searchController,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _hideSuggestions(),
                    decoration: InputDecoration(
                      hintText: open == null
                          ? 'নাম বা বিভাগ দিয়ে খুঁজুন'
                          : '${open.label}-এ খুঁজুন',
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
                  if (_showSuggestions && query.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: _suggestionPanel(open, query),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth - 32;
                  final columns = width >= 720
                      ? 4
                      : width >= 460
                      ? 3
                      : 2;
                  return CustomScrollView(
                    key: const Key('resource-picker-scroll'),
                    slivers: [
                      if (open != null)
                        SliverToBoxAdapter(
                          child: _OpenSectionBar(
                            section: open,
                            trail: [
                              if (_openGroup != null)
                                _groupTitle(open.slug, _openGroup!),
                              if (_openCategory != null)
                                _trailCategory(_openCategory!),
                            ],
                            onBack: () => setState(() {
                              if (_openCategory != null) {
                                _openCategory = null;
                              } else if (_openGroup != null) {
                                _openGroup = null;
                              } else {
                                _openSection = null;
                              }
                            }),
                          ),
                        ),
                      if (!widget.multiSelect &&
                          (browsing ||
                              (open != null && open.slug != 'official')))
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _ClearResourceTile(
                              selected: widget.selectedId.isEmpty,
                            ),
                          ),
                        ),
                      if (_showsCanonicalQuran && query.isEmpty)
                        ..._canonicalQuranSlivers(),
                      if (browsing)
                        ..._sectionGridSlivers(sections, columns)
                      else if (open?.slug == 'official')
                        ..._officialTemplateSlivers(query, columns)
                      else
                        ..._resourceGridSlivers(open, query, columns),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  );
                },
              ),
            ),
            if (widget.multiSelect) _multiSelectBar(context),
          ],
        ),
      ),
    );
  }

  Widget _multiSelectBar(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: SukunColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _picked.isEmpty
                    ? 'কিছু বাছাই হয়নি'
                    : '${_bn(_picked.length)}টি বাছাই'
                          '${_room <= 0 ? ' · আর যোগ করা যাবে না' : ''}',
                style: const TextStyle(
                  color: SukunColors.nightNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_picked.isNotEmpty)
              TextButton(
                onPressed: () => setState(_picked.clear),
                child: const Text('মুছুন'),
              ),
            const SizedBox(width: 6),
            FilledButton.icon(
              key: const Key('resource-picker-add'),
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, List<String>.of(_picked)),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _picked.isEmpty
                    ? 'যোগ করুন'
                    : '${_bn(_picked.length)}টি যোগ করুন',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _canonicalQuranSlivers() => [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      sliver: SliverList.list(
        children: [
          const _CategoryHeader(
            label: 'কুরআনের ১১৪ সূরা ও সব আয়াত',
            count: 114,
          ),
          const SizedBox(height: 8),
          _PickerCard(
            key: const Key('routine-quran-ayah-entry'),
            selected: false,
            enabled: !_choosingCanonical,
            onTap: () => _pickCanonical(false),
            icon: Icons.format_list_numbered_rounded,
            title: '১১৪ সূরা থেকে নির্দিষ্ট আয়াত বাছুন',
            subtitle: 'সূরা খুলে আরবি আয়াত ও উপলব্ধ বাংলা অর্থ দেখে রুটিনে যুক্ত করুন',
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 10),
          _PickerCard(
            key: const Key('routine-quran-surah-entry'),
            selected: false,
            enabled: !_choosingCanonical,
            onTap: () => _pickCanonical(true),
            icon: Icons.menu_book_rounded,
            title: '১১৪ সূরা থেকে সম্পূর্ণ সূরা বাছুন',
            subtitle: 'কুরআনের সম্পূর্ণ সূরাটি রুটিনের সঙ্গে যুক্ত করুন',
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _sectionGridSlivers(
    List<_PickerSection> sections,
    int columns,
  ) => [
    const SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      sliver: SliverToBoxAdapter(
        child: Text(
          'বিষয় অনুযায়ী দেখুন',
          style: TextStyle(
            color: SukunColors.nightNavy,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 140,
        ),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return _SectionTile(
            key: Key('resource-section-${section.slug}'),
            section: section,
            picked: widget.multiSelect
                ? _picked
                      .where(
                        (id) => widget.resources.any(
                          (r) => r.id == id && section.matches(r),
                        ),
                      )
                      .length
                : 0,
            onTap: () => setState(() {
              _openSection = section;
              _openGroup = null;
              _openCategory = null;
            }),
          );
        },
      ),
    ),
  ];

  List<Widget> _officialTemplateSlivers(String query, int columns) {
    final templates = officialPrescriptionTemplates
        .where(
          (entry) =>
              query.isEmpty ||
              searchMatches(
                SearchDocument<Object?>(
                  item: null,
                  title: entry.title,
                  details: [entry.instruction],
                ),
                query,
              ),
        )
        .toList(growable: false);
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        sliver: SliverToBoxAdapter(
          child: Card(
            color: SukunColors.mist,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'সুকুন লাইফ অফিসিয়াল টেমপ্লেট · শুধুমাত্র Admin Draft। '
                'নির্দেশনা, দিন, সংখ্যা ও সংশ্লিষ্ট প্রকাশিত উপকরণ '
                'মূল প্রেসক্রিপশন থেকে যাচাই করে রোগীর জন্য অনুমোদন দিন।',
              ),
            ),
          ),
        ),
      ),
      for (final group in officialTemplateCategories)
        if (templates.any((t) => t.category == group.id)) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _CategoryHeader(
                label: group.title,
                count: templates.where((t) => t.category == group.id).length,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 156,
              ),
              itemCount: templates.where((t) => t.category == group.id).length,
              itemBuilder: (context, index) {
                final template = templates
                    .where((t) => t.category == group.id)
                    .elementAt(index);
                return _ItemTile(
                  key: Key('official-template-${template.id}'),
                  icon: Icons.assignment_turned_in_outlined,
                  title: template.title,
                  subtitle: template.instruction,
                  enabled: true,
                  state: _TileState.idle,
                  onTap: () => Navigator.pop(
                    context,
                    'official-template:${template.id}',
                  ),
                );
              },
            ),
          ),
        ],
    ];
  }

  List<Widget> _resourceGridSlivers(
    _PickerSection? section,
    String query,
    int columns,
  ) {
    final visible = query.isEmpty
        ? [
            for (final resource in widget.resources)
              if (section == null || section.matches(resource)) resource,
          ]
        : [
            // Best matches first; the category headings follow that order.
            for (final resource in rankSearch(_documents, query))
              if (section == null || section.matches(resource)) resource,
          ];
    var grouped = section?.isOther == true
        ? <String, List<ContentResourceOption>>{section!.label: visible}
        : _groupByCategory(visible);
    if (section?.slug == 'quran' &&
        widget.onPickCanonicalQuran == null &&
        !widget.resources.any((item) => item.canonicalSurahNumber != null)) {
      return const [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: _EmptyQuranResources()),
        ),
      ];
    }
    if (visible.isEmpty) {
      return const [SliverToBoxAdapter(child: _EmptyResources())];
    }
    final navGroups = section?.section == null
        ? const <LibraryNavGroup>[]
        : libraryNavGroupsForSection(section!.slug);
    if (query.isEmpty && navGroups.isNotEmpty) {
      return _navGroupSlivers(section!, navGroups, visible, columns);
    }
    final categoryOpen = _openCategory;
    if (section != null &&
        section.slug != 'all' &&
        query.isEmpty &&
        grouped.length > 1) {
      if (categoryOpen == null || !grouped.containsKey(categoryOpen)) {
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList.separated(
              itemCount: grouped.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return _folderCard(
                  key: Key('resource-category-$index'),
                  title: entry.key,
                  items: entry.value,
                  onTap: () => setState(() => _openCategory = entry.key),
                );
              },
            ),
          ),
        ];
      }
      grouped = {categoryOpen: grouped[categoryOpen]!};
    }
    return _itemGridSlivers(grouped, columns);
  }

  /// Section → group → category → items, the same path as the public
  /// Resources tab (e.g. দোয়া ও যিকর → ঘুমের আগে ও পরে → ঘুমের আগে: তিনকুল).
  List<Widget> _navGroupSlivers(
    _PickerSection section,
    List<LibraryNavGroup> groups,
    List<ContentResourceOption> visible,
    int columns,
  ) {
    final byCategory = <String, List<ContentResourceOption>>{};
    for (final resource in visible) {
      byCategory
          .putIfAbsent(_navCategory(section.slug, resource), () => [])
          .add(resource);
    }
    final known = {for (final group in groups) ...group.categorySlugs};
    final leftovers = [
      for (final entry in byCategory.entries)
        if (!known.contains(entry.key)) ...entry.value,
    ];
    List<ContentResourceOption> inGroup(LibraryNavGroup group) => [
      for (final slug in group.categorySlugs) ...?byCategory[slug],
    ];

    final groupOpen = _openGroup;
    if (groupOpen == null) {
      final cards = <Widget>[
        for (final group in groups)
          if (inGroup(group).isNotEmpty)
            _folderCard(
              key: Key('resource-group-${group.slug}'),
              title: group.titleBn,
              items: inGroup(group),
              onTap: () => setState(() {
                _openGroup = group.slug;
                _openCategory = null;
              }),
            ),
        if (leftovers.isNotEmpty)
          _folderCard(
            key: const Key('resource-group-other'),
            title: 'অন্যান্য',
            items: leftovers,
            onTap: () => setState(() {
              _openGroup = _otherGroup;
              _openCategory = null;
            }),
          ),
      ];
      return [_cardListSliver(cards)];
    }
    if (groupOpen == _otherGroup) {
      return _itemGridSlivers(_groupByCategory(leftovers), columns);
    }
    final group = groups.where((entry) => entry.slug == groupOpen).firstOrNull;
    if (group == null) {
      return const [SliverToBoxAdapter(child: _EmptyResources())];
    }
    final categoryOpen = _openCategory;
    if (categoryOpen != null && byCategory[categoryOpen] != null) {
      return _itemGridSlivers({
        _categoryTitle(categoryOpen, byCategory[categoryOpen]!):
            byCategory[categoryOpen]!,
      }, columns);
    }
    final shelvesWithItems = [
      for (final shelf in group.shelves)
        if (shelf.categorySlugs.any((slug) => byCategory[slug] != null)) shelf,
    ];
    // A group of one category opens straight onto its items.
    final onlyCategory = [
      for (final shelf in shelvesWithItems)
        for (final slug in shelf.categorySlugs)
          if (byCategory[slug] != null) slug,
    ];
    if (onlyCategory.length == 1) {
      final slug = onlyCategory.single;
      return _itemGridSlivers({
        _categoryTitle(slug, byCategory[slug]!): byCategory[slug]!,
      }, columns);
    }
    final cards = <Widget>[];
    for (final shelf in shelvesWithItems) {
      if (shelf.titleBn != null && shelvesWithItems.length > 1) {
        cards.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _CategoryHeader(
              label: shelf.titleBn!,
              count: [
                for (final slug in shelf.categorySlugs) ...?byCategory[slug],
              ].length,
            ),
          ),
        );
      }
      for (final slug in shelf.categorySlugs) {
        final items = byCategory[slug];
        if (items == null) continue;
        cards.add(
          _folderCard(
            key: Key('resource-nav-category-$slug'),
            title: _categoryTitle(slug, items),
            items: items,
            onTap: () => setState(() => _openCategory = slug),
          ),
        );
      }
    }
    return [_cardListSliver(cards)];
  }

  static const _otherGroup = '_other';

  Widget _cardListSliver(List<Widget> cards) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    sliver: SliverList.separated(
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => cards[index],
    ),
  );

  Widget _folderCard({
    required Key key,
    required String title,
    required List<ContentResourceOption> items,
    required VoidCallback onTap,
  }) {
    final pickedHere = widget.multiSelect
        ? items.where((r) => _picked.contains(r.id)).length
        : 0;
    return _PickerCard(
      key: key,
      selected: pickedHere > 0,
      enabled: true,
      onTap: onTap,
      icon: Icons.folder_open_rounded,
      title: title,
      subtitle: pickedHere > 0
          ? '${_bn(items.length)}টি · ${_bn(pickedHere)}টি বাছাই'
          : '${_bn(items.length)}টি',
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  String _navCategory(String sectionSlug, ContentResourceOption resource) {
    if (sectionSlug == 'ruqyah') {
      return ruqyahNavCategoryFor(
        type: resource.type,
        categorySlug: resource.categorySlug,
        slug: resource.slug,
      );
    }
    return resource.categorySlug ?? '';
  }

  String _categoryTitle(String slug, List<ContentResourceOption> items) =>
      libraryNavCategoryTitle(slug) ?? items.first.categoryLabel;

  String _groupTitle(String sectionSlug, String groupSlug) {
    if (groupSlug == _otherGroup) return 'অন্যান্য';
    for (final group in libraryNavGroupsForSection(sectionSlug)) {
      if (group.slug == groupSlug) return group.titleBn;
    }
    return groupSlug;
  }

  String _trailCategory(String category) =>
      libraryNavCategoryTitle(category) ?? category;

  void _hideSuggestions() {
    _searchFocus.unfocus();
    setState(() => _showSuggestions = false);
  }

  Widget _suggestionPanel(_PickerSection? section, String query) {
    final matches = [
      for (final resource in rankSearch(_documents, query))
        if (section == null || section.matches(resource)) resource,
    ];
    return LiveSearchSuggestionList<ContentResourceOption>(
      query: query,
      totalMatches: matches.length,
      suggestions: buildSearchSuggestions<ContentResourceOption>(
        query: query,
        rankedMatches: matches,
        titleOf: (item) => item.displayTitle,
        kindOf: (item) => searchKindLabel(item.type),
        categoryOf: (item) => item.categoryLabel,
      ),
      iconFor: (suggestion) => suggestion.item == null
          ? Icons.folder_open_rounded
          : _iconForType(suggestion.item!.type),
      onShowAll: _hideSuggestions,
      onSelect: (suggestion) {
        final item = suggestion.item;
        if (item == null) {
          _searchController.text = suggestion.label;
          _hideSuggestions();
          return;
        }
        if (!item.isLinkable) {
          _searchController.text = suggestion.label;
          _hideSuggestions();
          return;
        }
        if (!widget.multiSelect) {
          Navigator.pop(context, item.id);
          return;
        }
        _onResourceTap(item);
      },
    );
  }

  List<Widget> _itemGridSlivers(
    Map<String, List<ContentResourceOption>> grouped,
    int columns,
  ) {
    return [
      for (final entry in grouped.entries) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _CategoryHeader(label: entry.key, count: entry.value.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 148,
            ),
            itemCount: entry.value.length,
            itemBuilder: (context, index) {
              final resource = entry.value[index];
              final linked = widget.alreadyLinked.contains(resource.id);
              final picked = _picked.contains(resource.id);
              final state = linked
                  ? _TileState.linked
                  : picked || resource.id == widget.selectedId
                  ? _TileState.selected
                  : _TileState.idle;
              final full = widget.multiSelect && _room <= 0 && !picked;
              return _ItemTile(
                key: Key('resource-item-${resource.id}'),
                icon: _iconForType(resource.type),
                title: resource.displayTitle,
                subtitle: !resource.isLinkable
                    ? _unavailableReason(resource)
                    : resource.isEditorialRuqyahExcerpt
                    ? 'সম্পাদিত পাঠ · পূর্ণ যাচাইকৃত আয়াত নয়'
                    : _displayType(resource.type),
                meta: [
                  if (resource.status != 'published')
                    _displayStatus(resource.status),
                  if (resource.visibility != 'public')
                    _displayVisibility(resource.visibility),
                ],
                enabled: resource.isLinkable && !linked && !full,
                locked: !resource.isLinkable,
                checkbox: widget.multiSelect,
                state: state,
                onTap: resource.isLinkable
                    ? () => _onResourceTap(resource)
                    : null,
              );
            },
          ),
        ),
      ],
    ];
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
      if (widget.includeOfficialTemplates)
        _PickerSection(
          slug: 'official',
          label: 'Sukun Life Official Templates',
          icon: Icons.verified_outlined,
          count: officialPrescriptionTemplates.length,
        ),
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

SearchDocument<ContentResourceOption> _pickerSearchDocument(
  ContentResourceOption resource,
) => SearchDocument<ContentResourceOption>(
  item: resource,
  title: resource.displayTitle,
  altTitle: resource.displayTitle == resource.title ? null : resource.title,
  details: [
    resource.categoryLabel,
    resource.categoryName,
    libraryNavCategoryTitle(resource.categorySlug ?? ''),
    searchTypeLabel(resource.type),
    for (final group in libraryNavGroupsForSection('dua-azkar'))
      if (group.categorySlugs.contains(resource.categorySlug)) group.titleBn,
  ],
);

String _bn(int value) {
  const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return '$value'.split('').map((d) => digits[int.parse(d)]).join();
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

/// A library-style section card: icon, name and how many items it holds.
class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.section,
    required this.picked,
    required this.onTap,
  });

  final _PickerSection section;
  final int picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = picked > 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? SukunColors.sukunBlue : SukunColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: SukunColors.mist,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(section.icon, color: SukunColors.deepTide),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        section.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: SukunColors.nightNavy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_bn(section.count)}টি',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: SukunColors.muted),
                    ),
                  ],
                ),
              ),
              if (active)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SukunColors.sukunBlue,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _bn(picked),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenSectionBar extends StatelessWidget {
  const _OpenSectionBar({
    required this.section,
    required this.onBack,
    this.trail = const [],
  });

  final _PickerSection section;
  final VoidCallback onBack;

  /// Group and category opened inside the section, shown as a path.
  final List<String> trail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
    child: Row(
      children: [
        IconButton(
          key: const Key('resource-section-back'),
          tooltip: 'সব বিভাগ',
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SukunColors.nightNavy,
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: SukunColors.mist,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(section.icon, color: SukunColors.deepTide, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            [section.label, ...trail].join(' › '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: SukunColors.nightNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${_bn(section.count)}টি',
          style: const TextStyle(color: SukunColors.muted),
        ),
      ],
    ),
  );
}

enum _TileState { idle, selected, linked }

/// One library item in the grid. In multi-select mode it carries a round
/// check in the corner, the same tap that reading the library uses.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.state,
    required this.onTap,
    this.meta = const [],
    this.locked = false,
    this.checkbox = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> meta;
  final bool enabled;
  final bool locked;
  final bool checkbox;
  final _TileState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = state != _TileState.idle;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: highlighted,
      enabled: enabled,
      child: Material(
        color: highlighted ? SukunColors.mist : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted ? SukunColors.sukunBlue : SukunColors.border,
                width: highlighted ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: highlighted ? Colors.white : SukunColors.mist,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: SukunColors.deepTide, size: 20),
                    ),
                    const Spacer(),
                    if (locked)
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: SukunColors.muted,
                        size: 20,
                      )
                    else if (state == _TileState.linked)
                      const _LinkedMark()
                    else if (checkbox || state == _TileState.selected)
                      _CheckMark(checked: state == _TileState.selected),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: SukunColors.nightNavy,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state == _TileState.linked
                      ? 'আগেই যুক্ত আছে'
                      : [
                          subtitle,
                          ...meta,
                        ].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SukunColors.muted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: checked ? SukunColors.sukunBlue : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(
        color: checked ? SukunColors.sukunBlue : SukunColors.border,
        width: 1.5,
      ),
    ),
    child: checked
        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
        : null,
  );
}

class _LinkedMark extends StatelessWidget {
  const _LinkedMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: SukunColors.softBlue,
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.link_rounded, size: 15, color: SukunColors.deepTide),
  );
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

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Disabled entries stay readable; the lock icon and disabled tap
    // communicate restricted/unverified resources without fading text.
    return Opacity(
      opacity: 1,
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
                          color: SukunColors.nightNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: SukunColors.muted),
                        ),
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

class _SelectedMark extends StatelessWidget {
  const _SelectedMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
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
  return 'কুরআনের মূল পাঠ যাচাই ছাড়া যুক্ত করা যাবে না।';
}
