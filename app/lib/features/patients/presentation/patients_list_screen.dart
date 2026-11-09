import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/presentation/patient_status_ui.dart';

class PatientsListScreen extends ConsumerStatefulWidget {
  const PatientsListScreen({super.key});

  @override
  ConsumerState<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends ConsumerState<PatientsListScreen> {
  final _searchController = TextEditingController();
  late Future<List<Patient>> _patients;
  PatientStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _patients = _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Patient>> _search() {
    return ref
        .read(patientsRepositoryProvider)
        .searchPatients(query: _searchController.text);
  }

  Future<void> _refresh() async {
    final future = _search();
    setState(() {
      _patients = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the retry state.
    }
  }

  void _reload() {
    _refresh();
  }

  Future<void> _createPatient() async {
    final created = await context.push<Patient>('/admin/patients/new');
    if (!mounted || created == null) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.fullName}-এর অ্যাকাউন্ট তৈরি হয়েছে।')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AdminScaffold(
      title: 'রোগীদের তালিকা',
      // Patients live under the Users area, so its tab stays highlighted.
      selectedIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPatient,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('নতুন রোগী যোগ করুন'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SukunSpace.page,
                  SukunSpace.xs,
                  SukunSpace.page,
                  SukunSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'রোগী খুঁজুন',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: SukunSpace.xs),
                    Text(
                      'রোগী খুঁজে তথ্য দেখুন অথবা নতুন রোগী যোগ করুন।',
                      style: textTheme.bodyMedium?.copyWith(
                        color: SukunColors.muted,
                      ),
                    ),
                    const SizedBox(height: SukunSpace.lg),
                    SukunSearchField(
                      controller: _searchController,
                      hintText: 'নাম, ফোন বা রোগী নম্বর লিখুন',
                      onSubmitted: (_) => _reload(),
                      onClear: () {
                        _searchController.clear();
                        _reload();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Patient>>(
                  future: _patients,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoadingState(
                        label: 'রোগীদের তথ্য আনা হচ্ছে…',
                      );
                    }
                    if (snapshot.hasError) {
                      return AppErrorState(
                        message:
                            'রোগীদের তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
                        onRetry: _reload,
                      );
                    }
                    final patients = snapshot.data ?? const <Patient>[];
                    if (patients.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.people_outline,
                        title: 'কোনো রোগী পাওয়া যায়নি',
                        message: 'অন্য নাম বা নম্বর দিয়ে খুঁজুন, অথবা নতুন রোগী যোগ করুন।',
                      );
                    }
                    final visible = _statusFilter == null
                        ? patients
                        : patients
                              .where((p) => p.status == _statusFilter)
                              .toList(growable: false);
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          SukunSpace.page,
                          SukunSpace.xs,
                          SukunSpace.page,
                          112,
                        ),
                        children: [
                          _StatusFilters(
                            patients: patients,
                            selected: _statusFilter,
                            onSelected: (status) =>
                                setState(() => _statusFilter = status),
                          ),
                          const SizedBox(height: SukunSpace.md),
                          if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: SukunSpace.section,
                              ),
                              child: Text(
                                'এই অবস্থায় কোনো রোগী নেই।',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: SukunColors.muted,
                                ),
                              ),
                            ),
                          for (final patient in visible) ...[
                            _PatientRow(
                              patient: patient,
                              onTap: () =>
                                  context.push('/admin/patients/${patient.id}'),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Client-side filter over the patients already loaded by the search. It
/// never widens what the server returned.
class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.patients,
    required this.selected,
    required this.onSelected,
  });

  final List<Patient> patients;
  final PatientStatus? selected;
  final ValueChanged<PatientStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(PatientStatus status) =>
        patients.where((p) => p.status == status).length;
    return Wrap(
      spacing: SukunSpace.sm,
      runSpacing: SukunSpace.sm,
      children: [
        SukunFilterPill(
          key: const Key('patients-filter-all'),
          label: 'সব · ${patients.length}',
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final status in PatientStatus.values)
          if (count(status) > 0 || selected == status)
            SukunFilterPill(
              key: Key('patients-filter-${status.name}'),
              label: '${patientStatusLabel(status)} · ${count(status)}',
              selected: selected == status,
              onTap: () => onSelected(status),
            ),
      ],
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SukunSurface(
      padding: const EdgeInsets.all(14),
      radius: SukunRadius.tile + 2,
      onTap: onTap,
      child: Row(
        children: [
          PatientInitialAvatar(name: patient.fullName),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  patient.phone == null
                      ? patient.patientCode
                      : '${patient.patientCode} · ${patient.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: SukunColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SukunStatusPill(
            label: patientStatusLabel(patient.status),
            tone: patientStatusTone(patient.status),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8AA3B5)),
        ],
      ),
    );
  }
}
