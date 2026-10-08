import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:uuid/uuid.dart';

class CarePlanBuilderScreen extends ConsumerStatefulWidget {
  const CarePlanBuilderScreen({
    super.key,
    required this.patientId,
    required this.planId,
  });

  final String patientId;
  final String planId;

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

  Future<void> _publish(_BuilderData data) async {
    final approved = data.actions
        .where((action) => action.reviewStatus == ActionReviewStatus.approved)
        .length;
    final unresolved = data.actions.length - approved;
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: 'রোগীর জন্য পরিকল্পনাটি চালু করবেন?',
      message:
          'This will make version ${data.plan.version} the patient’s active plan. '
          'It contains $approved approved action${approved == 1 ? '' : 's'}.'
          '${unresolved == 0 ? '' : ' $unresolved action${unresolved == 1 ? '' : 's'} still require review and publishing will be refused.'}',
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
    await _runMutation(() async {
      await ref
          .read(carePlansRepositoryProvider)
          .archivePlan(plan.id, const Uuid().v4());
    }, successMessage: 'আগের তথ্য অক্ষত রেখে পরিকল্পনাটি সংরক্ষণাগারে রাখা হয়েছে।');
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
      const SnackBar(content: Text('কাজটি সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।')),
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
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverList.list(
                    children: [
                      const SukunPageIntro(
                        eyebrow: 'রোগীর সেবার কাজ',
                        title: 'রোগীর করণীয় সাজান',
                        subtitle: 'রোগীর কাছে পাঠানোর আগে প্রতিটি করণীয় যাচাই ও অনুমোদন করুন।',
                      ),
                      const SizedBox(height: 20),
                      _PlanSummary(plan: data.plan),
                      const SizedBox(height: 16),
                      _PlanActions(
                        plan: data.plan,
                        working: _working,
                        onPreview: () => context.push(
                          '/admin/patients/${widget.patientId}/plans/${widget.planId}/preview',
                        ),
                        onGenerate: () => _generateActions(data.plan),
                        onAdd: () => _openAction(),
                        onPublish: () => _publish(data),
                        onArchive: () => _archive(data.plan),
                        onCreateVersion: () => _createVersion(data.plan),
                      ),
                      const SizedBox(height: 24),
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
                          child: _ActionCard(
                            action: action,
                            editable: data.plan.isEditable && !_working,
                            index: index,
                            onEdit: () => _openAction(action),
                            onReject: () => _reject(action),
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
          const SizedBox(height: 20),
          Text(
            '${_formatDate(plan.startDate)} – '
            '${plan.endDate == null ? 'শেষ তারিখ নির্ধারিত নয়' : _formatDate(plan.endDate!)}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (plan.isEditable) ...[
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
    required this.onPreview,
    required this.onGenerate,
    required this.onAdd,
    required this.onPublish,
    required this.onArchive,
    required this.onCreateVersion,
  });

  final CarePlan plan;
  final bool working;
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
          OutlinedButton.icon(
            onPressed: working ? null : onAdd,
            icon: const Icon(Icons.add),
            label: const Text('নতুন করণীয় যোগ করুন'),
          ),
          FilledButton.icon(
            onPressed: working ? null : onPublish,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('রোগীর জন্য চালু করুন'),
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
    required this.onEdit,
    required this.onReject,
  });

  final PlanAction action;
  final bool editable;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      padding: const EdgeInsets.all(16),
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
                Text('${_frequencyLabel(action.frequency)} · ${_timingLabel(action)}'),
                if (action.countTarget != null)
                  Text('কতবার: ${action.countTarget}'),
                if (action.durationMinutes != null)
                  Text('সময়: ${action.durationMinutes} মিনিট'),
                if (action.instruction?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(action.instruction!),
                ],
                if (action.resource != null) ...[
                  const SizedBox(height: 8),
                  Text('সহায়ক উপকরণ: ${action.resource!.titleBn ?? action.resource!.title}'),
                ],
              ],
            ),
          ),
          if (editable)
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onReject(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('সংশোধন করুন')),
                PopupMenuItem(value: 'remove', child: Text('বাদ দিন')),
              ],
            ),
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
