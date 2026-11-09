import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/patients/presentation/patient_status_ui.dart';
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
  _DetailTab _tab = _DetailTab.summary;

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
    if (!mounted) return;
    // The AI flow may end on the plan builder instead of returning a
    // result, so refresh plans and prescriptions either way.
    _reload();
    if (created != true) return;
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
      // The two clinical actions are always one tap away instead of being
      // hidden behind a "+" menu.
      bottomNavigationBar: _PatientActionBar(
        onAddPrescription: _addPrescription,
        onCreatePlan: _createPlan,
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
          final activePlans = plans
              .where((plan) => plan.status == CarePlanStatus.active)
              .toList(growable: false);

          Widget planCard(CarePlan plan) => _CarePlanCard(
            plan: plan,
            onTap: () async {
              await context.push<void>(
                '/admin/patients/${widget.patientId}/plans/${plan.id}',
              );
              if (mounted) _reload();
            },
          );

          final tabContent = switch (_tab) {
            _DetailTab.summary => <Widget>[
              _PatientProgressCard(
                key: ValueKey(_details),
                patientId: patient.id,
              ),
              const SizedBox(height: SukunSpace.section),
              SukunSectionHeader(
                title: 'চালু পরিকল্পনা',
                action: plans.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () =>
                            setState(() => _tab = _DetailTab.plans),
                        child: const Text('সব সংস্করণ'),
                      ),
              ),
              const SizedBox(height: SukunSpace.md),
              if (plans.isEmpty)
                _EmptyPlans(onCreatePlan: _createPlan)
              else if (activePlans.isEmpty)
                const _SoftNote(
                  text:
                      'এখন কোনো পরিকল্পনা চালু নেই। "পরিকল্পনা" ট্যাবে খসড়া '
                      'ও পুরনো সংস্করণ দেখুন।',
                )
              else
                for (final plan in activePlans) ...[
                  planCard(plan),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: SukunSpace.section),
              SukunSectionHeader(
                title: 'সর্বশেষ মূল নির্দেশনা',
                action: prescriptions.length > 1
                    ? TextButton(
                        onPressed: () =>
                            setState(() => _tab = _DetailTab.prescriptions),
                        child: Text('সব (${prescriptions.length})'),
                      )
                    : null,
              ),
              const SizedBox(height: SukunSpace.md),
              if (prescriptions.isEmpty)
                const _SoftNote(
                  text:
                      'এখনো মূল নির্দেশনা নেই। পরিকল্পনা সাজানোর আগে মূল '
                      'নির্দেশনা যোগ করুন।',
                )
              else
                _PrescriptionCard(
                  prescription: prescriptions.first,
                  onBuildPlan: () =>
                      _createPlan(prescriptionId: prescriptions.first.id),
                ),
            ],
            _DetailTab.plans => <Widget>[
              SukunSectionHeader(
                title: 'সেবা পরিকল্পনা',
                subtitle: 'প্রতিটি সংস্করণের নির্দেশনা ও করণীয়।',
                action: SukunStatusPill(label: '${plans.length}টি সংস্করণ'),
              ),
              const SizedBox(height: SukunSpace.md),
              if (plans.isEmpty)
                _EmptyPlans(onCreatePlan: _createPlan)
              else
                for (final plan in plans) ...[
                  planCard(plan),
                  const SizedBox(height: 10),
                ],
            ],
            _DetailTab.prescriptions => <Widget>[
              SukunSectionHeader(
                title: 'মূল নির্দেশনা',
                subtitle: 'মানুষের লেখা মূল প্রেসক্রিপশন বা নির্দেশনা।',
                action: SukunStatusPill(label: '${prescriptions.length}'),
              ),
              const SizedBox(height: SukunSpace.md),
              if (prescriptions.isEmpty)
                const _SoftNote(
                  text:
                      'এখনো মূল নির্দেশনা নেই। পরিকল্পনা সাজানোর আগে মূল '
                      'নির্দেশনা যোগ করুন।',
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
          };

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SukunSpace.page,
                    SukunSpace.xs,
                    SukunSpace.page,
                    SukunSpace.section,
                  ),
                  children: [
                    _PatientHeader(patient: patient),
                    const SizedBox(height: SukunSpace.page),
                    _DetailTabs(
                      selected: _tab,
                      planCount: plans.length,
                      prescriptionCount: prescriptions.length,
                      onSelected: (tab) => setState(() => _tab = tab),
                    ),
                    const SizedBox(height: SukunSpace.page),
                    ...tabContent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _DetailTab { summary, plans, prescriptions }

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.selected,
    required this.planCount,
    required this.prescriptionCount,
    required this.onSelected,
  });

  final _DetailTab selected;
  final int planCount;
  final int prescriptionCount;
  final ValueChanged<_DetailTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = {
      _DetailTab.summary: 'সারাংশ',
      _DetailTab.plans: 'পরিকল্পনা ($planCount)',
      _DetailTab.prescriptions: 'নির্দেশনা ($prescriptionCount)',
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SukunColors.mist,
        borderRadius: BorderRadius.circular(SukunRadius.control + 2),
      ),
      child: Row(
        children: [
          for (final tab in _DetailTab.values)
            Expanded(
              child: Semantics(
                selected: tab == selected,
                button: true,
                child: InkWell(
                  key: Key('patient-detail-tab-${tab.name}'),
                  borderRadius: BorderRadius.circular(SukunRadius.control - 2),
                  onTap: () => onSelected(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 42),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: tab == selected ? Colors.white : null,
                      borderRadius: BorderRadius.circular(
                        SukunRadius.control - 2,
                      ),
                      boxShadow: tab == selected
                          ? [
                              BoxShadow(
                                color: SukunColors.nightNavy.withValues(
                                  alpha: 0.10,
                                ),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[tab]!,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: tab == selected
                              ? SukunColors.nightNavy
                              : SukunColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientActionBar extends StatelessWidget {
  const _PatientActionBar({
    required this.onAddPrescription,
    required this.onCreatePlan,
  });

  final VoidCallback onAddPrescription;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      boxShadow: [
        BoxShadow(
          color: SukunColors.nightNavy.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        SukunSpace.page,
        SukunSpace.md,
        SukunSpace.page,
        SukunSpace.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('patient-detail-add-prescription'),
              onPressed: onAddPrescription,
              icon: const Icon(Icons.note_add_outlined),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('মূল নির্দেশনা যোগ করুন'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              key: const Key('patient-detail-create-plan'),
              onPressed: onCreatePlan,
              icon: const Icon(Icons.add_task),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('সেবা পরিকল্পনা তৈরি করুন'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) => SukunSurface(
    tone: SukunSurfaceTone.soft,
    showBorder: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'এখনো সেবা পরিকল্পনা নেই। আগে মূল নির্দেশনা সংরক্ষণ করুন অথবা '
          'নিজে পরিকল্পনা সাজান।',
        ),
        const SizedBox(height: SukunSpace.md),
        OutlinedButton.icon(
          onPressed: onCreatePlan,
          icon: const Icon(Icons.add_task),
          label: const Text('সেবা পরিকল্পনা তৈরি করুন'),
        ),
      ],
    ),
  );
}

class _SoftNote extends StatelessWidget {
  const _SoftNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SukunSurface(
    tone: SukunSurfaceTone.soft,
    showBorder: false,
    padding: const EdgeInsets.all(SukunSpace.lg),
    child: Text(text),
  );
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        PatientInitialAvatar(name: patient.fullName, size: 60),
        const SizedBox(width: SukunSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.fullName,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                patient.patientCode,
                style: textTheme.bodyMedium?.copyWith(
                  color: SukunColors.deepTide,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: SukunSpace.sm,
                runSpacing: SukunSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SukunStatusPill(
                    label: 'অবস্থা: ${patientStatusLabel(patient.status)}',
                    tone: patientStatusTone(patient.status),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: SukunColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        patient.phone ?? 'ফোন নম্বর নেই',
                        style: textTheme.bodySmall?.copyWith(
                          color: SukunColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
        final textTheme = Theme.of(context).textTheme;
        return SukunSurface(
          key: const Key('patient-detail-progress'),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress.completionRate,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        backgroundColor: SukunColors.mist,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SukunSpace.lg + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'গত ৭ দিন',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$percentage% সম্পন্ন',
                      style: textTheme.bodySmall?.copyWith(
                        color: SukunColors.deepTide,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: SukunSpace.sm),
                    Text(
                      '${progress.completed}টি সম্পন্ন · ${progress.skipped}টি বাদ · ${progress.remaining}টি বাকি',
                      style: textTheme.bodySmall?.copyWith(
                        color: SukunColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
              SukunStatusPill(
                label: switch (prescription.visibility) {
                  PrescriptionVisibility.patient => 'রোগী দেখতে পারবেন',
                  PrescriptionVisibility.staffOnly => 'শুধু স্টাফ',
                },
                icon:
                    prescription.visibility == PrescriptionVisibility.staffOnly
                    ? Icons.lock_outline_rounded
                    : Icons.visibility_outlined,
                tone:
                    prescription.visibility == PrescriptionVisibility.staffOnly
                    ? SukunStatusTone.neutral
                    : SukunStatusTone.brand,
              ),
              if (sessionDate != null)
                SukunStatusPill(label: 'সেশন ${_formatDate(sessionDate)}'),
            ],
          ),
          const SizedBox(height: SukunSpace.md),
          Text(
            prescription.rawText,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            'সংরক্ষিত ${_formatDate(prescription.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SukunColors.muted),
          ),
          const SizedBox(height: SukunSpace.md),
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
      radius: SukunRadius.tile + 2,
      padding: const EdgeInsets.all(SukunSpace.lg),
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
