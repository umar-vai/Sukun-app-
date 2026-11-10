import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';

/// Opens the editor for one template (or a new one when [template] is null).
/// Returns the saved template, or null if the admin left without saving.
Future<OfficialPrescriptionTemplate?> showCareTemplateEditor(
  BuildContext context, {
  OfficialPrescriptionTemplate? template,
  String? initialCategory,
  required List<ContentResourceOption> resources,
  required Future<OfficialPrescriptionTemplate> Function(
    OfficialPrescriptionTemplate draft,
  )
  save,
}) {
  return Navigator.of(context).push<OfficialPrescriptionTemplate>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CareTemplateEditorScreen(
        template: template,
        initialCategory: initialCategory,
        resources: resources,
        save: save,
      ),
    ),
  );
}

/// Super Admin edits a prescription template. Saving updates the database
/// at once, so the next import uses it; no app deploy is needed. Plans that
/// were already imported keep their own copy of the text.
class CareTemplateEditorScreen extends StatefulWidget {
  const CareTemplateEditorScreen({
    super.key,
    this.template,
    this.initialCategory,
    required this.resources,
    required this.save,
  });

  final OfficialPrescriptionTemplate? template;
  final String? initialCategory;
  final List<ContentResourceOption> resources;
  final Future<OfficialPrescriptionTemplate> Function(
    OfficialPrescriptionTemplate draft,
  )
  save;

  @override
  State<CareTemplateEditorScreen> createState() =>
      _CareTemplateEditorScreenState();
}

class _CareTemplateEditorScreenState extends State<CareTemplateEditorScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.template?.title ?? '',
  );
  late final TextEditingController _instruction = TextEditingController(
    text: widget.template?.instruction ?? '',
  );
  late String _category =
      widget.template?.category ??
      widget.initialCategory ??
      officialTemplateCategories.first.id;
  late final List<ReminderClock> _times = widget.template == null
      ? [const ReminderClock(8, 0)]
      : defaultTimesForTemplate(widget.template!);
  late final List<String> _refs = widget.template == null
      ? []
      : List.of(
          widget.template!.resourceRefs ??
              officialTemplateResourceRefs[widget.template!.id] ??
              const <String>[],
        );
  late bool _requiresResource =
      widget.template?.requiresLinkedResource ?? false;
  late bool _active = widget.template?.isActive ?? true;
  bool _saving = false;

  bool get _isNew => widget.template == null || widget.template!.id.isEmpty;

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    super.dispose();
  }

  ContentResourceOption? _resourceForRef(String ref) {
    for (final resource in widget.resources) {
      if (resource.id == ref || resource.slug == ref) return resource;
    }
    return null;
  }

  String _refLabel(String ref) {
    final title = _resourceForRef(ref)?.displayTitle;
    if (title != null) return title;
    if (ref.startsWith('quran:')) {
      return 'সূরা ${toBanglaDigits(ref.substring(6))}';
    }
    return '$ref (লাইব্রেরিতে নেই)';
  }

  IconData _refIcon(String ref) => switch (_resourceForRef(ref)?.type) {
    'audio' => Icons.headphones_rounded,
    'video' => Icons.play_circle_outline_rounded,
    'pdf' => Icons.picture_as_pdf_outlined,
    _ when ref.startsWith('quran:') => Icons.menu_book_rounded,
    _ => Icons.article_outlined,
  };

  void _insertVariable(String name) {
    final token = '{$name}';
    final selection = _instruction.selection;
    final text = _instruction.text;
    final at = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _instruction.value = TextEditingValue(
      text: text.replaceRange(at, end, token),
      selection: TextSelection.collapsed(offset: at + token.length),
    );
    setState(() {});
  }

  Future<void> _editTime(int index) async {
    final current = index < _times.length
        ? _times[index]
        : const ReminderClock(8, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'ডিফল্ট রিমাইন্ডারের সময়',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final clock = ReminderClock(picked.hour, picked.minute);
      if (index < _times.length) {
        _times[index] = clock;
      } else if (_times.length < 8) {
        _times.add(clock);
      }
      final unique = _times.toSet().toList()..sort();
      _times
        ..clear()
        ..addAll(unique);
    });
  }

  Future<void> _addContent() async {
    if (_refs.length >= bulkMaxResourcesPerItem) return;
    final id = await showResourcePickerSheet(
      context: context,
      resources: widget.resources,
      selectedId: '',
    );
    if (id == null || id.isEmpty || !mounted) return;
    final resource = _resourceForRef(id);
    // Templates store stable references, never database UUIDs, so they
    // survive a re-import of the library.
    final ref = id.startsWith('quran:') ? id : resource?.slug;
    if (ref == null || ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'এই কন্টেন্টের স্থায়ী লিংক (slug) নেই, তাই টেমপ্লেটে রাখা যাবে না।',
          ),
        ),
      );
      return;
    }
    if (_refs.contains(ref)) return;
    setState(() => _refs.add(ref));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final instruction = _instruction.text.trim();
    if (title.isEmpty || instruction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('শিরোনাম ও নির্দেশনা দুটোই লিখুন।')),
      );
      return;
    }
    setState(() => _saving = true);
    final draft = OfficialPrescriptionTemplate(
      id: _isNew ? '' : widget.template!.id,
      category: _category,
      title: title,
      instruction: instruction,
      actionType: actionTypeForTemplateCategory(_category),
      defaultTimes: List.of(_times),
      resourceRefs: List.of(_refs),
      requiresResource: _requiresResource,
      isActive: _active,
      sortOrder: widget.template?.sortOrder ?? 0,
    );
    try {
      final saved = await widget.save(draft);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'সেভ করা যায়নি। সংযোগ ও Super Admin অনুমতি দেখে আবার চেষ্টা করুন।',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: SukunSpace.lg, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(color: SukunColors.muted),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'নতুন টেমপ্লেট' : 'টেমপ্লেট এডিট'),
        actions: [
          TextButton(
            key: const Key('care-template-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'সেভ হচ্ছে…' : 'সেভ'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.page,
              SukunSpace.md,
              SukunSpace.page,
              48,
            ),
            children: [
              Text(
                'সেভ করলেই পরের ইমপোর্ট থেকে নতুন লেখা, সময় ও কন্টেন্ট যাবে। '
                'আগে ইমপোর্ট করা প্ল্যান বদলাবে না।',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: SukunColors.muted,
                ),
              ),
              label('বিভাগ'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: [
                  for (final category in officialTemplateCategories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.title),
                    ),
                ],
                // The id letter follows the category, so it is fixed once saved.
                onChanged: _isNew
                    ? (value) => setState(() => _category = value ?? _category)
                    : null,
              ),
              label('শিরোনাম'),
              TextField(
                key: const Key('care-template-title'),
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(counterText: ''),
              ),
              label('নির্দেশনা'),
              TextField(
                key: const Key('care-template-instruction'),
                controller: _instruction,
                maxLength: 2000,
                minLines: 3,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  helperText: 'সংখ্যা ইমপোর্টের সময় বাছাই হবে এমন জায়গায় নিচের ঘর বসান',
                  helperMaxLines: 2,
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final name in OfficialPrescriptionTemplate.variables)
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text('{$name}'),
                      onPressed: () => _insertVariable(name),
                    ),
                ],
              ),
              label('ডিফল্ট রিমাইন্ডারের সময়'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _times.length; i++)
                    InputChip(
                      avatar: const Icon(Icons.alarm_rounded, size: 16),
                      label: Text(_times[i].label),
                      onPressed: () => _editTime(i),
                      onDeleted: () => setState(() => _times.removeAt(i)),
                    ),
                  if (_times.length < 8)
                    ActionChip(
                      avatar: const Icon(Icons.add_alarm_rounded, size: 16),
                      label: const Text('সময় যোগ'),
                      onPressed: () => _editTime(_times.length),
                    ),
                ],
              ),
              label(
                'কন্টেন্ট (লেখা ও অডিও) '
                '${toBanglaDigits('${_refs.length}')}/'
                '${toBanglaDigits('$bulkMaxResourcesPerItem')}',
              ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) => setState(() {
                  _refs.insert(to, _refs.removeAt(from));
                }),
                children: [
                  for (var i = 0; i < _refs.length; i++)
                    ListTile(
                      key: ValueKey('ref-${_refs[i]}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(_refIcon(_refs[i])),
                      title: Text(_refLabel(_refs[i])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'বাদ দিন',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _refs.removeAt(i)),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_refs.length < bulkMaxResourcesPerItem)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('care-template-add-content'),
                    onPressed: _addContent,
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('কন্টেন্ট যোগ'),
                  ),
                ),
              const Divider(height: SukunSpace.section),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _requiresResource,
                onChanged: (value) => setState(() => _requiresResource = value),
                title: const Text('কন্টেন্ট ছাড়া ইমপোর্ট করা যাবে না'),
                subtitle: const Text('যেমন অডিও শোনার টেমপ্লেট'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text('তালিকায় দেখাবে'),
                subtitle: const Text('বন্ধ করলে লুকানো থাকবে, মুছে যাবে না'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
