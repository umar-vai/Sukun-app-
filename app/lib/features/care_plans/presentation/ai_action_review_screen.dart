import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/ai_actions_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/resource_matcher.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:uuid/uuid.dart';

class AiActionReviewScreen extends ConsumerStatefulWidget {
  const AiActionReviewScreen({
    super.key,
    required this.patientId,
    required this.planId,
    required this.prescriptionId,
    this.initialSeed,
  });

  final String patientId;
  final String planId;
  final String prescriptionId;
  final AiActionReviewSeed? initialSeed;

  @override
  ConsumerState<AiActionReviewScreen> createState() =>
      _AiActionReviewScreenState();
}

class _AiActionReviewScreenState extends ConsumerState<AiActionReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _generationRequestId;
  late Future<_ReviewData> _data;
  late AiActionReviewSeed? _reviewSeed;
  List<_EditableSuggestion>? _drafts;
  bool _importing = false;
  bool _forceFreshGeneration = false;
  _ReviewFilter _reviewFilter = _ReviewFilter.all;

  @override
  void initState() {
    super.initState();
    _reviewSeed = widget.initialSeed;
    _generationRequestId = _reviewSeed?.result.requestId ?? const Uuid().v4();
    _data = _load();
  }

  Future<_ReviewData> _load() async {
    final carePlans = ref.read(carePlansRepositoryProvider);
    final results = await Future.wait<Object?>([
      carePlans.getPlan(widget.planId),
      carePlans.getAvailableResources(),
      ref.read(patientsRepositoryProvider).getPrescriptions(widget.patientId),
      _resolveGeneration(),
    ]);
    final plan = results[0] as CarePlan?;
    if (plan == null ||
        plan.patientId != widget.patientId ||
        plan.prescriptionId != widget.prescriptionId ||
        !plan.isEditable) {
      throw const CarePlanWorkflowException(
        'Use a draft care plan linked to this prescription.',
      );
    }
    final prescriptions = results[2] as List<Prescription>;
    final prescription = prescriptions
        .where((item) => item.id == widget.prescriptionId)
        .firstOrNull;
    if (prescription == null) {
      throw const CarePlanWorkflowException(
        'The source prescription could not be found.',
      );
    }
    final result = results[3] as AiActionGenerationResult;
    final resources = results[1] as List<ContentResourceOption>;
    _drafts ??= result.actions
        .map(
          (suggestion) => _EditableSuggestion.fromSuggestion(
            suggestion,
            resourceMatches: matchResources(
              suggestion.resourceMatchQuery,
              resources,
            ),
          ),
        )
        .toList(growable: false);
    return _ReviewData(
      plan: plan,
      prescription: prescription,
      result: result,
      resources: resources,
    );
  }

  Future<AiActionGenerationResult> _resolveGeneration() async {
    final seed = _reviewSeed;
    if (seed != null && !_forceFreshGeneration) {
      return seed.result;
    }

    final repository = ref.read(aiActionsRepositoryProvider);
    if (!_forceFreshGeneration) {
      final stored = await repository.loadStoredActions(
        prescriptionId: widget.prescriptionId,
        carePlanId: widget.planId,
      );
      if (stored != null) {
        _reviewSeed = stored;
        _generationRequestId = stored.result.requestId;
        return stored.result;
      }
    }

    _forceFreshGeneration = false;
    return repository.generateActions(
      prescriptionId: widget.prescriptionId,
      carePlanId: widget.planId,
      requestId: _generationRequestId,
    );
  }

  void _retry() {
    setState(() {
      _data = _load();
    });
  }

  void _startNewGeneration() {
    setState(() {
      _reviewSeed = null;
      _generationRequestId = const Uuid().v4();
      _drafts = null;
      _forceFreshGeneration = true;
      _data = _load();
    });
  }

  Future<void> _openManualBuilder() async {
    final changed = await context.push<bool>(
      '/admin/patients/${widget.patientId}/plans/${widget.planId}/actions/new',
    );
    if (mounted && changed == true) context.pop(true);
  }

  Future<void> _import(_ReviewData data) async {
    if (_importing || !_formKey.currentState!.validate()) return;
    final selected = _drafts!
        .where((draft) => draft.selected && !draft.imported)
        .toList(growable: false);
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one action to import.')),
      );
      return;
    }
    final invalidWeekly = selected.any(
      (draft) =>
          draft.frequencyType == ActionFrequencyType.weekly &&
          draft.weekdays.isEmpty,
    );
    if (invalidWeekly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one weekday.')),
      );
      return;
    }

    setState(() => _importing = true);
    var imported = 0;
    try {
      final repository = ref.read(carePlansRepositoryProvider);
      for (final draft in selected) {
        await repository.saveAction(
          SavePlanActionInput(
            carePlanId: widget.planId,
            type: draft.type.trim(),
            title: draft.title.trim(),
            instruction: draft.instruction.trim(),
            countTarget: int.tryParse(draft.count.trim()),
            durationMinutes: int.tryParse(draft.duration.trim()),
            frequency: draft.frequencyType == ActionFrequencyType.daily
                ? ActionFrequency.daily(
                    interval: int.parse(draft.dailyInterval.trim()),
                  )
                : ActionFrequency.weekly(draft.weekdays),
            timeWindow: draft.timeWindow.isEmpty ? null : draft.timeWindow,
            exactTime: draft.exactTime,
            startDate: data.plan.startDate,
            endDate: data.plan.endDate,
            reviewStatus: importedReviewStatus(draft.source),
            reminderEnabled: false,
            contentItemId: draft.contentItemId.isEmpty
                ? null
                : draft.contentItemId,
            requestId: draft.importRequestId,
            aiRequestId: data.result.requestId,
            attachmentId: _reviewSeed?.attachmentId,
            sourceEvidence: draft.source.sourceEvidence,
            aiConfidence: draft.source.confidence,
            aiAmbiguities: draft.source.ambiguities,
            humanEdited: draft.wasEdited,
          ),
        );
        draft.imported = true;
        draft.selected = false;
        imported += 1;
        if (mounted) setState(() {});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$imported suggested action${imported == 1 ? '' : 's'} imported as unapproved draft work.',
          ),
        ),
      );
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imported == 0
                ? 'The selected actions could not be imported. Your suggestions are still here; please retry.'
                : '$imported action${imported == 1 ? '' : 's'} imported. The remaining suggestions are still here; retry to continue.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review suggested actions')),
      body: FutureBuilder<_ReviewData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              label: 'Preparing draft action suggestions',
            );
          }
          if (snapshot.hasError) {
            return _GenerationUnavailable(
              message: _safeError(snapshot.error),
              onRetry: _retry,
              onManual: _openManualBuilder,
            );
          }
          final data = snapshot.data!;
          if (data.result.requiresManualBuilder) {
            return _GenerationUnavailable(
              message: aiManualFallbackMessage,
              onRetry: _startNewGeneration,
              onManual: _openManualBuilder,
            );
          }
          final selectedCount = _drafts!
              .where((draft) => draft.selected && !draft.imported)
              .length;
          final readyCount = _drafts!
              .where((draft) => draft.isReady && !draft.imported)
              .length;
          final reviewCount = _drafts!
              .where((draft) => !draft.isReady && !draft.imported)
              .length;
          final visibleDrafts = <({int index, _EditableSuggestion draft})>[
            for (var index = 0; index < _drafts!.length; index++)
              if (_reviewFilter.matches(_drafts![index]))
                (index: index, draft: _drafts![index]),
          ];
          return Form(
            key: _formKey,
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
                  children: [
                    const SukunPageIntro(
                      eyebrow: 'AI-assisted parsing',
                      title: 'Review suggested actions',
                      subtitle: 'Compare every field with the human-authored prescription before importing it as draft work.',
                    ),
                    const SizedBox(height: 20),
                    const _SafetyNotice(),
                    const SizedBox(height: 16),
                    _SourcePrescription(prescription: data.prescription),
                    const SizedBox(height: 16),
                    _ReviewSummary(
                      totalCount: _drafts!.length,
                      readyCount: readyCount,
                      reviewCount: reviewCount,
                      selectedCount: selectedCount,
                      filter: _reviewFilter,
                      enabled: !_importing,
                      onFilterChanged: (filter) =>
                          setState(() => _reviewFilter = filter),
                      onSelectionAction: () => setState(() {
                        if (selectedCount > 0) {
                          for (final draft in _drafts!) {
                            if (!draft.imported) draft.selected = false;
                          }
                          return;
                        }
                        for (final draft in _drafts!) {
                          if (!draft.imported && draft.isReady) {
                            draft.selected = true;
                          }
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (visibleDrafts.isEmpty)
                      const _NoSuggestionsForFilter()
                    else
                      for (final entry in visibleDrafts) ...[
                        _SuggestedActionCard(
                          number: entry.index + 1,
                          draft: entry.draft,
                          resources: data.resources,
                          enabled: !_importing,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _importing ? null : _openManualBuilder,
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Use Manual Action Builder'),
                    ),
                  ],
                ),
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: SafeArea(
                      top: false,
                      child: _ImportDock(
                        selectedCount: selectedCount,
                        importing: _importing,
                        onImport: selectedCount == 0 || _importing
                            ? null
                            : () => _import(data),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _ReviewFilter { all, ready, needsReview }

extension on _ReviewFilter {
  bool matches(_EditableSuggestion draft) => switch (this) {
    _ReviewFilter.all => true,
    _ReviewFilter.ready => draft.isReady,
    _ReviewFilter.needsReview => !draft.isReady,
  };
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.totalCount,
    required this.readyCount,
    required this.reviewCount,
    required this.selectedCount,
    required this.filter,
    required this.enabled,
    required this.onFilterChanged,
    required this.onSelectionAction,
  });

  final int totalCount;
  final int readyCount;
  final int reviewCount;
  final int selectedCount;
  final _ReviewFilter filter;
  final bool enabled;
  final ValueChanged<_ReviewFilter> onFilterChanged;
  final VoidCallback onSelectionAction;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      tone: SukunSurfaceTone.soft,
      showBorder: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$totalCount suggestions',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: enabled ? onSelectionAction : null,
                child: Text(
                  selectedCount > 0 ? 'Clear selection' : 'Select ready',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$readyCount ready · $reviewCount need review',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: SukunColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReviewFilterChip(
                label: 'All',
                count: totalCount,
                selected: filter == _ReviewFilter.all,
                onTap: () => onFilterChanged(_ReviewFilter.all),
              ),
              _ReviewFilterChip(
                label: 'Ready',
                count: readyCount,
                selected: filter == _ReviewFilter.ready,
                onTap: () => onFilterChanged(_ReviewFilter.ready),
              ),
              _ReviewFilterChip(
                label: 'Needs review',
                count: reviewCount,
                selected: filter == _ReviewFilter.needsReview,
                onTap: () => onFilterChanged(_ReviewFilter.needsReview),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewFilterChip extends StatelessWidget {
  const _ReviewFilterChip({
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
  Widget build(BuildContext context) => ChoiceChip(
    selected: selected,
    onSelected: (_) => onTap(),
    label: Text('$label · $count'),
  );
}

class _NoSuggestionsForFilter extends StatelessWidget {
  const _NoSuggestionsForFilter();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Text(
        'No suggestions in this filter.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: SukunColors.muted),
      ),
    ),
  );
}

class _ImportDock extends StatelessWidget {
  const _ImportDock({
    required this.selectedCount,
    required this.importing,
    required this.onImport,
  });

  final int selectedCount;
  final bool importing;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SukunColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedCount == 0
                          ? 'No actions selected'
                          : '$selectedCount selected',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Imported items stay as draft work.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: SukunColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onImport,
              icon: importing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_check_rounded),
              label: Text(importing ? 'Importing…' : 'Import'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewData {
  const _ReviewData({
    required this.plan,
    required this.prescription,
    required this.result,
    required this.resources,
  });

  final CarePlan plan;
  final Prescription prescription;
  final AiActionGenerationResult result;
  final List<ContentResourceOption> resources;
}

class _EditableSuggestion {
  _EditableSuggestion({
    required this.source,
    required this.type,
    required this.title,
    required this.instruction,
    required this.count,
    required this.duration,
    required this.frequencyType,
    required this.dailyInterval,
    required this.weekdays,
    required this.timeWindow,
    required this.exactTime,
    required this.resourceMatches,
  });

  factory _EditableSuggestion.fromSuggestion(
    SuggestedPlanAction source, {
    required List<ResourceMatch> resourceMatches,
  }) {
    final draft = _EditableSuggestion(
      source: source,
      type: source.type,
      title: source.title,
      instruction: source.instruction ?? '',
      count: source.countTarget?.toString() ?? '',
      duration: source.durationMinutes?.toString() ?? '',
      frequencyType: source.frequency?.type,
      dailyInterval: source.frequency?.interval.toString() ?? '1',
      weekdays: {...?source.frequency?.weekdays},
      timeWindow: source.timeWindow ?? '',
      exactTime: source.exactTime,
      resourceMatches: resourceMatches,
    );
    draft.selected = draft.isReady;
    return draft;
  }

  final SuggestedPlanAction source;
  final String importRequestId = const Uuid().v4();
  final List<ResourceMatch> resourceMatches;
  String type;
  String title;
  String instruction;
  String count;
  String duration;
  ActionFrequencyType? frequencyType;
  String dailyInterval;
  Set<int> weekdays;
  String timeWindow;
  DateTime? exactTime;
  String contentItemId = '';
  bool selected = false;
  bool imported = false;

  bool get hasIncompleteMetadata => source.ambiguities.any(
    (item) => item.startsWith('AI omitted metadata fields:'),
  );

  bool get isReady =>
      !source.needsReview && !hasIncompleteMetadata && source.confidence >= 0.8;

  bool get wasEdited {
    if (type.trim() != source.type ||
        title.trim() != source.title ||
        instruction.trim() != (source.instruction ?? '') ||
        int.tryParse(count.trim()) != source.countTarget ||
        int.tryParse(duration.trim()) != source.durationMinutes ||
        timeWindow != (source.timeWindow ?? '') ||
        contentItemId.isNotEmpty) {
      return true;
    }
    final sourceFrequency = source.frequency;
    if (sourceFrequency?.type != frequencyType) return true;
    if (frequencyType == ActionFrequencyType.daily &&
        int.tryParse(dailyInterval.trim()) != sourceFrequency?.interval) {
      return true;
    }
    if (frequencyType == ActionFrequencyType.weekly &&
        weekdays
            .difference(sourceFrequency?.weekdays ?? const <int>{})
            .isNotEmpty) {
      return true;
    }
    if (frequencyType == ActionFrequencyType.weekly &&
        (sourceFrequency?.weekdays ?? const <int>{})
            .difference(weekdays)
            .isNotEmpty) {
      return true;
    }
    final sourceTime = source.exactTime;
    if (sourceTime == null) return exactTime != null;
    return exactTime == null ||
        sourceTime.hour != exactTime!.hour ||
        sourceTime.minute != exactTime!.minute;
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return const SukunSurface(
      tone: SukunSurfaceTone.warning,
      showBorder: false,
      radius: 18,
      padding: EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: SukunColors.deepTide),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'These are parser suggestions, not medical or religious decisions. Check every field against the original prescription. Imported actions stay unapproved until you explicitly approve them in the plan builder.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedActionCard extends StatelessWidget {
  const _SuggestedActionCard({
    required this.number,
    required this.draft,
    required this.resources,
    required this.enabled,
    required this.onChanged,
  });

  final int number;
  final _EditableSuggestion draft;
  final List<ContentResourceOption> resources;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: number == 1,
        leading: Checkbox(
          value: draft.selected,
          onChanged: !enabled || draft.imported
              ? null
              : (value) {
                  draft.selected = value ?? false;
                  onChanged();
                },
        ),
        title: Text(draft.title.isEmpty ? 'Suggestion $number' : draft.title),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              draft.hasIncompleteMetadata
                  ? 'Metadata incomplete'
                  : '${(draft.source.confidence * 100).round()}% confidence',
              style: draft.hasIncompleteMetadata
                  ? const TextStyle(color: SukunColors.deepTide)
                  : null,
            ),
            if (draft.source.needsReview)
              const Text(
                'Needs review',
                style: TextStyle(color: SukunColors.deepTide),
              ),
            if (draft.imported) const Text('Imported'),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [
          if (draft.source.sourceEvidence != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SukunColors.mist,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Source evidence: “${draft.source.sourceEvidence}”'),
            ),
          ],
          if (draft.source.ambiguities.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SukunColors.warningSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Check these ambiguities:'),
                  for (final ambiguity in draft.source.ambiguities)
                    Text('• $ambiguity'),
                ],
              ),
            ),
          TextFormField(
            initialValue: draft.type,
            enabled: enabled && !draft.imported,
            decoration: const InputDecoration(labelText: 'Action type'),
            onChanged: (value) => draft.type = value,
            validator: (value) => !draft.selected || draft.imported
                ? null
                : validateActionRequired(value, 'Action type'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: draft.title,
            enabled: enabled && !draft.imported,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: (value) {
              draft.title = value;
              onChanged();
            },
            validator: (value) => !draft.selected || draft.imported
                ? null
                : validateActionRequired(value, 'Title'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: draft.instruction,
            enabled: enabled && !draft.imported,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Instruction (optional)',
              alignLabelWithHint: true,
            ),
            onChanged: (value) => draft.instruction = value,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: draft.count,
                  enabled: enabled && !draft.imported,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Count (optional)',
                  ),
                  onChanged: (value) => draft.count = value,
                  validator: (value) => !draft.selected || draft.imported
                      ? null
                      : validateOptionalPositiveInteger(value, 'Count'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: draft.duration,
                  enabled: enabled && !draft.imported,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes (optional)',
                  ),
                  onChanged: (value) => draft.duration = value,
                  validator: (value) => !draft.selected || draft.imported
                      ? null
                      : validateOptionalPositiveInteger(value, 'Duration'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormField<ActionFrequencyType>(
            initialValue: draft.frequencyType,
            validator: (value) =>
                draft.selected && !draft.imported && value == null
                ? 'Choose the frequency from the prescription.'
                : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SukunChoiceField<ActionFrequencyType>(
                  label: 'Frequency',
                  placeholder: 'Choose an approved recurrence',
                  value: field.value,
                  enabled: enabled && !draft.imported,
                  options: const [
                    SukunChoiceOption(
                      value: ActionFrequencyType.daily,
                      title: 'Daily',
                      description: 'Repeat every approved N-day interval.',
                      icon: Icons.today_outlined,
                    ),
                    SukunChoiceOption(
                      value: ActionFrequencyType.weekly,
                      title: 'Selected days',
                      description:
                          'Repeat only on explicitly approved weekdays.',
                      icon: Icons.date_range_outlined,
                    ),
                  ],
                  onChanged: (value) {
                    field.didChange(value);
                    draft.frequencyType = value;
                    onChanged();
                  },
                ),
                if (field.errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    field.errorText!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          if (draft.frequencyType == ActionFrequencyType.daily) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.dailyInterval,
              enabled: enabled && !draft.imported,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Every N days'),
              onChanged: (value) => draft.dailyInterval = value,
              validator: (value) => !draft.selected || draft.imported
                  ? null
                  : validateOptionalPositiveInteger(value, 'Daily interval') ??
                        ((value?.trim().isEmpty ?? true)
                            ? 'Daily interval is required.'
                            : null),
            ),
          ],
          if (draft.frequencyType == ActionFrequencyType.weekly) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_weekdayName(day)),
                    selected: draft.weekdays.contains(day),
                    onSelected: !enabled || draft.imported
                        ? null
                        : (selected) {
                            selected
                                ? draft.weekdays.add(day)
                                : draft.weekdays.remove(day);
                            onChanged();
                          },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SukunChoiceField<String>(
            label: 'Time window (optional)',
            placeholder: 'Choose only if the prescription specifies one',
            value: draft.timeWindow,
            enabled: enabled && !draft.imported,
            options: const [
              SukunChoiceOption(
                value: '',
                title: 'Not specified',
                description: 'Do not infer a time window.',
              ),
              SukunChoiceOption(
                value: 'morning',
                title: 'Morning',
                icon: Icons.wb_sunny_outlined,
              ),
              SukunChoiceOption(
                value: 'afternoon',
                title: 'Afternoon',
                icon: Icons.light_mode_outlined,
              ),
              SukunChoiceOption(
                value: 'evening',
                title: 'Evening',
                icon: Icons.nights_stay_outlined,
              ),
              SukunChoiceOption(
                value: 'night',
                title: 'Night',
                icon: Icons.bedtime_outlined,
              ),
              SukunChoiceOption(
                value: 'anytime',
                title: 'Anytime',
                icon: Icons.schedule_outlined,
              ),
            ],
            onChanged: (value) {
              draft.timeWindow = value;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Exact time'),
            subtitle: Text(
              draft.exactTime == null
                  ? 'Not specified'
                  : TimeOfDay.fromDateTime(draft.exactTime!).format(context),
            ),
            trailing: draft.exactTime == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    onPressed: !enabled || draft.imported
                        ? null
                        : () {
                            draft.exactTime = null;
                            onChanged();
                          },
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear exact time',
                  ),
            onTap: !enabled || draft.imported
                ? null
                : () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: draft.exactTime == null
                          ? TimeOfDay.now()
                          : TimeOfDay.fromDateTime(draft.exactTime!),
                    );
                    if (selected == null) return;
                    draft.exactTime = DateTime(
                      2000,
                      1,
                      1,
                      selected.hour,
                      selected.minute,
                    );
                    onChanged();
                  },
          ),
          if (draft.resourceMatches.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Possible resource matches',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final match in draft.resourceMatches)
                  ActionChip(
                    label: Text(match.resource.displayTitle),
                    onPressed: !enabled || draft.imported
                        ? null
                        : () {
                            draft.contentItemId = match.resource.id;
                            onChanged();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          ResourcePickerField(
            key: ValueKey(draft.contentItemId),
            resources: resources,
            selectedId: draft.contentItemId,
            enabled: enabled && !draft.imported,
            onChanged: (value) {
              draft.contentItemId = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _SourcePrescription extends StatelessWidget {
  const _SourcePrescription({required this.prescription});

  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      tone: SukunSurfaceTone.soft,
      showBorder: false,
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.description_outlined),
        title: const Text('Original prescription'),
        subtitle: const Text('Use this as the source of truth.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(prescription.rawText),
          ),
        ],
      ),
    );
  }
}

class _GenerationUnavailable extends StatelessWidget {
  const _GenerationUnavailable({
    required this.message,
    required this.onRetry,
    required this.onManual,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SukunSurface(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_note_outlined,
                  size: 48,
                  color: SukunColors.deepTide,
                ),
                const SizedBox(height: 16),
                Text(
                  'Continue with manual action entry',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.add),
                  label: const Text('Open Manual Action Builder'),
                ),
                TextButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _safeError(Object? error) {
  if (error is CarePlanWorkflowException) return error.message;
  return aiManualFallbackMessage;
}

String _weekdayName(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
