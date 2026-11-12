import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_template_repository.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/presentation/care_template_editor_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/ghusl_calendar_screen.dart';
import 'package:sukun_life/features/home/presentation/staff_access.dart';
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
  Future<CareTemplateCatalog>? templates,
  Future<OfficialPrescriptionTemplate> Function(OfficialPrescriptionTemplate)?
  saveTemplate,
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
        templates: templates,
        // Only the main admin edits official templates; a raqi imports them.
        saveTemplate: isRaqiSession(context) ? null : saveTemplate,
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
    this.templates,
    this.saveTemplate,
  });

  final String recipientLabel;

  /// The live template list from the database. Null or unreachable uses the
  /// built-in copy, which cannot be edited.
  final Future<CareTemplateCatalog>? templates;

  /// Saves an edited or new template (Super Admin). Null hides editing.
  final Future<OfficialPrescriptionTemplate> Function(
    OfficialPrescriptionTemplate,
  )?
  saveTemplate;
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

  /// Rows written by hand from a section's "নতুন যোগ করুন", for this
  /// person only. They stay listed in their section even when unticked.
  final List<OfficialPrescriptionTemplate> _customs = [];
  CareTemplateCatalog _catalog = CareTemplateCatalog.builtIn;

  /// Templates shown in the picker (inactive ones are hidden).
  List<OfficialPrescriptionTemplate> get _templates => [
    for (final template in _catalog.templates)
      if (template.isActive) template,
  ];

  bool get _canEditTemplates =>
      _catalog.editable && widget.saveTemplate != null;

  /// Second step: every selected row in one list to check and edit
  /// (times, reminder name, content, on/off) before importing.
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    widget.templates?.then((catalog) {
      if (!mounted) return;
      setState(() => _catalog = catalog);
    }, onError: (_) {});
    widget.resources.then((value) {
      if (!mounted) return;
      setState(() {
        _resources = value
            .where((resource) => resource.isLinkable)
            .toList(growable: false);
        // Rows ticked before the library loaded get their content now.
        for (final item in _selected.values) {
          item.fillSuggestedResources(_resources);
        }
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => foldBanglaForSearch(_search.text.trim().toLowerCase());

  bool _matches(String text) =>
      _query.isEmpty ||
      foldBanglaForSearch(text.toLowerCase()).contains(_query);

  BulkImportItem _newTemplateItem(OfficialPrescriptionTemplate template) {
    final item = BulkImportItem.template(template);
    // Pre-link every library item that belongs to this template (audio,
    // surah, guide section). The admin can remove any or add more.
    item.resourceIds.addAll(
      suggestResourcesForTemplate(template, _resources).map((r) => r.id),
    );
    return item;
  }

  /// Opens the ghusl calendar and applies the chosen dates: a bath with
  /// dates is selected for import, a bath without dates is deselected.
  Future<void> _openGhuslCalendar([GhuslKind? focus]) async {
    final initial = <GhuslKind, Set<DateTime>>{
      for (final kind in GhuslKind.values)
        kind: {...?_selected['t:${kind.templateId}']?.calendarDates},
    };
    final result = await showGhuslCalendar(
      context,
      initial: initial,
      focus: focus,
    );
    if (result == null || !mounted) return;
    setState(() {
      for (final kind in GhuslKind.values) {
        final dates = result[kind] ?? const <DateTime>{};
        final key = 't:${kind.templateId}';
        if (dates.isEmpty) {
          _selected.remove(key);
          continue;
        }
        final template = _templates
            .where((t) => t.id == kind.templateId)
            .firstOrNull;
        if (template == null) continue;
        final item = _selected.putIfAbsent(
          key,
          () => _newTemplateItem(template),
        );
        item.calendarDates
          ..clear()
          ..addAll(dates);
      }
    });
  }

  void _toggleTemplate(OfficialPrescriptionTemplate template) {
    final kind = GhuslKind.forTemplate(template.id);
    if (kind != null && !_selected.containsKey('t:${template.id}')) {
      _openGhuslCalendar(kind);
      return;
    }
    setState(() {
      final key = 't:${template.id}';
      if (_selected.remove(key) == null) {
        _selected[key] = _newTemplateItem(template);
      }
    });
  }

  /// Opens the template editor; a saved change shows at once and is used by
  /// this and every later import.
  Future<void> _editTemplate(OfficialPrescriptionTemplate? template) async {
    final save = widget.saveTemplate;
    if (save == null) return;
    final saved = await showCareTemplateEditor(
      context,
      template: template,
      initialCategory: _category,
      resources: _resources,
      save: save,
    );
    if (saved == null || !mounted) return;
    setState(() {
      final list = [..._catalog.templates];
      final index = list.indexWhere((t) => t.id == saved.id);
      if (index >= 0) {
        list[index] = saved;
      } else {
        list.add(saved);
      }
      _catalog = CareTemplateCatalog(
        templates: List.unmodifiable(list),
        editable: true,
      );
      // A ticked row restarts from the edited template.
      final key = 't:${saved.id}';
      if (_selected.containsKey(key)) {
        if (saved.isActive) {
          _selected[key] = _newTemplateItem(saved);
        } else {
          _selected.remove(key);
        }
      }
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('“${saved.title}” সেভ হয়েছে।')));
  }

  /// Adds (or edits) a one-off row in [category] for this person only.
  Future<void> _addCustom(
    String category, {
    OfficialPrescriptionTemplate? existing,
  }) async {
    final categoryTitle = officialTemplateCategories
        .firstWhere(
          (c) => c.id == category,
          orElse: () => officialTemplateCategories.first,
        )
        .title;
    final result = await showModalBottomSheet<_CustomDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _CustomItemSheet(
        categoryTitle: categoryTitle,
        initialTitle: existing?.title,
        initialInstruction: existing?.title == existing?.instruction
            ? null
            : existing?.instruction,
      ),
    );
    if (result == null || !mounted) return;
    final draft = customBulkTemplate(
      id:
          existing?.id ??
          '$bulkCustomItemIdPrefix${DateTime.now().microsecondsSinceEpoch}',
      category: category,
      title: result.title,
      instruction: result.instruction,
    );
    setState(() {
      final key = 'c:${draft.id}';
      final index = _customs.indexWhere((c) => c.id == draft.id);
      if (index >= 0) {
        _customs[index] = draft;
      } else {
        _customs.add(draft);
      }
      final previous = _selected[key];
      final item = BulkImportItem.custom(draft, times: previous?.times);
      if (previous != null) {
        item.resourceIds.addAll(previous.resourceIds);
        item.durationDays = previous.durationDays;
        item.notificationTitle = previous.notificationTitle;
        item.reminderEnabled = previous.reminderEnabled;
      }
      _selected[key] = item;
    });
  }

  void _toggleCustom(OfficialPrescriptionTemplate draft) {
    setState(() {
      final key = 'c:${draft.id}';
      if (_selected.remove(key) == null) {
        _selected[key] = BulkImportItem.custom(draft);
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

  void _setGroup(
    Iterable<OfficialPrescriptionTemplate> group,
    bool select, [
    Iterable<OfficialPrescriptionTemplate> customs = const [],
  ]) {
    setState(() {
      for (final template in group) {
        final key = 't:${template.id}';
        if (select) {
          _selected.putIfAbsent(key, () => _newTemplateItem(template));
        } else {
          _selected.remove(key);
        }
      }
      for (final draft in customs) {
        final key = 'c:${draft.id}';
        if (select) {
          _selected.putIfAbsent(key, () => BulkImportItem.custom(draft));
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

  /// Adds linked resources from the grid picker (several at once); earlier
  /// links stay.
  Future<void> _pickResource(BulkImportItem item) async {
    if (item.resourceIds.length >= bulkMaxResourcesPerItem) return;
    final ids = await showResourceMultiPickerSheet(
      context: context,
      resources: _resources,
      alreadyLinked: item.resourceIds.toSet(),
      maxSelection: bulkMaxResourcesPerItem,
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    setState(() {
      for (final id in ids) {
        if (id.isEmpty || id.startsWith('official-template:')) continue;
        if (item.resourceIds.length >= bulkMaxResourcesPerItem) break;
        if (!item.resourceIds.contains(id)) item.resourceIds.add(id);
      }
    });
  }

  List<_LinkedResource> _linkedResources(BulkImportItem? item) => [
    for (final id in item?.resourceIds ?? const <String>[])
      _LinkedResource(id, _resourceById(id)),
  ];

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
    if (!_reviewing) {
      setState(() => _reviewing = true);
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
        leading: _reviewing
            ? IconButton(
                key: const Key('bulk-review-back'),
                tooltip: 'বাছাইয়ে ফিরে যান',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _reviewing = false),
              )
            : null,
        title: Text(
          _reviewing ? 'সব একসাথে দেখে নিন' : 'আমল ও রিমাইন্ডার বাছুন',
        ),
        actions: [
          if (_selected.isNotEmpty && !_reviewing)
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
              : !_reviewing && blocked == 0
              ? '${toBanglaDigits('${items.length}')}টি বাছাই · পরের ধাপে সব একসাথে দেখে নিন'
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
            key: Key(_reviewing ? 'bulk-import-final' : 'bulk-import-confirm'),
            onPressed: items.isEmpty ? null : _confirm,
            icon: Icon(
              _reviewing
                  ? Icons.notifications_active_outlined
                  : Icons.fact_check_outlined,
            ),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                items.isEmpty
                    ? widget.confirmLabel
                    : _reviewing
                    ? '${widget.confirmLabel} (${toBanglaDigits('${items.length}')})'
                    : 'দেখে নিন ও এডিট (${toBanglaDigits('${items.length}')})',
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: _reviewing
              ? _reviewList(context, items)
              : CustomScrollView(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.recipientLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                    '(${toBanglaDigits('${_templates.length}')})',
                                  ),
                                ),
                                ButtonSegment(
                                  value: _BulkTab.resources,
                                  icon: const Icon(
                                    Icons.library_books_outlined,
                                  ),
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

  /// Step two: only the chosen rows, each fully open for editing.
  Widget _reviewList(BuildContext context, List<BulkImportItem> items) {
    final reminders = items
        .where((item) => item.reminderEnabled)
        .fold<int>(0, (sum, item) => sum + item.times.length);
    return ListView(
      key: const Key('bulk-review-list'),
      padding: const EdgeInsets.fromLTRB(
        SukunSpace.page,
        SukunSpace.md,
        SukunSpace.page,
        32,
      ),
      children: [
        SukunSurface(
          tone: SukunSurfaceTone.soft,
          showBorder: false,
          padding: const EdgeInsets.all(SukunSpace.lg),
          child: Row(
            children: [
              const SukunIconBadge(icon: Icons.fact_check_outlined, size: 44),
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
                    Text(
                      '${toBanglaDigits('${items.length}')}টি করণীয় · '
                      '${toBanglaDigits('$reminders')}টি দৈনিক রিমাইন্ডার। '
                      'সময়, নোটিফিকেশনের নাম ও কন্টেন্ট এখানেই ঠিক করে নিন।',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SukunSpace.md),
        for (final item in items) ...[
          _rowForItem(item),
          const SizedBox(height: SukunSpace.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _reviewing = false),
            icon: const Icon(Icons.add_rounded),
            label: const Text('আরও বাছাই করুন'),
          ),
        ),
      ],
    );
  }

  _BulkRow _rowForItem(BulkImportItem item) {
    final template = item.template;
    return _BulkRow(
      key: Key('bulk-review-${item.key}'),
      title: item.title,
      subtitle: template?.instruction ?? _typeLabel(item.resource!.type),
      item: item,
      onToggle: () => setState(() {
        _selected.remove(item.key);
        if (_selected.isEmpty) _reviewing = false;
      }),
      onEditTime: (i) => _editTime(item, i),
      onRemoveTime: (i) => setState(() => item.times.removeAt(i)),
      onVariable: (name, value) => setState(() => item.variables[name] = value),
      onDuration: widget.showDuration
          ? (days) => setState(() => item.durationDays = days)
          : null,
      onPickResource: template == null ? null : () => _pickResource(item),
      onRemoveResource: template == null
          ? null
          : (id) => setState(() => item.resourceIds.remove(id)),
      linkedResources: _linkedResources(item),
      needsResource: template?.requiresLinkedResource ?? false,
      onNotificationTitle: (value) =>
          setState(() => item.notificationTitle = value),
      onReminderEnabled: widget.showDuration
          ? (value) => setState(() => item.reminderEnabled = value)
          : null,
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
            _templates
                .where(
                  (t) =>
                      t.category == category.id &&
                      _matches('${t.title} ${t.instruction}'),
                )
                .toList(growable: false),
            _customs
                .where((t) => t.category == category.id)
                .toList(growable: false),
          ),
    ].where((g) => g.$2.isNotEmpty || g.$3.isNotEmpty).toList();
    return [
      SliverToBoxAdapter(
        child: _filters([
          (null, 'সব'),
          for (final category in officialTemplateCategories)
            (category.id, category.title),
        ]),
      ),
      if (_canEditTemplates)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.page - 8,
              SukunSpace.sm,
              SukunSpace.page,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('bulk-template-new'),
                onPressed: () => _editTemplate(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('নতুন টেমপ্লেট যোগ করুন'),
              ),
            ),
          ),
        ),
      if (groups.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(SukunSpace.page),
            child: Text('কিছু পাওয়া যায়নি। অন্য শব্দ লিখে দেখুন।'),
          ),
        ),
      for (final (category, templates, customs) in groups) ...[
        if (category.id == 'bath' &&
            templates.any((t) => GhuslKind.forTemplate(t.id) != null))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SukunSpace.page,
                SukunSpace.md,
                SukunSpace.page,
                0,
              ),
              child: _GhuslCalendarCard(
                counts: {
                  for (final kind in GhuslKind.values)
                    kind:
                        _selected['t:${kind.templateId}']
                            ?.calendarDates
                            .length ??
                        0,
                },
                onOpen: () => _openGhuslCalendar(),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _GroupHeader(
            title: category.title,
            subtitle: category.subtitle,
            total: templates.length + customs.length,
            selected:
                templates
                    .where((t) => _selected.containsKey('t:${t.id}'))
                    .length +
                customs.where((t) => _selected.containsKey('c:${t.id}')).length,
            onSelectAll: (select) => _setGroup(templates, select, customs),
          ),
        ),
        if (customs.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.page,
              0,
              SukunSpace.page,
              SukunSpace.sm,
            ),
            sliver: SliverList.separated(
              itemCount: customs.length,
              separatorBuilder: (_, _) => const SizedBox(height: SukunSpace.sm),
              itemBuilder: (context, index) {
                final draft = customs[index];
                final item = _selected['c:${draft.id}'];
                return _BulkRow(
                  key: Key('bulk-custom-${draft.id}'),
                  title: draft.title,
                  subtitle: draft.instruction == draft.title
                      ? 'নিজের যোগ করা · শুধু এখানে'
                      : draft.instruction,
                  badge: 'নতুন',
                  item: item,
                  onEditTemplate: () =>
                      _addCustom(draft.category, existing: draft),
                  onToggle: () => _toggleCustom(draft),
                  onEditTime: (i) => _editTime(item!, i),
                  onRemoveTime: (i) => setState(() => item!.times.removeAt(i)),
                  onVariable: (_, _) {},
                  onDuration: widget.showDuration
                      ? (days) => setState(() => item!.durationDays = days)
                      : null,
                  onPickResource: () => _pickResource(item!),
                  onRemoveResource: (id) =>
                      setState(() => item!.resourceIds.remove(id)),
                  linkedResources: _linkedResources(item),
                  needsResource: draft.requiresLinkedResource,
                  onNotificationTitle: (value) =>
                      setState(() => item!.notificationTitle = value),
                  onReminderEnabled: widget.showDuration
                      ? (value) => setState(() => item!.reminderEnabled = value)
                      : null,
                );
              },
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
                onEditTemplate: _canEditTemplates
                    ? () => _editTemplate(template)
                    : null,
                onToggle: () => _toggleTemplate(template),
                onEditTime: (i) => _editTime(item!, i),
                onRemoveTime: (i) => setState(() => item!.times.removeAt(i)),
                onVariable: (name, value) =>
                    setState(() => item!.variables[name] = value),
                onDuration: widget.showDuration
                    ? (days) => setState(() => item!.durationDays = days)
                    : null,
                onPickResource: () => _pickResource(item!),
                onRemoveResource: (id) =>
                    setState(() => item!.resourceIds.remove(id)),
                linkedResources: _linkedResources(item),
                needsResource: template.requiresLinkedResource,
                onNotificationTitle: (value) =>
                    setState(() => item!.notificationTitle = value),
                onReminderEnabled: widget.showDuration
                    ? (value) => setState(() => item!.reminderEnabled = value)
                    : null,
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            SukunSpace.page,
            SukunSpace.sm,
            SukunSpace.page,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _AddNewTile(
              key: Key('bulk-add-new-${category.id}'),
              label: '${category.title}-এ নতুন যোগ করুন',
              onTap: () => _addCustom(category.id),
            ),
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
                onRemoveResource: null,
                linkedResources: const [],
                needsResource: false,
                onNotificationTitle: (value) =>
                    setState(() => item!.notificationTitle = value),
                onReminderEnabled: widget.showDuration
                    ? (value) => setState(() => item!.reminderEnabled = value)
                    : null,
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
    final all = total > 0 && selected == total;
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
          if (total > 0)
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

/// Dashed "+ নতুন যোগ করুন" row closing each section's list.
class _AddNewTile extends StatelessWidget {
  const _AddNewTile({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SukunColors.paleBlue,
    borderRadius: BorderRadius.circular(SukunRadius.tile),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SukunRadius.tile),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SukunRadius.tile),
          border: Border.all(
            color: SukunColors.sukunBlue.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: SukunColors.sukunBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: SukunSpace.md),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: SukunColors.deepTide,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _CustomDraft {
  const _CustomDraft(this.title, this.instruction);

  final String title;
  final String instruction;
}

/// A short form for a one-off row in one section. Nothing is inferred: the
/// writer types the name and, if they want, the instruction in their words.
class _CustomItemSheet extends StatefulWidget {
  const _CustomItemSheet({
    required this.categoryTitle,
    this.initialTitle,
    this.initialInstruction,
  });

  final String categoryTitle;
  final String? initialTitle;
  final String? initialInstruction;

  @override
  State<_CustomItemSheet> createState() => _CustomItemSheetState();
}

class _CustomItemSheetState extends State<_CustomItemSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _instruction = TextEditingController(
    text: widget.initialInstruction,
  );

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(_CustomDraft(title, _instruction.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.initialTitle != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SukunSpace.page,
        0,
        SukunSpace.page,
        MediaQuery.viewInsetsOf(context).bottom + SukunSpace.page,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SukunIconBadge(icon: Icons.add_task_rounded, size: 40),
                const SizedBox(width: SukunSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editing ? 'আইটেম এডিট' : 'নতুন যোগ করুন',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${widget.categoryTitle} · শুধু এই তালিকার জন্য, '
                        'টেমপ্লেটে সেভ হবে না',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SukunColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SukunSpace.lg),
            TextField(
              key: const Key('bulk-custom-title'),
              controller: _title,
              autofocus: true,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'নাম',
                hintText: 'যেমন: সকালে মধু খাওয়া',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SukunSpace.sm),
            TextField(
              key: const Key('bulk-custom-instruction'),
              controller: _instruction,
              minLines: 2,
              maxLines: 5,
              maxLength: 600,
              decoration: const InputDecoration(
                labelText: 'নির্দেশনা (ঐচ্ছিক)',
                hintText: 'কী করতে হবে, নিজের ভাষায় লিখুন',
              ),
            ),
            const SizedBox(height: SukunSpace.md),
            FilledButton.icon(
              key: const Key('bulk-custom-save'),
              onPressed: _title.text.trim().isEmpty ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(editing ? 'সেভ করুন' : 'যোগ করুন ও টিক দিন'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LinkedResource {
  const _LinkedResource(this.id, this.resource);

  final String id;

  /// Null while the library is still loading.
  final ContentResourceOption? resource;

  String get label {
    final title = resource?.displayTitle;
    if (title != null) return title;
    final surah = id.startsWith('quran:') ? id.substring(6) : null;
    return surah == null ? 'যুক্ত কন্টেন্ট' : 'সূরা ${toBanglaDigits(surah)}';
  }

  IconData get icon => switch (resource?.type) {
    'audio' => Icons.headphones_rounded,
    'video' => Icons.play_circle_outline_rounded,
    'pdf' => Icons.picture_as_pdf_outlined,
    'quran' => Icons.menu_book_rounded,
    _ when id.startsWith('quran:') => Icons.menu_book_rounded,
    _ => Icons.article_outlined,
  };
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
    required this.onRemoveResource,
    required this.linkedResources,
    required this.needsResource,
    required this.onNotificationTitle,
    this.onReminderEnabled,
    this.onEditTemplate,
    this.badge,
  });

  final String title;
  final String subtitle;

  /// Small tag after the title, e.g. "নতুন" for a hand-written row.
  final String? badge;
  final BulkImportItem? item;
  final VoidCallback onToggle;
  final ValueChanged<int> onEditTime;
  final ValueChanged<int> onRemoveTime;
  final void Function(String variable, int value) onVariable;
  final ValueChanged<int?>? onDuration;
  final VoidCallback? onPickResource;
  final ValueChanged<String>? onRemoveResource;
  final List<_LinkedResource> linkedResources;
  final bool needsResource;
  final ValueChanged<String> onNotificationTitle;

  /// Null hides the switch (routines are always on).
  final ValueChanged<bool>? onReminderEnabled;

  /// Opens the template editor (Super Admin, live templates only).
  final VoidCallback? onEditTemplate;

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
                          Text.rich(
                            TextSpan(
                              text: title,
                              children: [
                                if (badge != null)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SukunColors.mist,
                                        borderRadius: BorderRadius.circular(
                                          SukunRadius.chip,
                                        ),
                                      ),
                                      child: Text(
                                        badge!,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: SukunColors.deepTide,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
                  if (onEditTemplate != null)
                    IconButton(
                      tooltip: 'টেমপ্লেট এডিট',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEditTemplate,
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
                  _ReminderNameField(
                    key: ValueKey('bulk-name-${item!.key}'),
                    initial: item!.notificationTitle,
                    fallback: item!.defaultNotificationTitle,
                    onChanged: onNotificationTitle,
                  ),
                  if (onReminderEnabled != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item!.reminderEnabled
                                ? 'রিমাইন্ডার চালু'
                                : 'রিমাইন্ডার বন্ধ (শুধু তালিকায় থাকবে)',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Switch.adaptive(
                          key: ValueKey('bulk-reminder-${item!.key}'),
                          value: item!.reminderEnabled,
                          onChanged: onReminderEnabled,
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
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
                  if (onPickResource != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            linkedResources.isEmpty
                                ? 'কন্টেন্ট (অডিও, সূরা, দুআ, গাইড)'
                                : 'যুক্ত কন্টেন্ট '
                                      '(${toBanglaDigits('${linkedResources.length}')})',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: SukunColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final linked in linkedResources)
                                InputChip(
                                  key: Key('bulk-linked-${linked.id}'),
                                  avatar: Icon(linked.icon, size: 16),
                                  label: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 220,
                                    ),
                                    child: Text(
                                      linked.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  onDeleted: onRemoveResource == null
                                      ? null
                                      : () => onRemoveResource!(linked.id),
                                  deleteButtonTooltipMessage:
                                      'কন্টেন্ট বাদ দিন',
                                ),
                              if (linkedResources.length <
                                  bulkMaxResourcesPerItem)
                                ActionChip(
                                  key: const Key('bulk-add-resource'),
                                  avatar: const Icon(
                                    Icons.add_link_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    linkedResources.isEmpty
                                        ? 'কন্টেন্ট যোগ'
                                        : 'আরও কন্টেন্ট যোগ',
                                  ),
                                  onPressed: onPickResource,
                                ),
                            ],
                          ),
                        ],
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

/// "What the phone will say": the reminder name, editable in place. Blank
/// falls back to the row title.
class _ReminderNameField extends StatefulWidget {
  const _ReminderNameField({
    super.key,
    required this.initial,
    required this.fallback,
    required this.onChanged,
  });

  final String? initial;
  final String fallback;
  final ValueChanged<String> onChanged;

  @override
  State<_ReminderNameField> createState() => _ReminderNameFieldState();
}

class _ReminderNameFieldState extends State<_ReminderNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? widget.fallback,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLength: bulkMaxNotificationTitleLength,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        isDense: true,
        counterText: '',
        prefixIcon: Icon(Icons.notifications_none_rounded, size: 20),
        labelText: 'নোটিফিকেশনে যে নাম দেখাবে',
        helperText: 'ফাঁকা রাখলে উপরের শিরোনাম দেখাবে',
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Entry to the ghusl calendar inside the bath section, with a colour dot
/// and day count per bath.
class _GhuslCalendarCard extends StatelessWidget {
  const _GhuslCalendarCard({required this.counts, required this.onOpen});

  final Map<GhuslKind, int> counts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SukunSurface(
      key: const Key('bulk-ghusl-calendar'),
      onTap: onOpen,
      padding: const EdgeInsets.all(SukunSpace.lg),
      child: Row(
        children: [
          const SukunIconBadge(icon: Icons.calendar_month_rounded, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'গোসল ক্যালেন্ডার',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (final kind in GhuslKind.values)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: ghuslColor(kind),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${kind.label.split(' ').first} '
                            '${toBanglaDigits('${counts[kind] ?? 0}')}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
