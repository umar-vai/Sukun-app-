import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';

class OfficialTemplateBulkPicker extends StatefulWidget {
  const OfficialTemplateBulkPicker({
    super.key,
    required this.importedIds,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onImport,
    required this.working,
  });

  final Set<String> importedIds;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final VoidCallback onImport;
  final bool working;

  @override
  State<OfficialTemplateBulkPicker> createState() =>
      _OfficialTemplateBulkPickerState();
}

class _OfficialTemplateBulkPickerState
    extends State<OfficialTemplateBulkPicker> {
  String _query = '';

  void _select(
    Iterable<OfficialPrescriptionTemplate> templates,
    bool selected,
  ) {
    final ids = templates.map((template) => template.id);
    widget.onSelectionChanged({
      if (selected)
        ...widget.selectedIds
      else
        ...widget.selectedIds.difference(ids.toSet()),
      if (selected) ...ids,
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sukun Life Official Templates',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('official-template-search'),
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'টেমপ্লেট খুঁজুন',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final category in officialTemplateCategories)
                _category(category, query),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: widget.selectedIds.isEmpty || widget.working
                ? null
                : widget.onImport,
            icon: const Icon(Icons.playlist_add),
            label: Text('Import Selected (${widget.selectedIds.length})'),
          ),
        ),
      ],
    );
  }

  Widget _category(OfficialTemplateCategory category, String query) {
    final all = officialPrescriptionTemplates
        .where((template) => template.category == category.id)
        .toList();
    final visible = all
        .where(
          (template) =>
              '${template.title} ${template.instruction} ${category.title}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final available = all.where(
      (template) => !widget.importedIds.contains(template.id),
    );
    final visibleAvailable = visible.where(
      (template) => !widget.importedIds.contains(template.id),
    );
    final count = all
        .where((template) => widget.selectedIds.contains(template.id))
        .length;
    return ExpansionTile(
      key: ValueKey('official-category-${category.id}-${query.isNotEmpty}'),
      initiallyExpanded: query.isNotEmpty,
      title: Text(category.title),
      trailing: SukunStatusPill(
        label: '$count / ${all.length}',
        tone: SukunStatusTone.brand,
      ),
      children: [
        Wrap(
          children: [
            TextButton(
              key: Key('select-category-${category.id}'),
              onPressed: !widget.working && available.isNotEmpty
                  ? () => _select(available, true)
                  : null,
              child: const Text('পুরো বিভাগ নির্বাচন'),
            ),
            TextButton(
              onPressed: !widget.working && count > 0
                  ? () => _select(all, false)
                  : null,
              child: const Text('বিভাগের নির্বাচন বাতিল'),
            ),
            if (query.isNotEmpty)
              TextButton(
                onPressed: !widget.working && visibleAvailable.isNotEmpty
                    ? () => _select(visibleAvailable, true)
                    : null,
                child: const Text('শুধু অনুসন্ধানের ফল নির্বাচন'),
              ),
          ],
        ),
        for (final template in visible)
          CheckboxListTile(
            key: Key('official-template-${template.id}'),
            controlAffinity: ListTileControlAffinity.leading,
            value:
                widget.importedIds.contains(template.id) ||
                widget.selectedIds.contains(template.id),
            onChanged:
                widget.working || widget.importedIds.contains(template.id)
                ? null
                : (value) => _select([template], value == true),
            title: Text(template.title),
            subtitle: widget.importedIds.contains(template.id)
                ? const Text('খসড়ায় যোগ হয়েছে')
                : null,
          ),
      ],
    );
  }
}
