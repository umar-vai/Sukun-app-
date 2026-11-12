import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_template_repository.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/presentation/care_template_editor_screen.dart';

/// The permanent home of the Sukun Life official templates (owner request
/// 2026-11-12). A Super Admin edits, adds and removes templates here; every
/// import uses the saved version. Removing hides a template (audited,
/// reversible), it never deletes history. Plans already imported keep their
/// own copy.
class CareTemplatesAdminScreen extends ConsumerStatefulWidget {
  const CareTemplatesAdminScreen({super.key});

  @override
  ConsumerState<CareTemplatesAdminScreen> createState() =>
      _CareTemplatesAdminScreenState();
}

class _CareTemplatesAdminScreenState
    extends ConsumerState<CareTemplatesAdminScreen> {
  final _search = TextEditingController();
  CareTemplateCatalog? _catalog;
  late final Future<List<ContentResourceOption>> _resources = ref
      .read(carePlansRepositoryProvider)
      .getAvailableResources();
  String? _category;
  bool _showHidden = false;

  CareTemplateRepository get _repository =>
      ref.read(careTemplateRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final catalog = await _repository.load();
    if (mounted) setState(() => _catalog = catalog);
  }

  void _replace(OfficialPrescriptionTemplate saved) {
    final catalog = _catalog;
    if (catalog == null) return;
    final list = [...catalog.templates];
    final index = list.indexWhere((t) => t.id == saved.id);
    if (index >= 0) {
      list[index] = saved;
    } else {
      list.add(saved);
    }
    setState(() {
      _catalog = CareTemplateCatalog(
        templates: List.unmodifiable(list),
        editable: catalog.editable,
      );
    });
  }

  Future<void> _edit({
    OfficialPrescriptionTemplate? template,
    String? category,
  }) async {
    final catalog = _catalog;
    if (catalog == null || !catalog.editable) {
      _toast('এখন টেমপ্লেট এডিট করা যাচ্ছে না। সংযোগ দেখে আবার চেষ্টা করুন।');
      return;
    }
    List<ContentResourceOption> resources = const [];
    try {
      resources = await _resources;
    } catch (_) {
      // Editing still works; content names show as their stable link.
    }
    if (!mounted) return;
    final saved = await showCareTemplateEditor(
      context,
      template: template,
      initialCategory: category ?? _category,
      resources: resources,
      save: _repository.save,
    );
    if (saved == null || !mounted) return;
    _replace(saved);
    _toast('"${saved.title}" সেভ হয়েছে');
  }

  Future<void> _setActive(
    OfficialPrescriptionTemplate template,
    bool active,
  ) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('"${template.title}" সরাবেন?'),
          content: const Text(
            'ইমপোর্টের তালিকায় আর দেখাবে না। আগের প্ল্যান বদলাবে না। '
            'পরে "সরানো" থেকে ফিরিয়ে আনা যাবে।',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('না'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('সরান'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      final saved = await _repository.save(_copy(template, isActive: active));
      if (!mounted) return;
      _replace(saved);
      _toast(active ? 'ফিরিয়ে আনা হয়েছে' : 'সরানো হয়েছে');
    } catch (_) {
      _toast('সেভ করা যায়নি। আবার চেষ্টা করুন।');
    }
  }

  OfficialPrescriptionTemplate _copy(
    OfficialPrescriptionTemplate t, {
    required bool isActive,
  }) => OfficialPrescriptionTemplate(
    id: t.id,
    category: t.category,
    title: t.title,
    instruction: t.instruction,
    actionType: t.actionType,
    defaultTimes: t.defaultTimes ?? defaultTimesForTemplate(t),
    resourceRefs:
        t.resourceRefs ?? officialTemplateResourceRefs[t.id] ?? const [],
    requiresResource: t.requiresLinkedResource,
    notificationTitle: t.notificationTitle,
    isActive: isActive,
    sortOrder: t.sortOrder,
  );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<OfficialPrescriptionTemplate> _visible(CareTemplateCatalog catalog) {
    final term = _search.text.trim().toLowerCase();
    return [
      for (final t in catalog.templates)
        if (t.isActive != _showHidden &&
            (_category == null || t.category == _category) &&
            (term.isEmpty ||
                t.title.toLowerCase().contains(term) ||
                t.instruction.toLowerCase().contains(term)))
          t,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final theme = Theme.of(context);
    final active = catalog?.templates.where((t) => t.isActive).length ?? 0;
    final hidden = catalog?.templates.where((t) => !t.isActive).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('সুকুন অফিসিয়াল টেমপ্লেট')),
      floatingActionButton: catalog?.editable == true
          ? FloatingActionButton.extended(
              key: const Key('care-templates-add'),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('নতুন টেমপ্লেট'),
            )
          : null,
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      SukunSpace.page,
                      SukunSpace.xs,
                      SukunSpace.page,
                      110,
                    ),
                    children: [
                      if (!catalog.editable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: SukunSpace.md),
                          child: SukunSurface(
                            tone: SukunSurfaceTone.warning,
                            padding: const EdgeInsets.all(SukunSpace.md),
                            child: const Text(
                              'অফলাইন কপি দেখানো হচ্ছে। এডিট করতে ইন্টারনেট লাগবে।',
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          _CountBadge(
                            value: active,
                            label: 'চালু',
                            selected: !_showHidden,
                            onTap: () => setState(() => _showHidden = false),
                          ),
                          const SizedBox(width: SukunSpace.sm),
                          _CountBadge(
                            value: hidden,
                            label: 'সরানো',
                            selected: _showHidden,
                            onTap: () => setState(() => _showHidden = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: SukunSpace.md),
                      SukunSearchField(
                        controller: _search,
                        hintText: 'টেমপ্লেট খুঁজুন',
                        onChanged: (_) => setState(() {}),
                        onClear: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: SukunSpace.md),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('সব'),
                                selected: _category == null,
                                onSelected: (_) =>
                                    setState(() => _category = null),
                              ),
                            ),
                            for (final category in officialTemplateCategories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(category.title),
                                  selected: _category == category.id,
                                  onSelected: (_) =>
                                      setState(() => _category = category.id),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SukunSpace.lg),
                      ..._sections(catalog, theme),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _sections(CareTemplateCatalog catalog, ThemeData theme) {
    final visible = _visible(catalog);
    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              _showHidden ? 'কোনো টেমপ្লেট সরানো নেই' : 'কিছু পাওয়া যায়নি',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ];
    }
    return [
      for (final category in officialTemplateCategories)
        if (visible.any((t) => t.category == category.id)) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: 4,
              top: SukunSpace.sm,
              bottom: SukunSpace.sm,
            ),
            child: Row(
              children: [
                Text(category.title, style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                SukunStatusPill(
                  label: toBanglaDigits(
                    '${visible.where((t) => t.category == category.id).length}',
                  ),
                ),
                const Spacer(),
                if (!_showHidden && catalog.editable)
                  IconButton(
                    tooltip: '${category.title}-এ নতুন',
                    onPressed: () => _edit(category: category.id),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
              ],
            ),
          ),
          for (final template in visible.where(
            (t) => t.category == category.id,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: SukunSpace.sm),
              child: _TemplateCard(
                template: template,
                onTap: () => _edit(template: template),
                onToggle: catalog.editable
                    ? () => _setActive(template, !template.isActive)
                    : null,
              ),
            ),
          const SizedBox(height: SukunSpace.md),
        ],
    ];
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: SukunSurface(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        tone: selected ? SukunSurfaceTone.soft : SukunSurfaceTone.white,
        child: Row(
          children: [
            Text(
              toBanglaDigits('$value'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: SukunColors.deepTide,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onToggle,
  });

  final OfficialPrescriptionTemplate template;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = template.defaultTimes ?? defaultTimesForTemplate(template);
    final refs =
        template.resourceRefs ??
        officialTemplateResourceRefs[template.id] ??
        const <String>[];
    return SukunSurface(
      key: Key('care-template-${template.id}'),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final time in times)
                      SukunStatusPill(
                        label: time.label,
                        icon: Icons.alarm_rounded,
                        tone: SukunStatusTone.brand,
                      ),
                    SukunStatusPill(
                      label: '${toBanglaDigits('${refs.length}')} কন্টেন্ট',
                      icon: Icons.link_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onToggle != null)
            IconButton(
              tooltip: template.isActive ? 'সরান' : 'ফিরিয়ে আনুন',
              onPressed: onToggle,
              icon: Icon(
                template.isActive
                    ? Icons.delete_outline_rounded
                    : Icons.restore_rounded,
              ),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
