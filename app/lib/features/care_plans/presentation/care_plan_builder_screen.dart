import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/bulk_prescription_repository.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/prescription_sections.dart';
import 'package:sukun_life/features/care_plans/presentation/batch_prescription_schedule.dart';
import 'package:sukun_life/features/care_plans/presentation/official_template_bulk_picker.dart';
import 'package:sukun_life/features/care_plans/presentation/prescription_pdf_preview.dart';
import 'package:sukun_life/features/care_plans/presentation/prescription_schedule_expansion.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:uuid/uuid.dart';

class CarePlanBuilderScreen extends ConsumerStatefulWidget {
  const CarePlanBuilderScreen({
    super.key,
    required this.patientId,
    required this.planId,
    this.openNewAction = false,
  });

  final String patientId;
  final String planId;
  final bool openNewAction;

  @override
  ConsumerState<CarePlanBuilderScreen> createState() =>
      _CarePlanBuilderScreenState();
}

class _CarePlanBuilderScreenState extends ConsumerState<CarePlanBuilderScreen> {
  late Future<_BuilderData> _data;
  bool _working = false;
  Set<String> _selectedTemplates = {};
  final _selectedActions = <String>{};
  String? _undoBatchId;
  final _pendingRequests = <String, String>{};

  Future<bool> _importTemplates() async {
    if (_working || _selectedTemplates.isEmpty) return false;
    final ids = _selectedTemplates.toList()..sort();
    final key = 'import:${jsonEncode(ids)}';
    final requestId = _pendingRequests.putIfAbsent(
      key,
      () => const Uuid().v4(),
    );
    setState(() => _working = true);
    try {
      final imported = await ref
          .read(bulkPrescriptionRepositoryProvider)
          .importTemplates(
            widget.planId,
            officialPrescriptionTemplates
                .where((item) => _selectedTemplates.contains(item.id))
                .toList(),
            requestId,
          );
      _pendingRequests.remove(key);
      if (!mounted) return false;
      _selectedTemplates = {};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$importedটি টেমপ্লেট খসড়ায় সংরক্ষণ হয়েছে।')),
      );
      _reload();
      return true;
    } catch (error) {
      if (mounted) _showError(error);
      return false;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _templatePicker(
    _BuilderData data, {
    required ValueChanged<Set<String>> onSelectionChanged,
    required VoidCallback onImport,
    bool? working,
  }) => OfficialTemplateBulkPicker(
    importedIds: data.actions
        .map((action) => action.officialTemplateId)
        .nonNulls
        .toSet(),
    selectedIds: _selectedTemplates,
    onSelectionChanged: onSelectionChanged,
    onImport: onImport,
    working: working ?? _working,
  );

  Future<void> _openTemplates(_BuilderData data) async {
    var importing = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .88,
        child: StatefulBuilder(
          builder: (context, setSheetState) => _templatePicker(
            data,
            working: importing,
            onSelectionChanged: (ids) {
              setState(() => _selectedTemplates = ids);
              setSheetState(() {});
            },
            onImport: () async {
              setSheetState(() => importing = true);
              final saved = await _importTemplates();
              if (!sheetContext.mounted) return;
              if (saved) {
                Navigator.pop(sheetContext);
              } else {
                setSheetState(() => importing = false);
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_working) return;
    if (_selectedTemplates.isNotEmpty) {
      await _importTemplates();
      return;
    }
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('করণীয় ও সময়সূচি খসড়ায় সংরক্ষিত আছে।')),
    );
  }

  Set<String> _selectedIn(_BuilderData data) => data.actions
      .map((action) => action.id)
      .toSet()
      .intersection(_selectedActions);

  Future<void> _updateBatch(
    _BuilderData data,
    Map<String, Object?> patch, {
    String? excludeActionId,
  }) async {
    final selected = _selectedIn(data)..remove(excludeActionId);
    if (selected.isEmpty || _working) return;
    final ids = selected.toList()..sort();
    final key = 'batch:${jsonEncode([ids, patch])}';
    final requestId = _pendingRequests.putIfAbsent(
      key,
      () => const Uuid().v4(),
    );
    await _runMutation(() async {
      await ref
          .read(bulkPrescriptionRepositoryProvider)
          .updateActions(widget.planId, selected, patch, requestId);
      _undoBatchId = requestId;
      _pendingRequests.remove(key);
      if (patch['remove'] == true) _selectedActions.removeAll(selected);
    }, successMessage: 'নির্বাচিত করণীয়গুলোর খসড়া সংরক্ষণ হয়েছে।');
  }

  Future<void> _undoBatch() async {
    final requestId = _undoBatchId;
    if (_working || requestId == null) return;
    await _runMutation(() async {
      await ref
          .read(bulkPrescriptionRepositoryProvider)
          .undoBatch(widget.planId, requestId);
      _undoBatchId = null;
    }, successMessage: 'শেষ ব্যাচের পরিবর্তন ফিরিয়ে নেওয়া হয়েছে।');
  }

  Future<void> _expandSchedule(PlanAction action) async {
    final expansion = await showDialog<PrescriptionScheduleExpansion>(
      context: context,
      builder: (context) =>
          PrescriptionScheduleExpansionDialog(title: action.title),
    );
    if (!mounted || expansion == null || _working) return;
    final key =
        'expand:${jsonEncode([action.id, expansion.stageDays, expansion.times])}';
    final requestId = _pendingRequests.putIfAbsent(
      key,
      () => const Uuid().v4(),
    );
    await _runMutation(() async {
      await ref
          .read(bulkPrescriptionRepositoryProvider)
          .expandSchedule(
            planId: widget.planId,
            actionId: action.id,
            requestId: requestId,
            stageDays: expansion.stageDays,
            times: expansion.times,
          );
      _pendingRequests.remove(key);
    }, successMessage: 'সময়সূচির আলাদা করণীয়গুলো খসড়ায় সংরক্ষণ হয়েছে।');
  }

  Future<void> _scheduleBatch(_BuilderData data) async {
    final patch = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => BatchPrescriptionSchedule(
        plan: data.plan,
        selectedCount: _selectedIn(data).length,
      ),
    );
    if (mounted && patch != null) await _updateBatch(data, patch);
  }

  Future<void> _removeBatch(_BuilderData data) async {
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: 'নির্বাচিত করণীয় বাদ দেবেন?',
      message: '${_selectedIn(data).length}টি করণীয় খসড়া থেকে বাদ যাবে।',
      confirmLabel: 'বাদ দিন',
      icon: Icons.delete_outline,
    );
    if (mounted && confirmed == true) {
      await _updateBatch(data, {'remove': true});
    }
  }

  Future<void> _export(_BuilderData data) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final patients = ref.read(patientsRepositoryProvider);
      final studio = ref.read(bulkPrescriptionRepositoryProvider);
      final practitionerId = data.plan.publishedBy ?? data.plan.createdBy;
      final patient = await patients.getPatient(data.plan.patientId);
      if (patient == null) {
        throw const CarePlanWorkflowException('Patient was not found.');
      }
      final practitioner = practitionerId == null
          ? null
          : await studio.practitionerName(practitionerId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PrescriptionPdfPreview(
            plan: data.plan,
            patient: patient,
            actions: data.actions,
            practitioner: practitioner,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _data = _load();
    if (widget.openNewAction) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAction();
      });
    }
  }

  Future<_BuilderData> _load() async {
    final repository = ref.read(carePlansRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.getPlan(widget.planId),
      repository.getActions(widget.planId),
    ]);
    final plan = results[0] as CarePlan?;
    if (plan == null || plan.patientId != widget.patientId) {
      throw const CarePlanWorkflowException('Care plan was not found.');
    }
    return _BuilderData(plan: plan, actions: results[1] as List<PlanAction>);
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _openAction([PlanAction? action]) async {
    final suffix = action == null ? 'new' : action.id;
    final changed = await context.push<bool>(
      '/admin/patients/${widget.patientId}/plans/${widget.planId}/actions/$suffix',
    );
    if (mounted && changed == true) _reload();
  }

  Future<void> _duplicateAction(PlanAction action) async {
    if (_working) return;
    String? newId;
    final key = 'duplicate:${action.id}';
    final requestId = _pendingRequests.putIfAbsent(
      key,
      () => const Uuid().v4(),
    );
    await _runMutation(() async {
      final ids = await ref
          .read(bulkPrescriptionRepositoryProvider)
          .expandSchedule(
            planId: widget.planId,
            actionId: action.id,
            requestId: requestId,
          );
      _pendingRequests.remove(key);
      newId = ids.single;
    }, successMessage: 'একটি আলাদা খসড়া তৈরি হয়েছে।');
    if (!mounted || newId == null) return;
    final changed = await context.push<bool>(
      '/admin/patients/${widget.patientId}/plans/${widget.planId}/actions/$newId',
    );
    if (mounted && changed == true) _reload();
  }

  Future<void> _generateActions(CarePlan plan) async {
    final prescriptionId = plan.prescriptionId;
    if (prescriptionId == null) return;
    final changed = await context.push<bool>(
      '/admin/patients/${widget.patientId}/plans/${widget.planId}/actions/suggest'
      '?prescriptionId=${Uri.encodeQueryComponent(prescriptionId)}',
    );
    if (mounted && changed == true) _reload();
  }

  Future<void> _reorder(_BuilderData data, int oldIndex, int newIndex) async {
    if (!data.plan.isEditable || _working) return;
    final reordered = [...data.actions];
    final action = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, action);
    setState(() {
      _working = true;
      _data = Future.value(_BuilderData(plan: data.plan, actions: reordered));
    });
    try {
      await ref
          .read(carePlansRepositoryProvider)
          .reorderActions(
            widget.planId,
            reordered.map((item) => item.id).toList(growable: false),
            const Uuid().v4(),
          );
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
      _reload();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reject(PlanAction action) async {
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: 'খসড়া থেকে করণীয় বাদ দেবেন?',
      message:
          '“${action.title}” বাদ দেওয়া হিসেবে লেখা থাকবে; আগের তথ্য সংরক্ষিত থাকবে।',
      confirmLabel: 'বাদ দিন',
      icon: Icons.remove_circle_outline_rounded,
    );
    if (confirmed != true || _working) return;
    await _runMutation(() async {
      await ref
          .read(carePlansRepositoryProvider)
          .rejectAction(action.id, const Uuid().v4());
    }, successMessage: 'খসড়া থেকে করণীয়টি বাদ দেওয়া হয়েছে।');
  }

  Future<void> _publish(_BuilderData data) async {
    final approved = data.actions
        .where((action) => action.reviewStatus == ActionReviewStatus.approved)
        .length;
    final unresolved = data.actions.length - approved;
    if (approved == 0 || unresolved > 0 || _working) return;
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: 'রোগীর জন্য পরিকল্পনাটি চালু করবেন?',
      message:
          'এই পরিকল্পনার ${data.plan.version} নম্বর সংস্করণ রোগী দেখতে পাবেন। $approvedটি করণীয় অনুমোদিত হয়েছে।',
      confirmLabel: 'চালু করুন',
      cancelLabel: 'আরও সংশোধন করব',
      icon: Icons.publish_outlined,
    );
    if (confirmed != true || _working) return;
    await _runMutation(() async {
      await ref
          .read(carePlansRepositoryProvider)
          .publishPlan(widget.planId, const Uuid().v4());
    }, successMessage: 'পরিকল্পনাটি রোগীর জন্য চালু হয়েছে।');
  }

  Future<void> _archive(CarePlan plan) async {
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: 'পরিকল্পনাটি সংরক্ষণাগারে রাখবেন?',
      message: 'আগের তথ্য থাকবে, তবে এই সংস্করণটি আর চালু পরিকল্পনা হিসেবে ব্যবহার করা যাবে না।',
      confirmLabel: 'সংরক্ষণাগারে রাখুন',
      icon: Icons.archive_outlined,
    );
    if (confirmed != true || _working) return;
    await _runMutation(
      () async {
        await ref
            .read(carePlansRepositoryProvider)
            .archivePlan(plan.id, const Uuid().v4());
      },
      successMessage:
          'আগের তথ্য অক্ষত রেখে পরিকল্পনাটি সংরক্ষণাগারে রাখা হয়েছে।',
    );
  }

  Future<void> _createVersion(CarePlan plan) async {
    final created = await context.push<CarePlan>(
      '/admin/patients/${widget.patientId}/plans/new'
      '?copyFromPlanId=${Uri.encodeQueryComponent(plan.id)}',
    );
    if (!mounted || created == null) return;
    context.pushReplacement(
      '/admin/patients/${widget.patientId}/plans/${created.id}',
    );
  }

  Future<void> _runMutation(
    Future<void> Function() mutation, {
    required String successMessage,
  }) async {
    setState(() => _working = true);
    try {
      await mutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      _reload();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('কাজটি সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('রোগীর পরিকল্পনা সাজান')),
      body: FutureBuilder<_BuilderData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'পরিকল্পনা আনা হচ্ছে…');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'পরিকল্পনাটি আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100 && data.plan.isEditable;
              final selected = _selectedIn(data);
              final unresolved = data.actions
                  .where(
                    (action) =>
                        action.reviewStatus != ActionReviewStatus.approved,
                  )
                  .length;
              final batchControls = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_undoBatchId != null)
                    TextButton.icon(
                      onPressed: _working ? null : _undoBatch,
                      icon: const Icon(Icons.undo),
                      label: const Text('শেষ ব্যাচের পরিবর্তন ফেরান'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _saveDraft,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Draft'),
                  ),
                  SukunStatusPill(
                    label: '${selected.length} নির্বাচিত',
                    tone: SukunStatusTone.brand,
                  ),
                  OutlinedButton.icon(
                    onPressed: _working || selected.isEmpty
                        ? null
                        : () => _scheduleBatch(data),
                    icon: const Icon(Icons.schedule),
                    label: const Text('সময়সূচি প্রয়োগ করুন'),
                  ),
                  TextButton(
                    onPressed: _working || selected.isEmpty
                        ? null
                        : () => _removeBatch(data),
                    child: const Text('নির্বাচিতগুলো বাদ দিন'),
                  ),
                  TextButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => setState(_selectedActions.clear),
                    child: const Text('নির্বাচন বাতিল'),
                  ),
                ],
              );
              final editor = RefreshIndicator(
                onRefresh: () async => _reload(),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      sliver: SliverList.list(
                        children: [
                          if (wide || !data.plan.isEditable)
                            const SukunPageIntro(
                              eyebrow: 'রোগীর সেবার কাজ',
                              title: 'রোগীর করণীয় সাজান',
                              subtitle: 'রোগীর কাছে পাঠানোর আগে প্রতিটি করণীয় যাচাই ও অনুমোদন করুন।',
                            ),
                          if (wide || !data.plan.isEditable)
                            const SizedBox(height: 20),
                          if (!wide)
                            _PlanSummary(
                              plan: data.plan,
                              compact: data.plan.isEditable,
                            ),
                          const SizedBox(height: 16),
                          if (data.plan.isEditable && !wide)
                            FilledButton.icon(
                              onPressed: _working
                                  ? null
                                  : () => _openTemplates(data),
                              icon: const Icon(Icons.library_add_outlined),
                              label: Text(
                                'Official Templates (${_selectedTemplates.length})',
                              ),
                            ),
                          if (!wide &&
                              !data.plan.isEditable &&
                              data.actions.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: _working ? null : () => _export(data),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Export Prescription PDF'),
                            ),
                          if (wide || !data.plan.isEditable)
                            _PlanActions(
                              plan: data.plan,
                              working: _working,
                              actionCount: data.actions.length,
                              unresolvedCount: unresolved,
                              onPreview: () => context.push(
                                '/admin/patients/${widget.patientId}/plans/${widget.planId}/preview',
                              ),
                              onGenerate: () => _generateActions(data.plan),
                              onAdd: () => _openAction(),
                              onPublish: () => _publish(data),
                              onArchive: () => _archive(data.plan),
                              onCreateVersion: () => _createVersion(data.plan),
                            ),
                          if (!wide && data.plan.isEditable)
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: _working
                                      ? null
                                      : () => _openAction(),
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text('নিজে করণীয় লিখুন'),
                                ),
                                IconButton(
                                  tooltip: 'রোগী যেমন দেখবেন',
                                  onPressed: () => context.push(
                                    '/admin/patients/${widget.patientId}/plans/${widget.planId}/preview',
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                ),
                                if (data.plan.prescriptionId != null)
                                  IconButton(
                                    tooltip: 'প্রেসক্রিপশন থেকে করণীয় সাজান',
                                    onPressed: _working
                                        ? null
                                        : () => _generateActions(data.plan),
                                    icon: const Icon(
                                      Icons.auto_awesome_outlined,
                                    ),
                                  ),
                                TextButton(
                                  onPressed: _working ? null : _saveDraft,
                                  child: const Text('Save Draft'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          if (data.plan.isEditable &&
                              !wide &&
                              (selected.isNotEmpty || _undoBatchId != null))
                            batchControls,
                          SukunSectionHeader(
                            title: 'করণীয় কাজগুলো',
                            subtitle: data.plan.isEditable
                                ? 'ক্রম বদলাতে ধরে টানুন · চালু করার আগে যাচাই করুন'
                                : 'রোগীর জন্য চালু করা ক্রম',
                            action: SukunStatusPill(
                              label: '${data.actions.length}',
                              tone: SukunStatusTone.brand,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    if (data.actions.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          title: 'এখনো কোনো করণীয় নেই',
                          message: 'প্রেসক্রিপশনের স্পষ্ট নির্দেশনা অনুযায়ী করণীয় যোগ করুন। অস্পষ্ট তথ্য অনুমোদনের আগে যাচাই করুন।',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 104),
                        sliver: SliverReorderableList(
                          itemCount: data.actions.length,
                          onReorderItem: (oldIndex, newIndex) =>
                              _reorder(data, oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final action = data.actions[index];
                            return Padding(
                              key: ValueKey(action.id),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (index == 0 ||
                                      prescriptionCategory(
                                            data.actions[index - 1],
                                          ) !=
                                          prescriptionCategory(action))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        prescriptionCategory(action),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                  _ActionCard(
                                    action: action,
                                    editable: data.plan.isEditable && !_working,
                                    index: index,
                                    selected: selected.contains(action.id),
                                    onSelect: (value) => setState(() {
                                      if (value == true) {
                                        _selectedActions.add(action.id);
                                      } else {
                                        _selectedActions.remove(action.id);
                                      }
                                    }),
                                    onCopySchedule:
                                        selected.difference({action.id}).isEmpty
                                        ? null
                                        : () => _updateBatch(
                                            data,
                                            copyPrescriptionSchedule(action),
                                            excludeActionId: action.id,
                                          ),
                                    onEdit: () => _openAction(action),
                                    onDuplicate: () => _duplicateAction(action),
                                    onExpandSchedule: () =>
                                        _expandSchedule(action),
                                    onReject: () => _reject(action),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
              if (!wide && data.plan.isEditable) {
                return Column(
                  children: [
                    Expanded(child: editor),
                    Material(
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unresolved > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '$unresolvedটি করণীয় যাচাই ও অনুমোদন বাকি।',
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: OutlinedButton.icon(
                                    onPressed: _working || data.actions.isEmpty
                                        ? null
                                        : () => _export(data),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                    ),
                                    label: const Text(
                                      'Export Prescription PDF',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton(
                                    onPressed:
                                        _working ||
                                            unresolved > 0 ||
                                            data.actions.isEmpty
                                        ? null
                                        : () => _publish(data),
                                    child: const Text('রোগীর জন্য চালু করুন'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              if (!wide) return editor;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 300,
                    child: _templatePicker(
                      data,
                      onSelectionChanged: (ids) =>
                          setState(() => _selectedTemplates = ids),
                      onImport: _importTemplates,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: editor),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 275,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _PlanSummary(plan: data.plan),
                        const SizedBox(height: 16),
                        Text(
                          'যাচাই ও রপ্তানি',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${data.actions.where((action) => action.reviewStatus != ActionReviewStatus.approved).length}টি যাচাই বাকি',
                        ),
                        const SizedBox(height: 8),
                        batchControls,
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _working || data.actions.isEmpty
                              ? null
                              : () => _export(data),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Export Prescription PDF'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BuilderData {
  const _BuilderData({required this.plan, required this.actions});

  final CarePlan plan;
  final List<PlanAction> actions;
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan, this.compact = false});

  final CarePlan plan;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      tone: SukunSurfaceTone.navy,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SukunIconBadge(
                icon: Icons.assignment_outlined,
                color: Colors.white,
                backgroundColor: Color(0x3328B8EF),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    Text(
                      'সংস্করণ ${plan.version}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              SukunStatusPill(
                label: _planStatusLabel(plan.status),
                tone: plan.isEditable
                    ? SukunStatusTone.warning
                    : SukunStatusTone.success,
              ),
            ],
          ),
          if (!compact) const SizedBox(height: 20),
          if (!compact)
            Text(
              '${_formatDate(plan.startDate)} – '
              '${plan.endDate == null ? 'শেষ তারিখ নির্ধারিত নয়' : _formatDate(plan.endDate!)}',
              style: const TextStyle(color: Colors.white70),
            ),
          if (plan.isEditable && !compact) ...[
            const SizedBox(height: 10),
            const Text(
              'সব করণীয় যাচাই ও অনুমোদনের পর পরিকল্পনাটি চালু করা হলে রোগী দেখতে পাবেন।',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanActions extends StatelessWidget {
  const _PlanActions({
    required this.plan,
    required this.working,
    required this.actionCount,
    required this.unresolvedCount,
    required this.onPreview,
    required this.onGenerate,
    required this.onAdd,
    required this.onPublish,
    required this.onArchive,
    required this.onCreateVersion,
  });

  final CarePlan plan;
  final bool working;
  final int actionCount;
  final int unresolvedCount;
  final VoidCallback onPreview;
  final VoidCallback onGenerate;
  final VoidCallback onAdd;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onCreateVersion;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onPreview,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('রোগী যেমন দেখবেন'),
        ),
        if (plan.isEditable) ...[
          if (plan.prescriptionId != null)
            FilledButton.tonalIcon(
              onPressed: working ? null : onGenerate,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('প্রেসক্রিপশন থেকে করণীয় সাজান'),
            ),
          FilledButton.icon(
            onPressed: working ? null : onAdd,
            icon: const Icon(Icons.add),
            label: const Text('নতুন করণীয় যোগ করুন'),
          ),
          FilledButton.tonalIcon(
            onPressed: working || actionCount == 0 || unresolvedCount > 0
                ? null
                : onPublish,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('রোগীর জন্য চালু করুন'),
          ),
          if (actionCount == 0 || unresolvedCount > 0)
            Text(
              actionCount == 0
                  ? 'আগে অন্তত একটি করণীয় যোগ ও অনুমোদন করুন।'
                  : '$unresolvedCountটি করণীয় যাচাই ও অনুমোদন বাকি।',
            ),
        ] else ...[
          FilledButton.tonalIcon(
            onPressed: working ? null : onCreateVersion,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('নতুন সংস্করণ তৈরি করুন'),
          ),
          if (plan.canArchive)
            TextButton.icon(
              onPressed: working ? null : onArchive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('সংরক্ষণাগারে রাখুন'),
            ),
        ],
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.editable,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onCopySchedule,
    required this.onEdit,
    required this.onDuplicate,
    required this.onExpandSchedule,
    required this.onReject,
  });

  final PlanAction action;
  final bool editable;
  final int index;
  final bool selected;
  final ValueChanged<bool?> onSelect;
  final VoidCallback? onCopySchedule;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onExpandSchedule;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final showDragHandle = MediaQuery.sizeOf(context).width >= 600;
    return SukunSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (editable)
            Checkbox(
              value: selected,
              onChanged: onSelect,
              semanticLabel: '${action.title} নির্বাচন',
            ),
          if (editable && showDragHandle)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 10, top: 8),
                child: Icon(Icons.drag_indicator),
              ),
            ),
          Expanded(
            child: ReorderableDelayedDragStartListener(
              index: index,
              enabled: editable && !showDragHandle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        action.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SukunStatusPill(
                        label: _reviewStatusLabel(action.reviewStatus),
                        tone: action.reviewStatus == ActionReviewStatus.approved
                            ? SukunStatusTone.success
                            : SukunStatusTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_frequencyLabel(action.frequency)} · ${_timingLabel(action)}',
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: const Text('বিস্তারিত'),
                    children: [
                      if (action.instruction?.isNotEmpty == true)
                        Text(action.instruction!),
                      Text(
                        '${prescriptionDate(action.startDate)} – '
                        '${action.endDate == null ? 'শেষ তারিখ নেই' : prescriptionDate(action.endDate!)}',
                      ),
                      Text(
                        action.reminderEnabled
                            ? 'রিমাইন্ডার চালু'
                            : 'রিমাইন্ডার বন্ধ',
                      ),
                      if (action.countTarget != null)
                        Text('কতবার: ${action.countTarget}'),
                      if (action.durationMinutes != null)
                        Text('${action.durationMinutes} মিনিট'),
                      for (final resource in action.linkedResources)
                        Text(
                          'সহায়ক উপকরণ: ${resource.titleBn ?? resource.title}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (editable) ...[
            IconButton(
              onPressed: onEdit,
              tooltip: 'সংশোধন করুন',
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'আরও কাজ',
              onSelected: (value) {
                if (value == 'duplicate') {
                  onDuplicate();
                } else if (value == 'remove') {
                  onReject();
                } else if (value == 'schedule') {
                  onCopySchedule?.call();
                } else if (value == 'expand') {
                  onExpandSchedule();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('ডুপ্লিকেট করে নতুন খসড়া'),
                ),
                const PopupMenuItem(value: 'remove', child: Text('বাদ দিন')),
                const PopupMenuItem(
                  value: 'expand',
                  child: Text('একাধিক সময় বা ধারাবাহিক ধাপ'),
                ),
                if (onCopySchedule != null)
                  const PopupMenuItem(
                    value: 'schedule',
                    child: Text('নির্বাচিতগুলোতে এই সময়সূচি দিন'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _timingLabel(PlanAction action) {
  if (action.exactTime != null) {
    final hour = action.exactTime!.hour.toString().padLeft(2, '0');
    final minute = action.exactTime!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  return action.timeWindow ?? 'সময় নির্ধারিত নেই';
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _planStatusLabel(CarePlanStatus status) => switch (status) {
  CarePlanStatus.draft => 'খসড়া',
  CarePlanStatus.active => 'চালু',
  CarePlanStatus.inactive => 'বন্ধ',
  CarePlanStatus.archived => 'সংরক্ষিত',
};

String _reviewStatusLabel(ActionReviewStatus status) => switch (status) {
  ActionReviewStatus.draft => 'খসড়া',
  ActionReviewStatus.needsReview => 'যাচাই বাকি',
  ActionReviewStatus.approved => 'অনুমোদিত',
  ActionReviewStatus.rejected => 'বাদ দেওয়া',
};

String _frequencyLabel(ActionFrequency frequency) {
  if (frequency.type == ActionFrequencyType.daily) {
    return frequency.interval == 1
        ? 'প্রতিদিন'
        : 'প্রতি ${frequency.interval} দিন পর';
  }
  const days = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];
  final selected = frequency.weekdays.toList()..sort();
  return selected.map((day) => days[day - 1]).join(', ');
}
