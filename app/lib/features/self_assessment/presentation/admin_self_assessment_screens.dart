import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/self_assessment/data/self_assessment_repository.dart';
import 'package:sukun_life/features/self_assessment/domain/self_assessment.dart';

/// Super Admin list of every self-assessment test, published or not.
/// Row-level security enforces the same rule in the database.
class AdminSelfAssessmentListScreen extends ConsumerStatefulWidget {
  const AdminSelfAssessmentListScreen({super.key});

  @override
  ConsumerState<AdminSelfAssessmentListScreen> createState() =>
      _AdminSelfAssessmentListScreenState();
}

class _AdminSelfAssessmentListScreenState
    extends ConsumerState<AdminSelfAssessmentListScreen> {
  late Future<List<SelfAssessmentTest>> _tests;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tests = ref.read(selfAssessmentRepositoryProvider).listTests();
  }

  void _reload() => setState(
    () => _tests = ref.read(selfAssessmentRepositoryProvider).listTests(),
  );

  Future<void> _setPublished(SelfAssessmentTest test, bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(selfAssessmentRepositoryProvider).updateTest(test.id, {
        'is_published': value,
      });
      _reload();
    } catch (_) {
      if (mounted) _showSaveError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: 'সেলফ ডায়াগনোসিস টেস্ট',
    selectedIndex: 2,
    body: FutureBuilder<List<SelfAssessmentTest>>(
      future: _tests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(label: 'টেস্ট আনা হচ্ছে…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'টেস্ট আনা যাচ্ছে না।',
            onRetry: _reload,
          );
        }
        final tests = snapshot.data!;
        if (tests.isEmpty) {
          return const AppEmptyState(
            title: 'কোনো টেস্ট নেই',
            message: 'ডাটাবেসে টেস্ট যুক্ত হলে এখানে দেখা যাবে।',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            for (final test in tests)
              Card(
                key: Key('admin-self-test-${test.slug}'),
                child: ListTile(
                  title: Text(test.titleBn),
                  subtitle: Text(
                    '${test.questions.length}টি প্রশ্ন · '
                    '${test.scoresByDimension ? 'বিষয়ভিত্তিক স্কোর' : '${test.bands.length}টি ফলাফল স্তর'}',
                  ),
                  trailing: Switch(
                    value: test.isPublished,
                    onChanged: _saving
                        ? null
                        : (value) => _setPublished(test, value),
                  ),
                  onTap: () async {
                    await context.push('/admin/self-assessment/${test.id}');
                    if (mounted) _reload();
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Edit one test: its text, questions with option scores, result bands
/// and, for a dimension-scored test, the rule and outcome JSON.
class AdminSelfAssessmentEditScreen extends ConsumerStatefulWidget {
  const AdminSelfAssessmentEditScreen({required this.testId, super.key});

  final String testId;

  @override
  ConsumerState<AdminSelfAssessmentEditScreen> createState() =>
      _AdminSelfAssessmentEditScreenState();
}

class _AdminSelfAssessmentEditScreenState
    extends ConsumerState<AdminSelfAssessmentEditScreen> {
  late Future<SelfAssessmentTest?> _test;
  bool _saving = false;

  SelfAssessmentRepository get _repository =>
      ref.read(selfAssessmentRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _test = _load();
  }

  Future<SelfAssessmentTest?> _load() async {
    final tests = await _repository.listTests();
    return tests.where((test) => test.id == widget.testId).firstOrNull;
  }

  void _reload() => setState(() => _test = _load());

  Future<bool> _mutate(Future<void> Function() action) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return true;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('সংরক্ষণ হয়েছে।')));
      _reload();
      return true;
    } catch (_) {
      if (mounted) _showSaveError(context);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SelfAssessmentTest?>(
      future: _test,
      builder: (context, snapshot) {
        final test = snapshot.data;
        return AdminScaffold(
          title: test?.titleBn ?? 'টেস্ট সম্পাদনা',
          selectedIndex: 2,
          body: switch (snapshot.connectionState) {
            ConnectionState.waiting => const AppLoadingState(),
            _ when snapshot.hasError => AppErrorState(
              message: 'টেস্ট আনা যাচ্ছে না।',
              onRetry: _reload,
            ),
            _ when test == null => const AppEmptyState(
              title: 'টেস্ট পাওয়া যায়নি',
              message: 'তালিকায় ফিরে যান।',
            ),
            _ => _editor(context, test),
          },
        );
      },
    );
  }

  Widget _editor(BuildContext context, SelfAssessmentTest test) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        _TestInfoForm(
          key: ValueKey('info-${test.id}-${test.titleBn}-${test.sortOrder}'),
          test: test,
          saving: _saving,
          onSave: (fields) =>
              _mutate(() => _repository.updateTest(test.id, fields)),
        ),
        const SizedBox(height: 20),
        SukunSectionHeader(
          title: 'প্রশ্নসমূহ (${test.questions.length})',
          action: TextButton.icon(
            key: const Key('admin-self-add-question'),
            onPressed: _saving ? null : () => _editQuestion(test, null),
            icon: const Icon(Icons.add),
            label: const Text('প্রশ্ন যোগ করুন'),
          ),
        ),
        const SizedBox(height: 8),
        for (final (index, question) in test.questions.indexed)
          Card(
            child: ListTile(
              key: Key('admin-self-question-${question.id}'),
              title: Text('${index + 1}. ${question.questionBn}'),
              subtitle: Text(
                question.options
                    .map(
                      (option) =>
                          '${option.label}: ${option.scores.isEmpty ? option.score : option.scores.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
                    )
                    .join(' · '),
              ),
              onTap: _saving ? null : () => _editQuestion(test, question),
              trailing: IconButton(
                tooltip: 'মুছুন',
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving
                    ? null
                    : () async {
                        if (await _confirm(context, 'প্রশ্নটি মুছবেন?')) {
                          await _mutate(
                            () => _repository.deleteQuestion(question.id),
                          );
                        }
                      },
              ),
            ),
          ),
        const SizedBox(height: 20),
        if (test.scoresByDimension)
          _RulesEditor(
            key: ValueKey('rules-${test.id}-${test.rawRules.length}'),
            test: test,
            saving: _saving,
            onSave: (fields) =>
                _mutate(() => _repository.updateTest(test.id, fields)),
          )
        else ...[
          SukunSectionHeader(
            title: 'ফলাফলের স্তর (${test.bands.length})',
            action: TextButton.icon(
              key: const Key('admin-self-add-band'),
              onPressed: _saving ? null : () => _editBand(test, null),
              icon: const Icon(Icons.add),
              label: const Text('স্তর যোগ করুন'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'মোট স্কোর যে স্তরের সর্বনিম্ন স্কোরের সমান বা বেশি, সেই স্তরের বার্তা দেখানো হয়। সবচেয়ে বড় মিলে যাওয়া স্তরটি নেওয়া হয়।',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final band in test.bands)
            Card(
              child: ListTile(
                key: Key('admin-self-band-${band.id}'),
                leading: CircleAvatar(child: Text('${band.minScore}')),
                title: Text(band.messageBn),
                subtitle: Text(
                  band.needsRuqyah
                      ? 'রুকইয়াহর পরামর্শ: হ্যাঁ'
                      : 'রুকইয়াহর পরামর্শ: না',
                ),
                onTap: _saving ? null : () => _editBand(test, band),
                trailing: IconButton(
                  tooltip: 'মুছুন',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (await _confirm(context, 'স্তরটি মুছবেন?')) {
                            await _mutate(
                              () => _repository.deleteBand(band.id),
                            );
                          }
                        },
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _editQuestion(
    SelfAssessmentTest test,
    SelfAssessmentQuestion? question,
  ) async {
    final draft = await showDialog<_QuestionDraft>(
      context: context,
      builder: (_) => _QuestionDialog(
        test: test,
        question: question,
        nextSortOrder: test.questions.isEmpty
            ? 1
            : test.questions.last.sortOrder + 1,
      ),
    );
    if (draft == null) return;
    await _mutate(
      () => _repository.saveQuestion(
        testId: test.id,
        questionId: question?.id,
        sortOrder: draft.sortOrder,
        questionBn: draft.questionBn,
        options: draft.options,
      ),
    );
  }

  Future<void> _editBand(
    SelfAssessmentTest test,
    SelfAssessmentBand? band,
  ) async {
    final draft = await showDialog<_BandDraft>(
      context: context,
      builder: (_) => _BandDialog(band: band),
    );
    if (draft == null) return;
    if (test.bands.any(
      (other) => other.id != band?.id && other.minScore == draft.minScore,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('এই সর্বনিম্ন স্কোরের একটি স্তর আগে থেকেই আছে।'),
        ),
      );
      return;
    }
    await _mutate(
      () => _repository.saveBand(
        testId: test.id,
        bandId: band?.id,
        minScore: draft.minScore,
        messageBn: draft.messageBn,
        needsRuqyah: draft.needsRuqyah,
      ),
    );
  }
}

class _TestInfoForm extends StatefulWidget {
  const _TestInfoForm({
    required this.test,
    required this.saving,
    required this.onSave,
    super.key,
  });

  final SelfAssessmentTest test;
  final bool saving;
  final Future<bool> Function(Map<String, dynamic> fields) onSave;

  @override
  State<_TestInfoForm> createState() => _TestInfoFormState();
}

class _TestInfoFormState extends State<_TestInfoForm> {
  late final _title = TextEditingController(text: widget.test.titleBn);
  late final _description = TextEditingController(
    text: widget.test.descriptionBn ?? '',
  );
  late final _note = TextEditingController(text: widget.test.noteBn ?? '');
  late final _fallback = TextEditingController(
    text: widget.test.fallbackBn ?? '',
  );
  late final _order = TextEditingController(text: '${widget.test.sortOrder}');
  late bool _published = widget.test.isPublished;

  @override
  void dispose() {
    for (final controller in [_title, _description, _note, _fallback, _order]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _clean(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('admin-self-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'শিরোনাম'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'বিবরণ'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'ফলাফলের নিচে সতর্কতা',
            ),
          ),
          if (widget.test.scoresByDimension) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _fallback,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'কোনো ফলাফল না মিললে বার্তা',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'তালিকায় ক্রম'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('প্রকাশিত'),
            value: _published,
            onChanged: (value) => setState(() => _published = value),
          ),
          FilledButton.icon(
            key: const Key('admin-self-save-info'),
            onPressed: widget.saving
                ? null
                : () {
                    final title = _clean(_title);
                    if (title == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('শিরোনাম দিন।')),
                      );
                      return;
                    }
                    widget.onSave({
                      'title_bn': title,
                      'description_bn': _clean(_description),
                      'note_bn': _clean(_note),
                      if (widget.test.scoresByDimension)
                        'fallback_bn': _clean(_fallback),
                      'sort_order': int.tryParse(_order.text.trim()) ?? 0,
                      'is_published': _published,
                    });
                  },
            icon: const Icon(Icons.save_outlined),
            label: const Text('তথ্য সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }
}

class _RulesEditor extends StatefulWidget {
  const _RulesEditor({
    required this.test,
    required this.saving,
    required this.onSave,
    super.key,
  });

  final SelfAssessmentTest test;
  final bool saving;
  final Future<bool> Function(Map<String, dynamic> fields) onSave;

  @override
  State<_RulesEditor> createState() => _RulesEditorState();
}

class _RulesEditorState extends State<_RulesEditor> {
  static const _encoder = JsonEncoder.withIndent('  ');
  late final _dimensions = TextEditingController(
    text: _encoder.convert(widget.test.rawDimensions),
  );
  late final _rules = TextEditingController(
    text: _encoder.convert(widget.test.rawRules),
  );
  late final _outcomes = TextEditingController(
    text: _encoder.convert(widget.test.rawOutcomes),
  );

  @override
  void dispose() {
    _dimensions.dispose();
    _rules.dispose();
    _outcomes.dispose();
    super.dispose();
  }

  List<dynamic>? _parse(TextEditingController controller) {
    try {
      final value = jsonDecode(controller.text);
      return value is List ? value : null;
    } catch (_) {
      return null;
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      minLines: 4,
      maxLines: 14,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'বিষয়ভিত্তিক ফলাফলের নিয়ম',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'প্রতিটি উত্তরে বিষয়ভিত্তিক স্কোর যোগ হয়। নিয়মগুলো উপর থেকে '
            'নিচে মেলানো হয়; প্রথম যে নিয়মের সব সীমা (min, max) মিলে, সেটির '
            'flags ঠিক করে কোন বিষয়গুলো চিহ্নিত হবে। তারপর ঠিক সেই flags '
            'থাকা ফলাফলের বার্তা দেখানো হয়।',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _field(_dimensions, 'বিষয়সমূহ (key, label_bn)'),
          _field(_rules, 'নিয়ম (when, flags)'),
          _field(_outcomes, 'ফলাফল (flags, message_bn, needs_ruqyah)'),
          FilledButton.icon(
            onPressed: widget.saving
                ? null
                : () {
                    final dimensions = _parse(_dimensions);
                    final rules = _parse(_rules);
                    final outcomes = _parse(_outcomes);
                    if (dimensions == null ||
                        rules == null ||
                        outcomes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'JSON সঠিক নয়। প্রতিটি ঘর একটি তালিকা ([...]) হতে হবে।',
                          ),
                        ),
                      );
                      return;
                    }
                    widget.onSave({
                      'dimensions': dimensions,
                      'rules': rules,
                      'outcomes': outcomes,
                    });
                  },
            icon: const Icon(Icons.save_outlined),
            label: const Text('নিয়ম সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }
}

class _QuestionDraft {
  const _QuestionDraft(this.sortOrder, this.questionBn, this.options);

  final int sortOrder;
  final String questionBn;
  final List<SelfAssessmentOption> options;
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({
    required this.test,
    required this.question,
    required this.nextSortOrder,
  });

  final SelfAssessmentTest test;
  final SelfAssessmentQuestion? question;
  final int nextSortOrder;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final _text = TextEditingController(
    text: widget.question?.questionBn ?? '',
  );
  late final _order = TextEditingController(
    text: '${widget.question?.sortOrder ?? widget.nextSortOrder}',
  );
  late final List<SelfAssessmentOption> _options = [
    ...?widget.question?.options,
  ];
  final _labels = <TextEditingController>[];
  final _scores = <Map<String, TextEditingController>>[];

  List<String> get _keys => widget.test.scoresByDimension
      ? widget.test.dimensions.map((dimension) => dimension.key).toList()
      : const ['score'];

  @override
  void initState() {
    super.initState();
    if (_options.isEmpty) {
      final blank = widget.test.scoresByDimension
          ? {for (final key in _keys) key: 0}
          : const <String, int>{};
      _options.addAll([
        SelfAssessmentOption(label: 'হ্যাঁ', scores: blank),
        SelfAssessmentOption(label: 'মাঝে মধ্যে', scores: blank),
        SelfAssessmentOption(label: 'না', scores: blank),
      ]);
    }
    for (final option in _options) {
      _addControllers(option);
    }
  }

  void _addControllers(SelfAssessmentOption option) {
    _labels.add(TextEditingController(text: option.label));
    _scores.add({
      for (final key in _keys)
        key: TextEditingController(
          text: widget.test.scoresByDimension
              ? '${option.scores[key] ?? 0}'
              : '${option.score}',
        ),
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _order.dispose();
    for (final controller in _labels) {
      controller.dispose();
    }
    for (final map in _scores) {
      for (final controller in map.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    final options = <SelfAssessmentOption>[
      for (var i = 0; i < _labels.length; i++)
        if (_labels[i].text.trim().isNotEmpty)
          widget.test.scoresByDimension
              ? SelfAssessmentOption(
                  label: _labels[i].text.trim(),
                  scores: {
                    for (final key in _keys)
                      key: int.tryParse(_scores[i][key]!.text.trim()) ?? 0,
                  },
                )
              : SelfAssessmentOption(
                  label: _labels[i].text.trim(),
                  score: int.tryParse(_scores[i]['score']!.text.trim()) ?? 0,
                ),
    ];
    if (text.isEmpty || options.length < 2 || options.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('প্রশ্ন লিখুন এবং ২ থেকে ৬টি উত্তর দিন।')),
      );
      return;
    }
    Navigator.pop(
      context,
      _QuestionDraft(int.tryParse(_order.text.trim()) ?? 0, text, options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = {
      for (final dimension in widget.test.dimensions)
        dimension.key: dimension.labelBn,
      'score': 'স্কোর',
    };
    return AlertDialog(
      title: Text(widget.question == null ? 'নতুন প্রশ্ন' : 'প্রশ্ন সম্পাদনা'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('admin-self-question-text'),
                controller: _text,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'প্রশ্ন'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'ক্রম'),
              ),
              const SizedBox(height: 14),
              Text(
                'উত্তর ও স্কোর (শেষ উত্তরটি "না" হিসেবে ধরা হয়)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (var i = 0; i < _labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _labels[i],
                          decoration: InputDecoration(
                            labelText: 'উত্তর ${i + 1}',
                          ),
                        ),
                      ),
                      for (final key in _keys)
                        SizedBox(
                          width: 84,
                          child: TextField(
                            controller: _scores[i][key],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: labels[key] ?? key,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'উত্তর মুছুন',
                        onPressed: _labels.length <= 2
                            ? null
                            : () => setState(() {
                                _labels.removeAt(i).dispose();
                                for (final controller
                                    in _scores.removeAt(i).values) {
                                  controller.dispose();
                                }
                              }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              if (_labels.length < 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _addControllers(
                        const SelfAssessmentOption(label: ''),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('উত্তর যোগ করুন'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        FilledButton(
          key: const Key('admin-self-question-save'),
          onPressed: _save,
          child: const Text('সংরক্ষণ করুন'),
        ),
      ],
    );
  }
}

class _BandDraft {
  const _BandDraft(this.minScore, this.messageBn, this.needsRuqyah);

  final int minScore;
  final String messageBn;
  final bool needsRuqyah;
}

class _BandDialog extends StatefulWidget {
  const _BandDialog({required this.band});

  final SelfAssessmentBand? band;

  @override
  State<_BandDialog> createState() => _BandDialogState();
}

class _BandDialogState extends State<_BandDialog> {
  late final _min = TextEditingController(
    text: '${widget.band?.minScore ?? 0}',
  );
  late final _message = TextEditingController(
    text: widget.band?.messageBn ?? '',
  );
  late bool _needs = widget.band?.needsRuqyah ?? false;

  @override
  void dispose() {
    _min.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.band == null ? 'নতুন স্তর' : 'স্তর সম্পাদনা'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _min,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'সর্বনিম্ন স্কোর'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'ফলাফলের বার্তা'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('রুকইয়াহর পরামর্শ দিন'),
            value: _needs,
            onChanged: (value) => setState(() => _needs = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('বাতিল'),
      ),
      FilledButton(
        onPressed: () {
          final message = _message.text.trim();
          if (message.isEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('বার্তা লিখুন।')));
            return;
          }
          Navigator.pop(
            context,
            _BandDraft(int.tryParse(_min.text.trim()) ?? 0, message, _needs),
          );
        },
        child: const Text('সংরক্ষণ করুন'),
      ),
    ],
  );
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('না'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('হ্যাঁ, মুছুন'),
          ),
        ],
      ),
    ) ==
    true;

void _showSaveError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।')),
  );
}
