import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
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

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _openResource(LinkedResource resource) async {
    await context.push<void>(
      '/patient/resources/${Uri.encodeComponent(resource.id)}',
    );
  }

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
                const SukunPageIntro(
                  eyebrow: 'Personal care',
                  title: 'Your current plan',
                  subtitle: 'Practitioner-approved actions and instructions in one clear view.',
                ),
                const SizedBox(height: 20),
                _PlanHeader(plan: data.plan!),
                const SizedBox(height: 24),
                SukunSectionHeader(
                  title: 'Plan actions',
                  subtitle:
                      '${data.actions.length} approved action${data.actions.length == 1 ? '' : 's'}',
                ),
                const SizedBox(height: 10),
                for (final action in data.actions) ...[
                  _PlanActionCard(
                    action: action,
                    onOpenResource: action.resource == null
                        ? null
                        : () => _openResource(action.resource!),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                const SukunSectionHeader(
                  title: 'Prescription',
                  subtitle: 'Original patient-visible instruction',
                ),
                const SizedBox(height: 10),
                if (data.prescriptions.isEmpty)
                  const SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    child: Text(
                      'No patient-visible prescription is available.',
                    ),
                  )
                else
                  for (final prescription in data.prescriptions) ...[
                    SukunSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SukunIconBadge(
                            icon: Icons.description_outlined,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          Text(prescription.rawText),
                          const SizedBox(height: 8),
                          Text(
                            'Recorded ${_date(prescription.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
    return SukunSurface(
      tone: SukunSurfaceTone.navy,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SukunIconBadge(
                icon: Icons.assignment_turned_in_outlined,
                color: Colors.white,
                backgroundColor: Color(0x3328B8EF),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  plan.name,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
              ),
              const SukunStatusPill(
                label: 'ACTIVE',
                tone: SukunStatusTone.brand,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Version ${plan.version}  ·  ${_date(plan.startDate)} – '
            '${plan.endDate == null ? 'ongoing' : _date(plan.endDate!)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PlanActionCard extends StatelessWidget {
  const _PlanActionCard({required this.action, this.onOpenResource});

  final PlanAction action;
  final VoidCallback? onOpenResource;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SukunIconBadge(icon: Icons.checklist_rounded, size: 42),
              const SizedBox(width: 12),
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
                      '${action.frequency.label} · ${_timeLabel(action)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: SukunColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action.instruction?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(action.instruction!),
          ],
          if (action.resource != null) ...[
            const Divider(height: 26),
            OutlinedButton.icon(
              onPressed: onOpenResource,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text('Open ${action.resource!.title}'),
            ),
          ],
        ],
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
