import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

class MyPlanScreen extends ConsumerStatefulWidget {
  const MyPlanScreen({super.key});

  @override
  ConsumerState<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends ConsumerState<MyPlanScreen> {
  late Future<_MyPlanData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_MyPlanData> _load() async {
    final repository = ref.read(patientCareRepositoryProvider);
    final plan = await repository.getActivePlan();
    final results = await Future.wait<Object?>([
      if (plan == null)
        Future.value(<PlanAction>[])
      else
        repository.getActivePlanActions(plan.id),
      repository.getVisiblePrescriptions(),
    ]);
    return _MyPlanData(
      plan: plan,
      actions: results[0] as List<PlanAction>,
      prescriptions: results[1] as List<Prescription>,
    );
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      title: 'My Plan',
      selectedIndex: 1,
      body: FutureBuilder<_MyPlanData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading your care plan');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          if (data.plan == null) {
            return const AppEmptyState(
              title: 'No active plan',
              message: 'Your practitioner has not published a care plan yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _PlanHeader(plan: data.plan!),
                const SizedBox(height: 24),
                Text(
                  'Plan actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final action in data.actions) ...[
                  _PlanActionCard(action: action),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                Text(
                  'Prescription',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (data.prescriptions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No patient-visible prescription is available.',
                      ),
                    ),
                  )
                else
                  for (final prescription in data.prescriptions) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prescription.rawText),
                            const SizedBox(height: 8),
                            Text(
                              'Recorded ${_date(prescription.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MyPlanData {
  const _MyPlanData({
    required this.plan,
    required this.actions,
    required this.prescriptions,
  });

  final CarePlan? plan;
  final List<PlanAction> actions;
  final List<Prescription> prescriptions;
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SukunColors.mist,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('Version ${plan.version} · active'),
            const SizedBox(height: 8),
            Text(
              '${_date(plan.startDate)} – '
              '${plan.endDate == null ? 'ongoing' : _date(plan.endDate!)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanActionCard extends StatelessWidget {
  const _PlanActionCard({required this.action});

  final PlanAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text('${action.frequency.label} · ${_timeLabel(action)}'),
            if (action.instruction?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(action.instruction!),
            ],
            if (action.resource != null) ...[
              const Divider(height: 26),
              Row(
                children: [
                  const Icon(Icons.library_books_outlined, size: 19),
                  const SizedBox(width: 8),
                  Expanded(child: Text(action.resource!.title)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _timeLabel(PlanAction action) {
  if (action.exactTime != null) {
    return '${action.exactTime!.hour.toString().padLeft(2, '0')}:'
        '${action.exactTime!.minute.toString().padLeft(2, '0')}';
  }
  return action.timeWindow ?? 'Any time';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
