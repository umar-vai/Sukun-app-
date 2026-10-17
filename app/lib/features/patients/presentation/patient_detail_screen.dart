import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/progress/data/progress_providers.dart';
import 'package:sukun_life/features/progress/domain/adherence_summary.dart';

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

  void _reload() {
    setState(() {
      _details = _load();
    });
  }

  Future<void> _addPrescription() async {
    final created = await context.push<bool>(
      '/admin/patients/${widget.patientId}/prescriptions/new',
    );
    if (!mounted || created != true) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('মূল নির্দেশনা ইতিহাসসহ সংরক্ষিত হয়েছে।')),
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
      '/admin/patients/${widget.patientId}/plans/${plan.id}?addAction=1',
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('রোগীর তথ্য')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context),
        tooltip: 'রোগীর সেবার তথ্য যোগ করুন',
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<(Patient?, List<Prescription>, List<CarePlan>)>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'রোগীর তথ্য আনা হচ্ছে');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: _reload,
            );
          }
          final patient = snapshot.data?.$1;
          if (patient == null) {
            return const AppEmptyState(
              title: 'রোগীকে পাওয়া যায়নি',
              message: 'রোগীর তথ্য সংরক্ষণাগারে থাকতে পারে।',
            );
          }
          final prescriptions = snapshot.data!.$2;
          final plans = snapshot.data!.$3;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
              children: [
                const SukunPageIntro(
                  eyebrow: 'রোগীর সেবা',
                  title: 'রোগীর সারসংক্ষেপ',
                  subtitle: 'সেবা পরিকল্পনা, মূল নির্দেশনা ও অগ্রগতি এক জায়গায় দেখুন।',
                ),
                const SizedBox(height: 18),
                _PatientSummaryCard(patient: patient),
                const SizedBox(height: 14),
                _PatientProgressCard(
                  key: ValueKey(_details),
                  patientId: patient.id,
                ),
                const SizedBox(height: 24),
                SukunSectionHeader(
                  title: 'সেবা পরিকল্পনা',
                  subtitle: 'প্রতিটি সংস্করণের নির্দেশনা ও করণীয়।',
                  action: SukunStatusPill(label: '${plans.length}টি সংস্করণ'),
                ),
                const SizedBox(height: 12),
                if (plans.isEmpty)
                  SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'এখনো সেবা পরিকল্পনা নেই। আগে মূল নির্দেশনা সংরক্ষণ করুন অথবা নিজে পরিকল্পনা সাজান।',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _createPlan,
                          icon: const Icon(Icons.add_task),
                          label: const Text('সেবা পরিকল্পনা তৈরি করুন'),
                        ),
                      ],
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
                SukunSectionHeader(
                  title: 'মূল নির্দেশনা',
                  subtitle: 'মানুষের লেখা মূল প্রেসক্রিপশন বা নির্দেশনা।',
                  action: SukunStatusPill(label: '${prescriptions.length}'),
                ),
                const SizedBox(height: 12),
                if (prescriptions.isEmpty)
                  const SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    child: Text(
                      'এখনো মূল নির্দেশনা নেই। পরিকল্পনা সাজানোর আগে মূল নির্দেশনা যোগ করুন।',
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SukunPageIntro(
                eyebrow: 'রোগীর সেবা',
                title: 'কী যোগ করবেন?',
                subtitle:
                    'মূল নির্দেশনা সংরক্ষণ করুন অথবা খসড়া পরিকল্পনা সাজান।',
              ),
              const SizedBox(height: 18),
              SukunSurface(
                onTap: () => context.pop('prescription'),
                child: const Row(
                  children: [
                    SukunIconBadge(icon: Icons.note_add_outlined),
                    SizedBox(width: 14),
                    Expanded(child: Text('মূল নির্দেশনা যোগ করুন')),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SukunSurface(
                onTap: () => context.pop('plan'),
                child: const Row(
                  children: [
                    SukunIconBadge(icon: Icons.add_task),
                    SizedBox(width: 14),
                    Expanded(child: Text('সেবা পরিকল্পনা তৈরি করুন')),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'prescription') await _addPrescription();
    if (choice == 'plan') await _createPlan();
  }
}

class _PatientProgressCard extends ConsumerStatefulWidget {
  const _PatientProgressCard({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<_PatientProgressCard> createState() =>
      _PatientProgressCardState();
}

class _PatientProgressCardState extends ConsumerState<_PatientProgressCard> {
  late Future<AdherenceSummary> _progress;

  @override
  void initState() {
    super.initState();
    _progress = _load();
  }

  Future<AdherenceSummary> _load() => ref
      .read(progressRepositoryProvider)
      .getPatientProgress(widget.patientId, days: 7);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdherenceSummary>(
      future: _progress,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SukunSurface(child: LinearProgressIndicator());
        }
        if (snapshot.hasError) {
          return SukunSurface(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('অগ্রগতি আনা যাচ্ছে না'),
              trailing: IconButton(
                tooltip: 'আবার চেষ্টা করুন',
                onPressed: () => setState(() {
                  _progress = _load();
                }),
                icon: const Icon(Icons.refresh),
              ),
            ),
          );
        }
        final progress = snapshot.data!;
        final percentage = (progress.completionRate * 100).round();
        return SukunSurface(
          tone: SukunSurfaceTone.navy,
          showBorder: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'গত ৭ দিন',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SukunStatusPill(
                    label: '$percentage% সম্পন্ন',
                    tone: SukunStatusTone.brand,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress.completionRate),
              const SizedBox(height: 10),
              Text(
                '${progress.completed}টি সম্পন্ন · ${progress.skipped}টি বাদ · ${progress.remaining}টি বাকি',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SukunIconBadge(
                icon: Icons.person_outline_rounded,
                size: 58,
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
            label: patient.phone ?? 'ফোন নম্বর নেই',
          ),
          const SizedBox(height: 10),
          _DetailLine(
            icon: Icons.verified_user_outlined,
            label:
                'অবস্থা: ${switch (patient.status) {
                  PatientStatus.active => 'চালু',
                  PatientStatus.inactive => 'নিষ্ক্রিয়',
                  PatientStatus.archived => 'সংরক্ষিত',
                }}',
          ),
        ],
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
    return SukunSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SukunStatusPill(label: prescription.visibility.label),
              if (sessionDate != null)
                SukunStatusPill(label: 'সেশন ${_formatDate(sessionDate)}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(prescription.rawText),
          const SizedBox(height: 12),
          Text(
            'সংরক্ষিত ${_formatDate(prescription.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onBuildPlan,
            icon: const Icon(Icons.add_task),
            label: const Text('সেবা পরিকল্পনা সাজান'),
          ),
        ],
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
    return SukunSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          SukunIconBadge(
            icon: plan.status == CarePlanStatus.active
                ? Icons.assignment_turned_in_outlined
                : Icons.assignment_outlined,
            backgroundColor: plan.status == CarePlanStatus.active
                ? SukunColors.successSoft
                : SukunColors.softBlue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'সংস্করণ ${plan.version} · শুরু ${_formatDate(plan.startDate)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: SukunColors.muted),
                ),
              ],
            ),
          ),
          SukunStatusPill(
            label: switch (plan.status) {
              CarePlanStatus.draft => 'খসড়া',
              CarePlanStatus.active => 'চালু',
              CarePlanStatus.inactive => 'নিষ্ক্রিয়',
              CarePlanStatus.archived => 'সংরক্ষিত',
            },
            tone: plan.status == CarePlanStatus.active
                ? SukunStatusTone.success
                : SukunStatusTone.neutral,
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
