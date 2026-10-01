import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

class CarePlanPreviewScreen extends ConsumerStatefulWidget {
  const CarePlanPreviewScreen({
    super.key,
    required this.patientId,
    required this.planId,
  });

  final String patientId;
  final String planId;

  @override
  ConsumerState<CarePlanPreviewScreen> createState() =>
      _CarePlanPreviewScreenState();
}

class _CarePlanPreviewScreenState extends ConsumerState<CarePlanPreviewScreen> {
  late Future<(CarePlan, List<PlanAction>)> _preview;

  @override
  void initState() {
    super.initState();
    _preview = _load();
  }

  Future<(CarePlan, List<PlanAction>)> _load() async {
    final repository = ref.read(carePlansRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.getPlan(widget.planId),
      repository.getActions(widget.planId),
    ]);
    final plan = results[0] as CarePlan?;
    if (plan == null || plan.patientId != widget.patientId) {
      throw const CarePlanWorkflowException('Care plan was not found.');
    }
    final actions = (results[1] as List<PlanAction>)
        .where((action) => action.reviewStatus == ActionReviewStatus.approved)
        .toList(growable: false);
    return (plan, actions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient preview')),
      backgroundColor: SukunColors.mist,
      body: FutureBuilder<(CarePlan, List<PlanAction>)>(
        future: _preview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Preparing patient preview');
          }
          if (snapshot.hasError) {
            return AppErrorState(message: snapshot.error.toString());
          }
          final (plan, actions) = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
              if (plan.status == CarePlanStatus.draft) ...[
                const Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Preview only. The patient cannot see this draft until it is reviewed and published.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Your care plan',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Starting ${_formatDate(plan.startDate)}'),
              const SizedBox(height: 24),
              Text(
                "Today's actions",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (actions.isEmpty)
                const Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No approved actions are available in this preview yet.',
                    ),
                  ),
                )
              else
                for (final action in actions) ...[
                  _PatientActionCard(action: action),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _PatientActionCard extends StatelessWidget {
  const _PatientActionCard({required this.action});

  final PlanAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: SukunColors.mist,
                  foregroundColor: SukunColors.deepTide,
                  child: Icon(Icons.check_circle_outline),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${action.frequency.label} · ${_timingLabel(action, context)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action.instruction?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Text(action.instruction!),
            ],
            if (action.countTarget != null ||
                action.durationMinutes != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  if (action.countTarget != null)
                    Chip(label: Text('${action.countTarget} repetitions')),
                  if (action.durationMinutes != null)
                    Chip(label: Text('${action.durationMinutes} minutes')),
                ],
              ),
            ],
            if (action.resource != null) ...[
              const Divider(height: 28),
              Row(
                children: [
                  const Icon(Icons.library_books_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(action.resource!.title)),
                ],
              ),
              if (action.resource!.usageNote?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(action.resource!.usageNote!),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _timingLabel(PlanAction action, BuildContext context) {
  if (action.exactTime != null) {
    return TimeOfDay.fromDateTime(action.exactTime!).format(context);
  }
  final value = action.timeWindow;
  if (value == null || value.isEmpty) return 'Time not specified';
  return value[0].toUpperCase() + value.substring(1);
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
