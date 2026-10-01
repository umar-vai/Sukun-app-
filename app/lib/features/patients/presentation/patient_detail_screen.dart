import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  late Future<(Patient?, List<Prescription>, List<CarePlan>)> _details;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<(Patient?, List<Prescription>, List<CarePlan>)> _load() async {
    final repository = ref.read(patientsRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.getPatient(widget.patientId),
      repository.getPrescriptions(widget.patientId),
      ref.read(carePlansRepositoryProvider).getPatientPlans(widget.patientId),
    ]);
    return (
      results[0] as Patient?,
      results[1] as List<Prescription>,
      results[2] as List<CarePlan>,
    );
  }

  void _reload() => setState(() => _details = _load());

  Future<void> _addPrescription() async {
    final created = await context.push<bool>(
      '/admin/patients/${widget.patientId}/prescriptions/new',
    );
    if (!mounted || created != true) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prescription saved with version history.')),
    );
  }

  Future<void> _createPlan({String? prescriptionId}) async {
    final query = prescriptionId == null
        ? ''
        : '?prescriptionId=${Uri.encodeQueryComponent(prescriptionId)}';
    final plan = await context.push<CarePlan>(
      '/admin/patients/${widget.patientId}/plans/new$query',
    );
    if (!mounted || plan == null) return;
    _reload();
    await context.push<void>(
      '/admin/patients/${widget.patientId}/plans/${plan.id}',
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient details')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context),
        tooltip: 'Add patient care record',
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<(Patient?, List<Prescription>, List<CarePlan>)>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading patient details');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final patient = snapshot.data?.$1;
          if (patient == null) {
            return const AppEmptyState(
              title: 'Patient not found',
              message: 'This patient may have been archived or removed.',
            );
          }
          final prescriptions = snapshot.data!.$2;
          final plans = snapshot.data!.$3;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
              children: [
                _PatientSummaryCard(patient: patient),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Care plans',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${plans.length} version${plans.length == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (plans.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No care plan has been created yet. Record a prescription first, or build a plan manually.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _createPlan,
                            icon: const Icon(Icons.add_task),
                            label: const Text('Create care plan'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final plan in plans) ...[
                    _CarePlanCard(
                      plan: plan,
                      onTap: () async {
                        await context.push<void>(
                          '/admin/patients/${widget.patientId}/plans/${plan.id}',
                        );
                        if (mounted) _reload();
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Prescriptions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text('${prescriptions.length}'),
                  ],
                ),
                const SizedBox(height: 12),
                if (prescriptions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No prescription has been recorded yet. Add the original human-authored instruction before building a care plan.',
                      ),
                    ),
                  )
                else
                  for (final prescription in prescriptions) ...[
                    _PrescriptionCard(
                      prescription: prescription,
                      onBuildPlan: () =>
                          _createPlan(prescriptionId: prescription.id),
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

  Future<void> _showCreateMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Add prescription'),
              onTap: () => context.pop('prescription'),
            ),
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text('Create care plan'),
              onTap: () => context.pop('plan'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'prescription') await _addPrescription();
    if (choice == 'plan') await _createPlan();
  }
}

class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: SukunColors.mist,
                  foregroundColor: SukunColors.deepTide,
                  child: Icon(Icons.person_outline, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(patient.patientCode),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _DetailLine(
              icon: Icons.phone_outlined,
              label: patient.phone ?? 'No phone number',
            ),
            const SizedBox(height: 10),
            _DetailLine(
              icon: Icons.verified_user_outlined,
              label: 'Status: ${patient.status.name}',
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: SukunColors.deepTide),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.prescription,
    required this.onBuildPlan,
  });

  final Prescription prescription;
  final VoidCallback onBuildPlan;

  @override
  Widget build(BuildContext context) {
    final sessionDate = prescription.sessionDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(prescription.visibility.label)),
                if (sessionDate != null)
                  Chip(label: Text('Session ${_formatDate(sessionDate)}')),
              ],
            ),
            const SizedBox(height: 10),
            Text(prescription.rawText),
            const SizedBox(height: 12),
            Text(
              'Recorded ${_formatDate(prescription.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onBuildPlan,
              icon: const Icon(Icons.add_task),
              label: const Text('Build care plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarePlanCard extends StatelessWidget {
  const _CarePlanCard({required this.plan, required this.onTap});

  final CarePlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: plan.status == CarePlanStatus.active
              ? SukunColors.sukunBlue
              : SukunColors.mist,
          foregroundColor: plan.status == CarePlanStatus.active
              ? Colors.white
              : SukunColors.deepTide,
          child: Text('${plan.version}'),
        ),
        title: Text(plan.name),
        subtitle: Text(
          'Version ${plan.version} · ${plan.status.label} · starts ${_formatDate(plan.startDate)}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
