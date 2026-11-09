import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';

/// Opens the bulk picker and returns the selected rows, or null if cancelled.
///
/// [showTemplates] is for Super Admin only: the official Sukun templates are
/// reviewer material. Members see the public resources tab only.
Future<List<BulkImportItem>?> showBulkTemplateImport(
  BuildContext context, {
  required String recipientLabel,
  required Future<List<ContentResourceOption>> resources,
  bool showTemplates = true,
  bool showDuration = true,
  String confirmLabel = 'ইম্পোর্ট ও রিমাইন্ডার চালু',
}) {
  return Navigator.of(context).push<List<BulkImportItem>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BulkTemplateImportScreen(
        recipientLabel: recipientLabel,
        resources: resources,
        showTemplates: showTemplates,
        showDuration: showDuration,
        confirmLabel: confirmLabel,
      ),
    ),
  );
}

enum _BulkTab { templates, resources }

class BulkTemplateImportScreen extends StatefulWidget {
  const BulkTemplateImportScreen({
    super.key,
    required this.recipientLabel,
    required this.resources,
    this.showTemplates = true,
    this.showDuration = true,
    this.confirmLabel = 'ইম্পোর্ট ও রিমাইন্ডার চালু',
  });

  final String recipientLabel;
  final Future<List<ContentResourceOption>> resources;
  final bool showTemplates;

  /// Care plans can end a reminder after N days; routines run until paused.
  final bool showDuration;
  final String confirmLabel;

  @override
  State<BulkTemplateImportScreen> createState() =>
      _BulkTemplateImportScreenState();
}

class _BulkTemplateImportScreenState extends State<BulkTemplateImportScreen> {
  final _search = TextEditingController();
  final Map<String, BulkImportItem> _selected = {};
  late _BulkTab _tab = widget.showTemplates
      ? _BulkTab.templates
      : _BulkTab.resources;
  String? _category;
  List<ContentResourceOption> _resources = const [];

  @override
  void initState() {
    super.initState();
    widget.resources.then((value) {
      if (!mounted) return;
      setState(() {
        _resources = value
            .where((resource) => resource.isLinkable)
            .toList(growable: false);
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().toLowerCase();

  bool _matches(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query);

  BulkImportItem _newTemplateItem(OfficialPrescriptionTemplate template) {
    final item = BulkImportItem.template(template);
    if (template.requiresLinkedResource) {
      final suggestion = suggestResourceForTemplate(template, _resources);
      if (suggestion != null) item.resourceIds.add(suggestion.id);
    }
    return item;
  }

  void _toggleTemplate(OfficialPrescriptionTemplate template) {
    setState(() {
      final key = 't:${template.id}';
      if (_selected.remove(key) == null) {
        _selected[key] = _newTemplateItem(template);
      }
    });
  }

  void _toggleResource(ContentResourceOption resource) {
    setState(() {
      final key = 'r:${resource.id}';
      if (_selected.remove(key) == null) {
        _selected[key] = BulkImportItem.resource(resource);
      }
    });
  }

  void _setGroup(Iterable<OfficialPrescriptionTemplate> group, bool select) {
    setState(() {
      for (final template in group) {
        final key = 't:${template.id}';
        if (select) {
          _selected.putIfAbsent(key, () => _newTemplateItem(template));
        } else {
          _selected.remove(key);
        }
      }
    });
  }

  void _setResourceGroup(Iterable<ContentResourceOption> group, bool select) {
    setState(() {
      for (final resource in group) {
        final key = 'r:${resource.id}';
        if (select) {
          _selected.putIfAbsent(key, () => BulkImportItem.resource(resource));
        } else {
          _selected.remove(key);
        }
      }
    });
  }

  Future<void> _editTime(BulkImportItem item, int index) async {
    final current = index < item.times.length
        ? item.times[index]
        : const ReminderClock(8, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'রিমাইন্ডারের সময়',
    );
    if (picked == null || !mounted) return;
    final clock = ReminderClock(picked.hour, picked.minute);
    setState(() {
      if (index < item.times.length) {
        item.times[index] = clock;
      } else if (!item.times.contains(clock)) {
        item.times.add(clock);
      }
      final unique = item.times.toSet().toList()..sort();
      item.times
        ..clear()
        ..addAll(unique);
    });
  }

  Future<void> _pickResource(BulkImportItem item) async {
    final id = await showResourcePickerSheet(
      context: context,
      resources: _resources,
      selectedId: item.resourceIds.firstOrNull ?? '',
    );
    if (id == null || id.isEmpty || id.startsWith('official-template:')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      item.resourceIds
        ..clear()
        ..add(id);
    });
  }

  ContentResourceOption? _resourceById(String id) {
    for (final resource in _resources) {
      if (resource.id == id) return resource;
    }
    return null;
  }

  void _confirm() {
    final items = _selected.values.toList(growable: false);
    final blocked = items.where((item) => !item.isReady).toList();
    if (items.isEmpty) return;
    if (blocked.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '“${blocked.first.title}”: ${blocked.first.problem}'
            '${blocked.length > 1 ? ' (আরও ${toBanglaDigits('${blocked.length - 1}')}টি বাকি)' : ''}',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(items);
  }

  @override
  Widget build(BuildContext context) {
    final items = _selected.values.toList(growable: false);
    final reminderCount = items.fold<int>(0, (sum, i) => sum + i.times.length);
    final blocked = items.where((item) => !item.isReady).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('আমল ও রিমাইন্ডার বাছুন'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('সব মুছুন'),
            ),
        ],
      ),
      bottomNavigationBar: SukunBottomActionBar(
        hint: Text(
          items.isEmpty
              ? 'যা যা দরকার টিক দিন। সময় আগে থেকেই বসানো আছে, চাইলে বদলান।'
              : blocked > 0
              ? '${toBanglaDigits('${items.length}')}টি বাছাই · '
                    '${toBanglaDigits('$blocked')}টিতে তথ্য বাকি'
              : '${toBanglaDigits('${items.length}')}টি বাছাই · '
                    '${toBanglaDigits('$reminderCount')}টি দৈনিক রিমাইন্ডার',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: blocked > 0 ? SukunColors.error : SukunColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          FilledButton.icon(
            key: const Key('bulk-import-confirm'),
            onPressed: items.isEmpty ? null : _confirm,
            icon: const Icon(Icons.notifications_active_outlined),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                items.isEmpty
                    ? widget.confirmLabel
                    : '${widget.confirmLabel} (${toBanglaDigits('${items.length}')})',
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SukunSpace.page,
                  SukunSpace.md,
                  SukunSpace.page,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    SukunSurface(
                      tone: SukunSurfaceTone.soft,
                      showBorder: false,
                      padding: const EdgeInsets.all(SukunSpace.lg),
                      child: Row(
                        children: [
                          const SukunIconBadge(
                            icon: Icons.playlist_add_check_rounded,
                            size: 44,
                          ),
                          const SizedBox(width: SukunSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.recipientLabel,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'একসাথে বাছাই করুন, এক ক্লিকে সব যুক্ত হবে '
                                  'এবং প্রতিদিনের রিমাইন্ডার চালু হবে।',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SukunSpace.md),
                    if (widget.showTemplates)
                      SegmentedButton<_BulkTab>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: _BulkTab.templates,
                            icon: const Icon(
                              Icons.auto_awesome_motion_outlined,
                            ),
                            label: Text(
                              'সুকুন টেমপ্লেট '
                              '(${toBanglaDigits('${officialPrescriptionTemplates.length}')})',
                            ),
                          ),
                          ButtonSegment(
                            value: _BulkTab.resources,
                            icon: const Icon(Icons.library_books_outlined),
                            label: const Text('সব উপকরণ'),
                          ),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (value) => setState(() {
                          _tab = value.single;
                          _category = null;
                        }),
                      ),
                    const SizedBox(height: SukunSpace.md),
                    SukunSearchField(
                      controller: _search,
                      hintText: _tab == _BulkTab.templates
                          ? 'আমল, সাপ্লিমেন্ট, গোসল খুঁজুন'
                          : 'দোয়া, অডিও, সূরা খুঁজুন',
                      onChanged: (_) => setState(() {}),
                      onClear: () => setState(_search.clear),
                    ),
                    const SizedBox(height: SukunSpace.md),
                  ],
                ),
              ),
              if (_tab == _BulkTab.templates)
                ..._templateSlivers(context)
              else
                ..._resourceSlivers(context),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(List<(String?, String)> options) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SukunSpace.page),
      children: [
        for (final (id, label) in options) ...[
          SukunFilterPill(
            label: label,
            selected: _category == id,
            onTap: () => setState(() => _category = id),
          ),
          const SizedBox(width: SukunSpace.sm),
        ],
      ],
    ),
  );

  List<Widget> _templateSlivers(BuildContext context) {
    final groups = [
      for (final category in officialTemplateCategories)
        if (_category == null || _category == category.id)
          (
            category,
            officialPrescriptionTemplates
                .where(
                  (t) =>
                      t.category == category.id &&
                      _matches('${t.title} ${t.instruction}'),
                )
                .toList(growable: false),
          ),
    ].where((group) => group.$2.isNotEmpty).toList();
    return [
      SliverToBoxAdapter(
        child: _filters([
          (null, 'সব'),
          for (final category in officialTemplateCategories)
            (category.id, category.title),
        ]),
      ),
      if (groups.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(SukunSpace.page),
            child: Text('কিছু পাওয়া যায়নি। অন্য শব্দ লিখে দেখুন।'),
          ),
        ),
      for (final (category, templates) in groups) ...[
        SliverToBoxAdapter(
          child: _GroupHeader(
            title: category.title,
            subtitle: category.subtitle,
            total: templates.length,
            selected: templates
                .where((t) => _selected.containsKey('t:${t.id}'))
                .length,
            onSelectAll: (select) => _setGroup(templates, select),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: SukunSpace.page),
          sliver: SliverList.separated(
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: SukunSpace.sm),
            itemBuilder: (context, index) {
              final template = templates[index];
              final item = _selected['t:${template.id}'];
              return _BulkRow(
                key: Key('bulk-template-${template.id}'),
                title: template.title,
                subtitle: template.instruction,
                item: item,
                onToggle: () => _toggleTemplate(template),
                onEditTime: (i) => _editTime(item!, i),
                onRemoveTime: (i) => setState(() => item!.times.removeAt(i)),
                onVariable: (name, value) =>
                    setState(() => item!.variables[name] = value),
                onDuration: widget.showDuration
                    ? (days) => setState(() => item!.durationDays = days)
                    : null,
                onPickResource: () => _pickResource(item!),
                linkedResource: item?.resourceIds.firstOrNull == null
                    ? null
                    : _resourceById(item!.resourceIds.first),
                needsResource: template.requiresLinkedResource,
              );
            },
          ),
        ),
      ],
    ];
  }

  List<Widget> _resourceSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<ContentResourceOption>>(
          future: widget.resources,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(SukunSpace.page),
                child: Text('উপকরণ আনা যায়নি। সংযোগ দেখে আবার চেষ্টা করুন।'),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(SukunSpace.page),
                child: AppLoadingState(label: 'উপকরণ আনা হচ্ছে'),
              );
            }
            final labels = <String>[];
            for (final resource in _resources) {
              if (!labels.contains(resource.categoryLabel)) {
                labels.add(resource.categoryLabel);
              }
            }
            return _filters([
              (null, 'সব'),
              for (final label in labels) (label, label),
            ]);
          },
        ),
      ),
      ..._resourceGroups(context),
    ];
  }

  List<Widget> _resourceGroups(BuildContext context) {
    final groups = <String, List<ContentResourceOption>>{};
    for (final resource in _resources) {
      final label = resource.categoryLabel;
      if (_category != null && _category != label) continue;
      if (!_matches('${resource.title} ${resource.titleBn ?? ''} $label')) {
        continue;
      }
      groups.putIfAbsent(label, () => []).add(resource);
    }
    return [
      for (final entry in groups.entries) ...[
        SliverToBoxAdapter(
          child: _GroupHeader(
            title: entry.key,
            total: entry.value.length,
            selected: entry.value
                .where((r) => _selected.containsKey('r:${r.id}'))
                .length,
            onSelectAll: (select) => _setResourceGroup(entry.value, select),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: SukunSpace.page),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => const SizedBox(height: SukunSpace.sm),
            itemBuilder: (context, index) {
              final resource = entry.value[index];
              final item = _selected['r:${resource.id}'];
              return _BulkRow(
                key: Key('bulk-resource-${resource.id}'),
                title: resource.displayTitle,
                subtitle: _typeLabel(resource.type),
                item: item,
                onToggle: () => _toggleResource(resource),
                onEditTime: (i) => _editTime(item!, i),
                onRemoveTime: (i) => setState(() => item!.times.removeAt(i)),
                onVariable: (_, _) {},
                onDuration: widget.showDuration
                    ? (days) => setState(() => item!.durationDays = days)
                    : null,
                onPickResource: null,
                linkedResource: null,
                needsResource: false,
              );
            },
          ),
        ),
      ],
    ];
  }
}

String _typeLabel(String type) => switch (type) {
  'audio' => 'অডিও',
  'video' => 'ভিডিও',
  'quran' => 'কুরআন',
  'hadith' => 'হাদিস',
  'dua' => 'দোয়া',
  'pdf' => 'পিডিএফ',
  'article' => 'লেখা',
  _ => 'উপকরণ',
};

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.total,
    required this.selected,
    required this.onSelectAll,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int total;
  final int selected;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final all = selected == total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SukunSpace.page,
        SukunSpace.section,
        SukunSpace.page - 8,
        SukunSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title · ${toBanglaDigits('$selected')}/${toBanglaDigits('$total')}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SukunColors.muted),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => onSelectAll(!all),
            icon: Icon(
              all ? Icons.remove_done_rounded : Icons.done_all_rounded,
            ),
            label: Text(all ? 'বাদ দিন' : 'সব বাছুন'),
          ),
        ],
      ),
    );
  }
}

class _BulkRow extends StatelessWidget {
  const _BulkRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.item,
    required this.onToggle,
    required this.onEditTime,
    required this.onRemoveTime,
    required this.onVariable,
    required this.onDuration,
    required this.onPickResource,
    required this.linkedResource,
    required this.needsResource,
  });

  final String title;
  final String subtitle;
  final BulkImportItem? item;
  final VoidCallback onToggle;
  final ValueChanged<int> onEditTime;
  final ValueChanged<int> onRemoveTime;
  final void Function(String variable, int value) onVariable;
  final ValueChanged<int?>? onDuration;
  final VoidCallback? onPickResource;
  final ContentResourceOption? linkedResource;
  final bool needsResource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = item != null;
    final problem = item?.problem;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SukunRadius.tile),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.55)
              : SukunColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(SukunRadius.tile),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(value: selected, onChanged: (_) => onToggle()),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: selected ? 4 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: SukunColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!selected && needsResource)
                    const Padding(
                      padding: EdgeInsets.only(top: 10, left: 6),
                      child: Icon(
                        Icons.headphones_rounded,
                        size: 18,
                        color: SukunColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (item != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < item!.times.length; i++)
                        InputChip(
                          avatar: const Icon(Icons.alarm_rounded, size: 16),
                          label: Text(item!.times[i].label),
                          onPressed: () => onEditTime(i),
                          onDeleted: () => onRemoveTime(i),
                          deleteButtonTooltipMessage: 'সময় বাদ দিন',
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add_alarm_rounded, size: 16),
                        label: const Text('সময় যোগ'),
                        onPressed: () => onEditTime(item!.times.length),
                      ),
                    ],
                  ),
                  for (final variable
                      in item!.template?.requiredVariables ?? const <String>[])
                    _QuickNumbers(
                      label: '$variable কত?',
                      values: bulkVariableQuickValues[variable] ?? const [],
                      selected: item!.variables[variable],
                      onSelected: (value) {
                        if (value != null) onVariable(variable, value);
                      },
                    ),
                  if (onDuration != null)
                    _QuickNumbers(
                      label: 'কত দিন চলবে?',
                      values: bulkDurationQuickValues,
                      selected: item!.durationDays,
                      onSelected: onDuration!,
                      noneLabel: 'চলমান',
                    ),
                  if (onPickResource != null && needsResource)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: onPickResource,
                        icon: Icon(
                          linkedResource == null
                              ? Icons.link_rounded
                              : Icons.headphones_rounded,
                        ),
                        label: Text(
                          linkedResource?.displayTitle ??
                              'অডিও বা সূরা যুক্ত করুন',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (problem != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SukunStatusPill(
                        label: problem,
                        tone: SukunStatusTone.warning,
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickNumbers extends StatelessWidget {
  const _QuickNumbers({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.noneLabel,
  });

  final String label;
  final List<int> values;
  final int? selected;
  final ValueChanged<int?> onSelected;
  final String? noneLabel;

  Future<void> _custom(BuildContext context) async {
    final controller = TextEditingController(
      text: selected == null ? '' : '$selected',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '১ থেকে ৩৬৫'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 1 && parsed <= 365) {
                Navigator.pop(dialog, parsed);
              }
            },
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final custom = selected != null && !values.contains(selected);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: SukunColors.muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (noneLabel != null)
                ChoiceChip(
                  label: Text(noneLabel!),
                  selected: selected == null,
                  onSelected: (_) => onSelected(null),
                ),
              for (final value in values)
                ChoiceChip(
                  label: Text(toBanglaDigits('$value')),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ),
              ChoiceChip(
                label: Text(custom ? toBanglaDigits('$selected') : 'অন্য'),
                selected: custom,
                onSelected: (_) => _custom(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
