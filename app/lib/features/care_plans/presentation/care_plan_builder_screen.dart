import 'package:flutter/material.dart';
import 'package:sukun_life/features/home/presentation/staff_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/data/care_template_repository.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/bulk_care_plan_importer.dart';
import 'package:sukun_life/features/care_plans/data/reminder_controls.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action_approval.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/presentation/bulk_template_import_screen.dart';
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

  /// Adds many template/library rows at once with reminders on, then
  /// publishes when nothing else in the draft still needs review.
  Future<void> _bulkImport() async {
    if (_working) return;
    final repository = ref.read(carePlansRepositoryProvider);
    final resources = repository.getAvailableResources();
    final items = await showBulkTemplateImport(
      context,
      recipientLabel: 'এই পরিকল্পনায় যোগ হবে',
      resources: resources,
      templates: ref.read(careTemplateRepositoryProvider).load(),
      saveTemplate: (template) =>
          ref.read(careTemplateRepositoryProvider).save(template),
    );
    if (items == null || items.isEmpty || !mounted) return;
    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var lookup = <String, ContentResourceOption>{};
      try {
        lookup = {for (final r in await resources) r.id: r};
      } catch (_) {}
      final result =
          await BulkCarePlanImporter(
            repository,
            setNotificationTitle: (id, title) =>
                saveReminderName(ref, id, title),
          ).import(
            patientId: widget.patientId,
            items: items,
            resourceLookup: lookup,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.published
                ? 'যুক্ত ও প্রকাশিত হয়েছে, রিমাইন্ডার চালু।'
                : 'যুক্ত হয়েছে। বাকি করণীয় অনুমোদন করে প্রকাশ করুন।',
          ),
        ),
      );
      if (result.plan.id != widget.planId && mounted) {
        context.pushReplacement(
          '/admin/patients/${widget.patientId}/plans/${result.plan.id}',
        );
        return;
      }
    } on CarePlanWorkflowException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) {
        setState(() => _working = false);
        _reload();
      }
    }
  }

  Future<void> _duplicateAction(PlanAction action) async {
    final changed = await context.push<bool>(
      '/admin/patients/${widget.patientId}/plans/${widget.planId}/actions/new'
      '?copyActionId=${Uri.encodeQueryComponent(action.id)}',
    );
    if (mounted && changed == true) _reload();
  }

  Future<void> _generateActions(CarePlan plan) async {
    final prescriptionId = plan.prescriptionId;
    if (prescriptionId == null) return;
    final changed = await context.push<bool>(
      '/admin/patients/${widget.patientId}/plans/${widget.planId}/actions/suggest'
      '?prescriptionId=${Uri.encodeQueryComponent(prescriptionId)}'
      '&from=builder',
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
      final saved = await ref
          .read(carePlansRepositoryProvider)
          .reorderActions(
            widget.planId,
            reordered.map((item) => item.id).toList(growable: false),
            const Uuid().v4(),
          );
      if (mounted) {
        setState(
          () => _data = Future.value(
            _BuilderData(plan: data.plan, actions: saved),
          ),
        );
      }
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

  /// One-tap approval. Shows what will be approved, then saves through the
  /// same repository path as the action editor (see plan_action_approval).
  Future<void> _approve(PlanAction action) async {
    if (_working) return;
    final details = [
      '${_frequencyLabel(action.frequency)} · ${_timingLabel(action)}',
      if (action.countTarget != null) 'কতবার: ${action.countTarget}',
      if (action.durationMinutes != null)
        'সময়: ${action.durationMinutes} মিনিট',
      if (action.instruction?.isNotEmpty == true) action.instruction!,
    ].join('\n');
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: '“${action.title}” অনুমোদন করবেন?',
      message:
          '$details\n\nভালো করে মিলিয়ে নিন। কিছু বদলাতে হলে আগে '
          '"সংশোধন করুন" চাপুন।',
      confirmLabel: 'অনুমোদন করুন',
      cancelLabel: 'বাতিল',
      icon: Icons.verified_outlined,
    );
    if (confirmed != true || _working) return;
    await _runMutation(() async {
      await approvePlanAction(ref.read(carePlansRepositoryProvider), action);
    }, successMessage: 'করণীয়টি অনুমোদিত হয়েছে।');
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

  int _unresolved(_BuilderData data) => data.actions
      .where((action) => action.reviewStatus != ActionReviewStatus.approved)
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('রোগীর পরিকল্পনা সাজান')),
      bottomNavigationBar: FutureBuilder<_BuilderData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null || snapshot.hasError) return const SizedBox.shrink();
          return _PlanBottomBar(
            plan: data.plan,
            working: _working,
            actionCount: data.actions.length,
            unresolvedCount: _unresolved(data),
            onPreview: () => context.push(
              '/admin/patients/${widget.patientId}/plans/${widget.planId}/preview',
            ),
            onPublish: () => _publish(data),
            onCreateVersion: () => _createVersion(data.plan),
          );
        },
      ),
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
          final unresolved = _unresolved(data);
          final step =
              !data.plan.isEditable ||
                  (data.actions.isNotEmpty && unresolved == 0)
              ? 2
              : 1;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    SukunSpace.page,
                    SukunSpace.sm,
                    SukunSpace.page,
                    SukunSpace.sm,
                  ),
                  sliver: SliverList.list(
                    children: [
                      SukunStepper(current: step),
                      const SizedBox(height: SukunSpace.page),
                      _PlanSummary(plan: data.plan),
                      const SizedBox(height: SukunSpace.md),
                      _PlanSecondaryActions(
                        plan: data.plan,
                        working: _working,
                        // AI suggestions are the main admin's tool.
                        onGenerate: isRaqiSession(context)
                            ? null
                            : () => _generateActions(data.plan),
                        onAdd: _bulkImport,
                        onArchive: () => _archive(data.plan),
                      ),
                      const SizedBox(height: SukunSpace.section),
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
                      const SizedBox(height: SukunSpace.md),
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
                    padding: const EdgeInsets.fromLTRB(
                      SukunSpace.page,
                      0,
                      SukunSpace.page,
                      SukunSpace.section,
                    ),
                    sliver: SliverReorderableList(
                      itemCount: data.actions.length,
                      onReorderItem: (oldIndex, newIndex) =>
                          _reorder(data, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final action = data.actions[index];
                        return Padding(
                          key: ValueKey(action.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActionCard(
                            action: action,
                            editable: data.plan.isEditable && !_working,
                            index: index,
                            onEdit: () => _openAction(action),
                            onDuplicate: () => _duplicateAction(action),
                            onReject: () => _reject(action),
                            onApprove: () => _approve(action),
                          ),
                        );
                      },
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

class _BuilderData {
  const _BuilderData({required this.plan, required this.actions});

  final CarePlan plan;
  final List<PlanAction> actions;
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SukunSurface(
      padding: const EdgeInsets.all(SukunSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SukunIconBadge(icon: Icons.assignment_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'সংস্করণ ${plan.version} · ${_formatDate(plan.startDate)} – '
                      '${plan.endDate == null ? 'শেষ তারিখ নির্ধারিত নয়' : _formatDate(plan.endDate!)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: SukunColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SukunStatusPill(
                label: _planStatusLabel(plan.status),
                tone: plan.isEditable
                    ? SukunStatusTone.warning
                    : SukunStatusTone.success,
              ),
            ],
          ),
          if (plan.isEditable) ...[
            const SizedBox(height: SukunSpace.md),
            Text(
              'সব করণীয় যাচাই ও অনুমোদনের পর পরিকল্পনাটি চালু করা হলে রোগী দেখতে পাবেন।',
              style: textTheme.bodySmall?.copyWith(color: SukunColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanSecondaryActions extends StatelessWidget {
  const _PlanSecondaryActions({
    required this.plan,
    required this.working,
    required this.onGenerate,
    required this.onAdd,
    required this.onArchive,
  });

  final CarePlan plan;
  final bool working;
  final VoidCallback? onGenerate;
  final VoidCallback onAdd;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    if (!plan.isEditable && !plan.canArchive) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (plan.isEditable) ...[
          OutlinedButton.icon(
            onPressed: working ? null : onAdd,
            icon: const Icon(Icons.add),
            label: const Text('নতুন করণীয় যোগ করুন'),
          ),
          if (plan.prescriptionId != null && onGenerate != null)
            OutlinedButton.icon(
              onPressed: working ? null : onGenerate,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('প্রেসক্রিপশন থেকে করণীয় সাজান'),
            ),
        ] else if (plan.canArchive)
          TextButton.icon(
            onPressed: working ? null : onArchive,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('সংরক্ষণাগারে রাখুন'),
          ),
      ],
    );
  }
}

/// Publishing is the plan's main decision, so it stays in a fixed bar.
class _PlanBottomBar extends StatelessWidget {
  const _PlanBottomBar({
    required this.plan,
    required this.working,
    required this.actionCount,
    required this.unresolvedCount,
    required this.onPreview,
    required this.onPublish,
    required this.onCreateVersion,
  });

  final CarePlan plan;
  final bool working;
  final int actionCount;
  final int unresolvedCount;
  final VoidCallback onPreview;
  final VoidCallback onPublish;
  final VoidCallback onCreateVersion;

  @override
  Widget build(BuildContext context) {
    final blocked = actionCount == 0 || unresolvedCount > 0;
    return SukunBottomActionBar(
      hint: plan.isEditable && blocked
          ? Text(
              actionCount == 0
                  ? 'আগে অন্তত একটি করণীয় যোগ ও অনুমোদন করুন।'
                  : '$unresolvedCountটি করণীয় যাচাই ও অনুমোদন বাকি।',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF7A5A10),
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      children: [
        OutlinedButton.icon(
          onPressed: onPreview,
          icon: const Icon(Icons.visibility_outlined),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('রোগী যেমন দেখবেন'),
          ),
        ),
        if (plan.isEditable)
          FilledButton.icon(
            onPressed: working || blocked ? null : onPublish,
            icon: const Icon(Icons.publish_outlined),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('রোগীর জন্য চালু করুন'),
            ),
          )
        else
          FilledButton.icon(
            onPressed: working ? null : onCreateVersion,
            icon: const Icon(Icons.copy_all_outlined),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('নতুন সংস্করণ তৈরি করুন'),
            ),
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.editable,
    required this.index,
    required this.onEdit,
    required this.onDuplicate,
    required this.onReject,
    required this.onApprove,
  });

  final PlanAction action;
  final bool editable;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final needsAttention =
        action.reviewStatus == ActionReviewStatus.needsReview;
    return Container(
      decoration: needsAttention
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(SukunRadius.card + 1.5),
              border: Border.all(color: SukunColors.saffron, width: 1.5),
            )
          : null,
      child: SukunSurface(
        padding: const EdgeInsets.all(SukunSpace.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (editable)
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 10, top: 8),
                  child: Icon(Icons.drag_indicator),
                ),
              ),
            Expanded(
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
                  if (action.countTarget != null)
                    Text('কতবার: ${action.countTarget}'),
                  if (action.durationMinutes != null)
                    Text('সময়: ${action.durationMinutes} মিনিট'),
                  if (action.instruction?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(action.instruction!),
                  ],
                  if (action.linkedResources.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final resource in action.linkedResources)
                      Text(
                        'সহায়ক উপকরণ: ${resource.titleBn ?? resource.title}',
                      ),
                  ],
                  if (editable &&
                      action.reviewStatus != ActionReviewStatus.approved) ...[
                    const SizedBox(height: SukunSpace.md),
                    FilledButton.tonalIcon(
                      key: Key('approve-action-${action.id}'),
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('অনুমোদন'),
                    ),
                  ],
                ],
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
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text('ডুপ্লিকেট করে নতুন খসড়া'),
                  ),
                  PopupMenuItem(value: 'remove', child: Text('বাদ দিন')),
                ],
              ),
            ],
          ],
        ),
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
  return switch (action.timeWindow) {
    'morning' => 'সকাল',
    'afternoon' => 'দুপুর',
    'evening' => 'সন্ধ্যা',
    'night' => 'রাত',
    'anytime' => 'যেকোনো সময়',
    null || '' => 'সময় নির্ধারিত নেই',
    final other => other,
  };
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
  if (frequency.type == ActionFrequencyType.dates) {
    final kind = frequency.ghusl?.label;
    return '${kind == null ? '' : '$kind · '}${frequency.dates.length}টি তারিখ';
  }
  if (frequency.type == ActionFrequencyType.daily) {
    return frequency.interval == 1
        ? 'প্রতিদিন'
        : 'প্রতি ${frequency.interval} দিন পর';
  }
  const days = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];
  final selected = frequency.weekdays.toList()..sort();
  return selected.map((day) => days[day - 1]).join(', ');
}
