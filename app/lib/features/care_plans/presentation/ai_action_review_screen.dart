import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/ai_actions_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/care_plans/domain/stored_ai_suggestion_reconciler.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/resource_matcher.dart';
import 'package:sukun_life/features/care_plans/domain/review_resource_discovery.dart';
import 'package:sukun_life/features/care_plans/domain/resource_material_packet.dart';
import 'package:sukun_life/features/patient_care/domain/verified_quran_link_resolver.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
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
    this.returnToCaller = false,
  });

  /// True when the plan builder opened this screen and expects a result.
  final bool returnToCaller;
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
        'এই প্রেসক্রিপশনের সাথে যুক্ত খসড়া পরিকল্পনা ব্যবহার করুন।',
      );
    }
    final prescriptions = results[2] as List<Prescription>;
    final prescription = prescriptions
        .where((item) => item.id == widget.prescriptionId)
        .firstOrNull;
    if (prescription == null) {
      throw const CarePlanWorkflowException('মূল প্রেসক্রিপশনটি পাওয়া যায়নি।');
    }
    final result = reconcileStoredAiResult(
      results[3] as AiActionGenerationResult,
      prescriptionText: prescription.rawText,
    );
    final resources = results[1] as List<ContentResourceOption>;
    _drafts ??= result.actions
        .map(
          (suggestion) => _EditableSuggestion.fromSuggestion(
            suggestion,
            resourceDiscovery: discoverReviewResources(
              title: suggestion.title,
              instruction: suggestion.instruction,
              resourceMatchQuery: suggestion.resourceMatchQuery,
              resources: resources,
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
    if (!widget.returnToCaller) {
      // Straight to the plan builder, which opens a new action editor.
      context.pushReplacement(
        '/admin/patients/${widget.patientId}/plans/${widget.planId}?addAction=1',
      );
      return;
    }
    final changed = await context.push<bool>(
      '/admin/patients/${widget.patientId}/plans/${widget.planId}/actions/new',
    );
    if (mounted && changed == true) context.pop(true);
  }

  /// After import, continue to the plan builder to approve and publish.
  /// When the builder itself opened this screen, return to it instead so the
  /// same builder is not stacked twice.
  void _finishImport() {
    if (widget.returnToCaller) {
      context.pop(true);
    } else {
      context.pushReplacement(
        '/admin/patients/${widget.patientId}/plans/${widget.planId}',
      );
    }
  }

  Future<void> _previewMaterialDraft() async {
    final selected =
        _drafts
            ?.where((draft) => draft.selected && !draft.imported)
            .toList(growable: false) ??
        const <_EditableSuggestion>[];
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('উপকরণের খসড়া তৈরি করতে আগে কাজ নির্বাচন করুন।'),
        ),
      );
      return;
    }
    try {
      final library = ref.read(resourcesRepositoryProvider);
      final actions = <MaterialPacketAction>[];
      for (final draft in selected) {
        final resource = draft.contentItemId.isEmpty
            ? null
            : await library.getResource(draft.contentItemId);
        actions.add(
          MaterialPacketAction(
            title: draft.title,
            instruction: draft.instruction,
            countTarget: int.tryParse(draft.count.trim()),
            durationMinutes: int.tryParse(draft.duration.trim()),
            resource: resource,
          ),
        );
      }
      final markdown = ResourceMaterialPacket.draftMarkdown(actions);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('উপকরণের খসড়া (অ্যাডমিন যাচাই)'),
          content: SizedBox(
            width: 660,
            height: 440,
            child: SingleChildScrollView(child: SelectableText(markdown)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('বন্ধ করুন'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: markdown));
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('খসড়া কপি করুন'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'উপকরণের খসড়া এখন তৈরি করা যায়নি। '
            'Resource Library ও সংযোগ যাচাই করুন।',
          ),
        ),
      );
    }
  }

  Future<void> _applyWindowReminderTime(String window) async {
    if (_importing || _drafts == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: window == 'morning'
          ? 'সকালের আমলের রিমাইন্ডার সময়'
          : 'সন্ধ্যার আমলের রিমাইন্ডার সময়',
    );
    if (selected == null || !mounted) return;
    setState(() {
      for (final draft in _drafts!) {
        if (draft.imported || draft.timeWindow != window) continue;
        draft.exactTime = DateTime(2000, 1, 1, selected.hour, selected.minute);
        draft.reminderEnabled = true;
      }
    });
  }

  Future<void> _import(_ReviewData data) async {
    if (_importing) return;
    final selected = _drafts!
        .where((draft) => draft.selected && !draft.imported)
        .toList(growable: false);
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('যোগ করার জন্য অন্তত একটি করণীয় বাছুন।')),
      );
      return;
    }
    if (selected.any((draft) => !draft.canImport)) {
      setState(() => _reviewFilter = _ReviewFilter.needsReview);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'যোগ করার আগে বাছাই করা প্রতিটি করণীয়ের দরকারি ঘর পূরণ করুন।',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _importing = true);
    var imported = 0;
    try {
      final repository = ref.read(carePlansRepositoryProvider);
      for (final draft in selected) {
        final saved = await repository.saveAction(
          SavePlanActionInput(
            carePlanId: widget.planId,
            type: draft.type.trim(),
            title: draft.title.trim(),
            instruction: draft.instruction.trim(),
            countTarget: int.tryParse(draft.count.trim()),
            durationMinutes: int.tryParse(draft.duration.trim()),
            frequency: draft.importFrequency!,
            timeWindow: draft.timeWindow.isEmpty ? null : draft.timeWindow,
            exactTime: draft.exactTime,
            startDate: data.plan.startDate,
            endDate: data.plan.endDate,
            reviewStatus: importedReviewStatus(draft.source),
            reminderEnabled: draft.reminderEnabled && draft.exactTime != null,
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
        final cmsLinks =
            draft.contentItemIds
                .where((id) => !id.startsWith('quran:'))
                .toList()
              ..sort();
        if (cmsLinks.length > 1) {
          await repository.replaceActionResources(
            actionId: saved.id,
            resourceIds: cmsLinks,
            requestId: draft.resourceLinkRequestId,
          );
        }
        final surahs = [
          for (final id in draft.contentItemIds)
            if (id.startsWith('quran:'))
              ...data.resources.where((resource) => resource.id == id),
        ];
        if (surahs.isNotEmpty) {
          await repository.replaceActionQuranSurahs(
            actionId: saved.id,
            surahs: surahs,
            requestId: draft.quranLinkRequestId,
          );
        }
        draft.imported = true;
        draft.selected = false;
        imported += 1;
        if (mounted) setState(() {});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$importedটি প্রস্তাব অনুমোদনহীন খসড়া হিসেবে প্ল্যানে যোগ হয়েছে।',
          ),
        ),
      );
      _finishImport();
    } on CarePlanWorkflowException catch (error) {
      if (!mounted) return;
      final prefix = imported == 0
          ? 'বাছাই করা করণীয় যোগ করা যায়নি।'
          : '$importedটি করণীয় যোগ হয়েছে।';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$prefix ${error.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imported == 0
                ? 'বাছাই করা করণীয় যোগ করা যায়নি। আপনার প্রস্তাবগুলো এখানেই আছে।'
                : '$importedটি করণীয় যোগ হয়েছে। বাকি প্রস্তাবগুলো এখানেই আছে।',
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
      appBar: AppBar(title: const Text('প্রস্তাবিত করণীয় যাচাই')),
      body: FutureBuilder<_ReviewData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'প্রস্তাবিত করণীয় তৈরি হচ্ছে…');
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
                    const SukunStepper(current: 1),
                    const SizedBox(height: SukunSpace.page),
                    const _SafetyNotice(),
                    const SizedBox(height: SukunSpace.md),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _importing
                              ? null
                              : () => _applyWindowReminderTime('morning'),
                          icon: const Icon(Icons.wb_sunny_outlined),
                          label: const Text('সকালের রিমাইন্ডার সময় দিন'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _importing
                              ? null
                              : () => _applyWindowReminderTime('evening'),
                          icon: const Icon(Icons.nights_stay_outlined),
                          label: const Text('সন্ধ্যার রিমাইন্ডার সময় দিন'),
                        ),
                      ],
                    ),
                    const SizedBox(height: SukunSpace.md),
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
                      onPressed: _importing ? null : _previewMaterialDraft,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('প্রস্তুত উপকরণের খসড়া দেখুন'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _importing ? null : _openManualBuilder,
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('নিজে করণীয় তৈরি করুন'),
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
                  '$totalCountটি প্রস্তাব',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: enabled ? onSelectionAction : null,
                child: Text(
                  selectedCount > 0 ? 'বাছাই মুছুন' : 'প্রস্তুতগুলো বাছুন',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$readyCountটি প্রস্তুত · $reviewCountটি যাচাই দরকার',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: SukunColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReviewFilterChip(
                label: 'সব',
                count: totalCount,
                selected: filter == _ReviewFilter.all,
                onTap: () => onFilterChanged(_ReviewFilter.all),
              ),
              _ReviewFilterChip(
                label: 'প্রস্তুত',
                count: readyCount,
                selected: filter == _ReviewFilter.ready,
                onTap: () => onFilterChanged(_ReviewFilter.ready),
              ),
              _ReviewFilterChip(
                label: 'যাচাই দরকার',
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
        'এই তালিকায় কোনো প্রস্তাব নেই।',
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
                          ? 'কোনো করণীয় বাছাই করা হয়নি'
                          : '$selectedCountটি বাছাই করা',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'যোগ করা করণীয় খসড়া হিসেবেই থাকবে।',
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
              label: Text(importing ? 'যোগ হচ্ছে…' : 'প্ল্যানে যোগ করুন'),
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
    required this.resourceDiscovery,
  });

  factory _EditableSuggestion.fromSuggestion(
    SuggestedPlanAction source, {
    required ReviewResourceDiscovery resourceDiscovery,
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
      resourceDiscovery: resourceDiscovery,
    );
    // Only an exact, unambiguous, approved resource can be preselected.
    // The action still imports as unapproved and requires Admin review.
    if (!source.needsReview && !resourceDiscovery.requiresManualSelection) {
      final exact = exactReviewResource(
        resourceDiscovery.matches,
        actionType: source.type,
      );
      if (exact != null) {
        draft.selectContentItem(exact.id, selected: true);
      }
    }
    draft.selected = draft.isReady;
    return draft;
  }

  final SuggestedPlanAction source;
  final String importRequestId = const Uuid().v4();
  final ReviewResourceDiscovery resourceDiscovery;
  List<ResourceMatch> get resourceMatches => resourceDiscovery.matches;
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
  String selectedResourceId = '';
  final Set<String> contentItemIds = <String>{};
  final String resourceLinkRequestId = const Uuid().v4();
  final String quranLinkRequestId = const Uuid().v4();

  void selectContentItem(String id, {required bool selected}) {
    if (selected && id.isNotEmpty && contentItemIds.length < 16) {
      contentItemIds.add(id);
    } else if (!selected) {
      contentItemIds.remove(id);
    }
    selectedResourceId = contentItemIds.lastOrNull ?? '';
    contentItemId =
        contentItemIds
            .where((item) => !item.startsWith('quran:'))
            .firstOrNull ??
        '';
  }

  bool selected = false;
  bool imported = false;
  bool reminderEnabled = false;

  bool get hasIncompleteMetadata => source.ambiguities.any(
    (item) =>
        item.startsWith('AI omitted metadata fields:') ||
        item.startsWith('AI omitted or left empty metadata fields:'),
  );

  bool get isReady =>
      !source.needsReview && !hasIncompleteMetadata && source.confidence >= 0.8;

  ActionFrequency? get importFrequency {
    if (frequencyType == ActionFrequencyType.daily) {
      final interval = int.tryParse(dailyInterval.trim());
      if (interval == null || interval < 1) return null;
      return ActionFrequency.daily(interval: interval);
    }
    if (frequencyType == ActionFrequencyType.weekly && weekdays.isNotEmpty) {
      return ActionFrequency.weekly(weekdays);
    }
    return null;
  }

  bool get canImport =>
      type.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      importFrequency != null;

  bool get wasEdited {
    if (type.trim() != source.type ||
        title.trim() != source.title ||
        instruction.trim() != (source.instruction ?? '') ||
        int.tryParse(count.trim()) != source.countTarget ||
        int.tryParse(duration.trim()) != source.durationMinutes ||
        timeWindow != (source.timeWindow ?? '') ||
        reminderEnabled ||
        contentItemIds.isNotEmpty) {
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
    return SukunSurface(
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
              'এগুলো শুধু প্রস্তাব, চিকিৎসা বা শরয়ি সিদ্ধান্ত নয়। মূল প্রেসক্রিপশনের সাথে মিলিয়ে নিন। যোগ করার পরেও আপনি অনুমোদন ও চালু না করা পর্যন্ত রোগী কিছু দেখবেন না।',
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
    final needsAttention =
        !draft.imported && (!draft.canImport || draft.source.needsReview);
    return Container(
      decoration: needsAttention
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(SukunRadius.card + 1.5),
              border: Border.all(color: SukunColors.saffron, width: 1.5),
            )
          : null,
      child: SukunSurface(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: number == 1 && !draft.hasIncompleteMetadata,
          leading: Checkbox(
            value: draft.selected,
            onChanged: !enabled || draft.imported || !draft.canImport
                ? null
                : (value) {
                    draft.selected = value ?? false;
                    onChanged();
                  },
          ),
          title: Text(
            draft.title.isEmpty ? 'প্রস্তাব $number' : draft.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                draft.hasIncompleteMetadata
                    ? 'তথ্য অসম্পূর্ণ'
                    : 'AI নিশ্চয়তা ${(draft.source.confidence * 100).round()}% · যাচাই হয়নি',
                style: draft.hasIncompleteMetadata
                    ? TextStyle(color: SukunColors.deepTide)
                    : null,
              ),
              if (!draft.canImport)
                Text(
                  'কতদিন পরপর তা দরকার',
                  style: TextStyle(color: SukunColors.deepTide),
                )
              else if (draft.source.needsReview)
                Text(
                  'যাচাই দরকার',
                  style: TextStyle(color: SukunColors.deepTide),
                ),
              if (draft.imported) const Text('যোগ হয়েছে'),
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
                child: Text(
                  'মূল লেখায় যা আছে: “${draft.source.sourceEvidence}”',
                ),
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
                    const Text('এগুলো মিলিয়ে দেখুন:'),
                    for (final ambiguity in draft.source.ambiguities)
                      Text('• $ambiguity'),
                  ],
                ),
              ),
            TextFormField(
              initialValue: draft.type,
              enabled: enabled && !draft.imported,
              decoration: const InputDecoration(labelText: 'করণীয়ের ধরন'),
              onChanged: (value) => draft.type = value,
              validator: (value) => !draft.selected || draft.imported
                  ? null
                  : validateActionRequired(value, 'করণীয়ের ধরন'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.title,
              enabled: enabled && !draft.imported,
              decoration: const InputDecoration(labelText: 'শিরোনাম'),
              onChanged: (value) {
                draft.title = value;
                onChanged();
              },
              validator: (value) => !draft.selected || draft.imported
                  ? null
                  : validateActionRequired(value, 'শিরোনাম'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.instruction,
              enabled: enabled && !draft.imported,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'নির্দেশনা (ঐচ্ছিক)',
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
                      labelText: 'কতবার (ঐচ্ছিক)',
                    ),
                    onChanged: (value) => draft.count = value,
                    validator: (value) => !draft.selected || draft.imported
                        ? null
                        : validateOptionalPositiveInteger(value, 'কতবার'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.duration,
                    enabled: enabled && !draft.imported,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'মিনিট (ঐচ্ছিক)',
                    ),
                    onChanged: (value) => draft.duration = value,
                    validator: (value) => !draft.selected || draft.imported
                        ? null
                        : validateOptionalPositiveInteger(value, 'সময়'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FormField<ActionFrequencyType>(
              initialValue: draft.frequencyType,
              validator: (value) =>
                  draft.selected && !draft.imported && value == null
                  ? 'প্রেসক্রিপশন অনুযায়ী কতদিন পরপর তা বাছুন।'
                  : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SukunChoiceField<ActionFrequencyType>(
                    label: 'কতদিন পরপর',
                    placeholder: 'পুনরাবৃত্তি বাছুন',
                    value: field.value,
                    enabled: enabled && !draft.imported,
                    options: const [
                      SukunChoiceOption(
                        value: ActionFrequencyType.daily,
                        title: 'প্রতিদিন',
                        description: 'নির্দিষ্ট দিন পরপর পুনরাবৃত্তি।',
                        icon: Icons.today_outlined,
                      ),
                      SukunChoiceOption(
                        value: ActionFrequencyType.weekly,
                        title: 'নির্বাচিত দিন',
                        description: 'শুধু নির্দিষ্ট বারগুলোতে।',
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                decoration: const InputDecoration(labelText: 'কত দিন পরপর'),
                onChanged: (value) => draft.dailyInterval = value,
                validator: (value) => !draft.selected || draft.imported
                    ? null
                    : validateOptionalPositiveInteger(value, 'দিনের ব্যবধান') ??
                          ((value?.trim().isEmpty ?? true)
                              ? 'দিনের ব্যবধান দিতে হবে।'
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
              label: 'দিনের সময় (ঐচ্ছিক)',
              placeholder: 'শুধু প্রেসক্রিপশনে লেখা থাকলে বাছুন',
              value: draft.timeWindow,
              enabled: enabled && !draft.imported,
              options: const [
                SukunChoiceOption(
                  value: '',
                  title: 'নির্ধারিত নয়',
                  description: 'নিজে থেকে সময় ধরে নেবেন না।',
                ),
                SukunChoiceOption(
                  value: 'morning',
                  title: 'সকাল',
                  icon: Icons.wb_sunny_outlined,
                ),
                SukunChoiceOption(
                  value: 'afternoon',
                  title: 'দুপুর',
                  icon: Icons.light_mode_outlined,
                ),
                SukunChoiceOption(
                  value: 'evening',
                  title: 'সন্ধ্যা',
                  icon: Icons.nights_stay_outlined,
                ),
                SukunChoiceOption(
                  value: 'night',
                  title: 'রাত',
                  icon: Icons.bedtime_outlined,
                ),
                SukunChoiceOption(
                  value: 'anytime',
                  title: 'যেকোনো সময়',
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
              title: const Text('নির্দিষ্ট সময়'),
              subtitle: Text(
                draft.exactTime == null
                    ? 'নির্ধারিত নয়'
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
                      tooltip: 'নির্দিষ্ট সময় মুছুন',
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
            if (draft.resourceDiscovery.note != null) ...[
              const SizedBox(height: 10),
              Text(
                draft.resourceDiscovery.note!,
                style: TextStyle(color: SukunColors.deepTide),
              ),
            ],
            if (draft.resourceMatches.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'মিলতে পারে এমন উপকরণ',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final match in draft.resourceMatches)
                    FilterChip(
                      label: Text(match.resource.displayTitle),
                      selected: draft.contentItemIds.contains(
                        match.resource.id,
                      ),
                      onSelected: !enabled || draft.imported
                          ? null
                          : (selected) {
                              draft.selectContentItem(
                                match.resource.id,
                                selected: selected,
                              );
                              onChanged();
                            },
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (draft.resourceDiscovery.missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'প্রকাশিত উপকরণের তালিকায় পাওয়া যায়নি',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final label in draft.resourceDiscovery.missing)
                Text('• $label: যুক্ত করার আগে উপকরণ CMS-এ যোগ বা যাচাই করুন'),
              const SizedBox(height: 10),
            ],
            // Canonical Surah links live in the existing API reader, not in
            // content_items. Show the same safe destination already available
            // to approved Patient plans without creating a false CMS record.
            if (verifiedQuranLinksForText(
              title: draft.title,
              instruction: draft.instruction,
            ).isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'কুরআন রিডারের রেফারেন্স',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 6),
              for (final link in verifiedQuranLinksForText(
                title: draft.title,
                instruction: draft.instruction,
              ))
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(link.route),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text('${link.title} খুলুন'),
                  ),
                ),
              const Text(
                'যাচাইকৃত এই সূরার রেফারেন্স পরিকল্পনা অনুমোদনের পর অ্যাডমিন ও '
                'রোগীর জন্য কুরআন রিডার খুলবে। এটা কোনো CMS উপকরণ বা পূর্ণ '
                'তিলাওয়াতের রেকর্ডিং নয়। প্রেসক্রিপশনে স্পষ্টভাবে শোনার কথা '
                'থাকলে তবেই আলাদা করে প্রকাশিত অডিও বাছুন।',
                style: TextStyle(fontSize: 12, color: SukunColors.muted),
              ),
              const SizedBox(height: 10),
            ],
            ResourcePickerField(
              key: ValueKey(draft.selectedResourceId),
              resources: resources,
              selectedId: draft.selectedResourceId,
              enabled: enabled && !draft.imported,
              onChanged: (value) {
                if (value.isEmpty) {
                  draft.contentItemIds.clear();
                  draft.contentItemId = '';
                  draft.selectedResourceId = '';
                } else {
                  draft.selectContentItem(value, selected: true);
                }
                onChanged();
              },
            ),
          ],
        ),
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
        // Always visible: every suggestion must be compared with it.
        initiallyExpanded: true,
        leading: const Icon(Icons.description_outlined),
        title: const Text('মূল প্রেসক্রিপশন'),
        subtitle: const Text('প্রতিটি প্রস্তাব এর সাথে মিলিয়ে দেখুন।'),
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
                Icon(
                  Icons.edit_note_outlined,
                  size: 48,
                  color: SukunColors.deepTide,
                ),
                const SizedBox(height: 16),
                Text(
                  'নিজে করণীয় লিখে এগিয়ে যান',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.add),
                  label: const Text('নিজে করণীয় তৈরি করুন'),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('আবার চেষ্টা করুন'),
                ),
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
    const ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'][day - 1];
