import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:uuid/uuid.dart';

class PlanActionEditorScreen extends ConsumerStatefulWidget {
  const PlanActionEditorScreen({
    super.key,
    required this.planId,
    this.actionId,
  });

  final String planId;
  final String? actionId;

  @override
  ConsumerState<PlanActionEditorScreen> createState() =>
      _PlanActionEditorScreenState();
}

class _PlanActionEditorScreenState
    extends ConsumerState<PlanActionEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _titleController = TextEditingController();
  final _instructionController = TextEditingController();
  final _countController = TextEditingController();
  final _durationController = TextEditingController();
  final _dailyIntervalController = TextEditingController(text: '1');
  final _usageNoteController = TextEditingController();
  final _requestId = const Uuid().v4();

  late Future<_EditorData> _data;
  CarePlan? _plan;
  ActionFrequencyType _frequencyType = ActionFrequencyType.daily;
  Set<int> _weekdays = {1};
  String _timeWindow = '';
  DateTime? _exactTime;
  late DateTime _startDate;
  DateTime? _endDate;
  ActionReviewStatus _reviewStatus = ActionReviewStatus.draft;
  bool _reminderEnabled = false;
  String _contentItemId = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(DateTime.now());
    _data = _load();
  }

  Future<_EditorData> _load() async {
    final repository = ref.read(carePlansRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.getPlan(widget.planId),
      repository.getActions(widget.planId),
      repository.getAvailableResources(),
    ]);
    final plan = results[0] as CarePlan?;
    if (plan == null) {
      throw const CarePlanWorkflowException('Care plan was not found.');
    }
    final actions = results[1] as List<PlanAction>;
    final resources = results[2] as List<ContentResourceOption>;
    final action = widget.actionId == null
        ? null
        : actions.where((item) => item.id == widget.actionId).firstOrNull;
    if (widget.actionId != null && action == null) {
      throw const CarePlanWorkflowException('Plan action was not found.');
    }
    _plan = plan;
    _startDate = action?.startDate ?? plan.startDate;
    _endDate = action?.endDate ?? plan.endDate;
    if (action != null) _populate(action);
    return _EditorData(plan: plan, action: action, resources: resources);
  }

  void _populate(PlanAction action) {
    _typeController.text = action.type;
    _titleController.text = action.title;
    _instructionController.text = action.instruction ?? '';
    _countController.text = action.countTarget?.toString() ?? '';
    _durationController.text = action.durationMinutes?.toString() ?? '';
    _frequencyType = action.frequency.type;
    _dailyIntervalController.text = action.frequency.interval.toString();
    _weekdays = {...action.frequency.weekdays};
    _timeWindow = action.timeWindow ?? '';
    _exactTime = action.exactTime;
    _reviewStatus = action.reviewStatus;
    _reminderEnabled = action.reminderEnabled;
    _contentItemId = action.resource?.id ?? '';
    _usageNoteController.text = action.resource?.usageNote ?? '';
  }

  @override
  void dispose() {
    _typeController.dispose();
    _titleController.dispose();
    _instructionController.dispose();
    _countController.dispose();
    _durationController.dispose();
    _dailyIntervalController.dispose();
    _usageNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final plan = _plan!;
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : (_endDate ?? _startDate),
      firstDate: plan.startDate,
      lastDate: plan.endDate ?? DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate?.isBefore(selected) == true) _endDate = null;
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _pickTime() async {
    final initial = _exactTime == null
        ? TimeOfDay.now()
        : TimeOfDay.fromDateTime(_exactTime!);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null) return;
    setState(() {
      _exactTime = DateTime(2000, 1, 1, selected.hour, selected.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    if (_frequencyType == ActionFrequencyType.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one weekday.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final frequency = _frequencyType == ActionFrequencyType.daily
          ? ActionFrequency.daily(
              interval: int.parse(_dailyIntervalController.text.trim()),
            )
          : ActionFrequency.weekly(_weekdays);
      await ref
          .read(carePlansRepositoryProvider)
          .saveAction(
            SavePlanActionInput(
              carePlanId: widget.planId,
              actionId: widget.actionId,
              type: _typeController.text,
              title: _titleController.text,
              instruction: _instructionController.text,
              countTarget: int.tryParse(_countController.text.trim()),
              durationMinutes: int.tryParse(_durationController.text.trim()),
              frequency: frequency,
              timeWindow: _timeWindow.isEmpty ? null : _timeWindow,
              exactTime: _exactTime,
              startDate: _startDate,
              endDate: _endDate,
              reviewStatus: _reviewStatus,
              reminderEnabled: _reminderEnabled,
              contentItemId: _contentItemId.isEmpty ? null : _contentItemId,
              resourceUsageNote: _usageNoteController.text,
              requestId: _requestId,
            ),
          );
      if (mounted) context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('করণীয়টি সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.actionId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit action' : 'Add action')),
      body: FutureBuilder<_EditorData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading action editor');
          }
          if (snapshot.hasError) {
            return AppErrorState(message: 'করণীয়টি আনা যাচ্ছে না। আবার চেষ্টা করুন।');
          }
          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SukunPageIntro(
                        eyebrow: editing ? 'Structured action' : 'New action',
                        title: editing ? 'Edit plan action' : 'Add plan action',
                        subtitle: 'Capture only what the practitioner explicitly provided.',
                      ),
                      const SizedBox(height: 18),
                      const SukunSurface(
                        tone: SukunSurfaceTone.warning,
                        showBorder: false,
                        radius: 18,
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.fact_check_outlined),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Leave unknown count, duration, time, or resource fields blank and mark the action “Needs review”.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _typeController,
                        decoration: const InputDecoration(
                          labelText: 'Action type',
                          hintText: 'For example: recitation or listening',
                        ),
                        validator: (value) =>
                            validateActionRequired(value, 'Action type'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) =>
                            validateActionRequired(value, 'Title'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _instructionController,
                        minLines: 3,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: 'Instruction (optional)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _countController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Count (optional)',
                              ),
                              validator: (value) =>
                                  validateOptionalPositiveInteger(
                                    value,
                                    'Count',
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minutes (optional)',
                              ),
                              validator: (value) =>
                                  validateOptionalPositiveInteger(
                                    value,
                                    'Duration',
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Frequency',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<ActionFrequencyType>(
                        segments: const [
                          ButtonSegment(
                            value: ActionFrequencyType.daily,
                            label: Text('Daily'),
                          ),
                          ButtonSegment(
                            value: ActionFrequencyType.weekly,
                            label: Text('Selected days'),
                          ),
                        ],
                        selected: {_frequencyType},
                        onSelectionChanged: (value) =>
                            setState(() => _frequencyType = value.single),
                      ),
                      if (_frequencyType == ActionFrequencyType.daily) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('daily-interval-field'),
                          controller: _dailyIntervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'কত দিন পরপর করবেন?',
                            helperText: '১ = প্রতিদিন, ২ = এক দিন পরপর',
                          ),
                          validator: (value) {
                            final interval = int.tryParse(value?.trim() ?? '');
                            if (interval == null || interval < 1) {
                              return '১ বা তার বেশি একটি সংখ্যা লিখুন।';
                            }
                            return null;
                          },
                        ),
                      ],
                      if (_frequencyType == ActionFrequencyType.weekly) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var day = 1; day <= 7; day++)
                              FilterChip(
                                label: Text(_weekdayName(day)),
                                selected: _weekdays.contains(day),
                                onSelected: (selected) => setState(() {
                                  selected
                                      ? _weekdays.add(day)
                                      : _weekdays.remove(day);
                                }),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      SukunChoiceField<String>(
                        label: 'Time window',
                        placeholder: 'Not specified',
                        value: _timeWindow,
                        options: const [
                          SukunChoiceOption(
                            value: '',
                            title: 'Not specified',
                            description:
                                'Keep time flexible and do not infer one.',
                          ),
                          SukunChoiceOption(value: 'morning', title: 'Morning'),
                          SukunChoiceOption(
                            value: 'afternoon',
                            title: 'Afternoon',
                          ),
                          SukunChoiceOption(value: 'evening', title: 'Evening'),
                          SukunChoiceOption(value: 'night', title: 'Night'),
                          SukunChoiceOption(value: 'anytime', title: 'Anytime'),
                        ],
                        onChanged: (value) =>
                            setState(() => _timeWindow = value),
                      ),
                      const SizedBox(height: 10),
                      SukunSurface(
                        radius: 20,
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.schedule_outlined),
                          title: const Text('Exact time'),
                          subtitle: Text(
                            _exactTime == null
                                ? 'Not specified'
                                : TimeOfDay.fromDateTime(_exactTime!)
                                      .format(context),
                          ),
                          trailing: _exactTime == null
                              ? const Icon(Icons.chevron_right)
                              : IconButton(
                                  onPressed: () =>
                                      setState(() => _exactTime = null),
                                  tooltip: 'Clear exact time',
                                  icon: const Icon(Icons.close),
                                ),
                          onTap: _pickTime,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ActionDateTile(
                        label: 'Action start',
                        date: _startDate,
                        onTap: () => _pickDate(start: true),
                      ),
                      const SizedBox(height: 10),
                      _ActionDateTile(
                        label: 'Action end',
                        date: _endDate,
                        onTap: () => _pickDate(start: false),
                        onClear: _endDate == null
                            ? null
                            : () => setState(() => _endDate = null),
                      ),
                      const SizedBox(height: 22),
                      SukunChoiceField<ActionReviewStatus>(
                        label: 'Review status',
                        placeholder: 'Choose review status',
                        value: _reviewStatus,
                        options: [
                          for (final status in const [
                            ActionReviewStatus.draft,
                            ActionReviewStatus.needsReview,
                            ActionReviewStatus.approved,
                          ])
                            SukunChoiceOption(
                              value: status,
                              title: status.label,
                              description: switch (status) {
                                ActionReviewStatus.draft =>
                                  'Still being prepared.',
                                ActionReviewStatus.needsReview =>
                                  'Contains missing or ambiguous information.',
                                ActionReviewStatus.approved =>
                                  'Reviewed and eligible for plan publication.',
                                _ => 'Not available for this workflow.',
                              },
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _reviewStatus = value),
                      ),
                      const SizedBox(height: 14),
                      SukunChoiceField<String>(
                        label: 'Linked resource',
                        placeholder: 'No linked resource',
                        value: _contentItemId,
                        options: [
                          const SukunChoiceOption(
                            value: '',
                            title: 'No linked resource',
                            description: 'Keep this action instruction-only.',
                          ),
                          for (final resource in data.resources)
                            SukunChoiceOption(
                              value: resource.id,
                              title: resource.title,
                              description: 'Reuse this canonical resource without copying it.',
                              icon: Icons.menu_book_outlined,
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _contentItemId = value),
                      ),
                      if (_contentItemId.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _usageNoteController,
                          decoration: const InputDecoration(
                            labelText: 'Resource usage note (optional)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _reminderEnabled,
                        onChanged: (value) =>
                            setState(() => _reminderEnabled = value),
                        title: const Text('Reminder enabled'),
                        subtitle: const Text(
                          'Scheduling is configured later; this does not invent a reminder time.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_submitting ? 'Saving…' : 'Save action'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditorData {
  const _EditorData({
    required this.plan,
    required this.action,
    required this.resources,
  });

  final CarePlan plan;
  final PlanAction? action;
  final List<ContentResourceOption> resources;
}

class _ActionDateTile extends StatelessWidget {
  const _ActionDateTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      radius: 20,
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: Text(label),
        subtitle: Text(date == null ? 'No end date' : _formatDate(date!)),
        trailing: onClear == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                onPressed: onClear,
                tooltip: 'Clear date',
                icon: const Icon(Icons.close),
              ),
        onTap: onTap,
      ),
    );
  }
}

String _weekdayName(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
