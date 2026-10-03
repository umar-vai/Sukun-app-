import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';

class PatientsListScreen extends ConsumerStatefulWidget {
  const PatientsListScreen({super.key});

  @override
  ConsumerState<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends ConsumerState<PatientsListScreen> {
  final _searchController = TextEditingController();
  late Future<List<Patient>> _patients;

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

  void _reload() {
    setState(() {
      _patients = _search();
    });
  }

  Future<void> _createPatient() async {
    final created = await context.push<Patient>('/admin/patients/new');
    if (!mounted || created == null) return;
    _reload();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.fullName} was created.')));
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Patients',
      selectedIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPatient,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add patient'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              children: [
                const SukunPageIntro(
                  eyebrow: 'Patient care',
                  title: 'Patients',
                  subtitle: 'Find a patient, review their history, or start a new care workflow.',
                ),
                const SizedBox(height: 18),
                SukunSearchField(
                  controller: _searchController,
                  hintText: 'Search name, phone, or patient ID',
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
                  return const AppLoadingState(label: 'Loading patients');
                }
                if (snapshot.hasError) {
                  return AppErrorState(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }
                final patients = snapshot.data ?? const <Patient>[];
                if (patients.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No patients found',
                    message: 'Add a patient or try a different search.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
                    itemCount: patients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      return SukunSurface(
                        padding: const EdgeInsets.all(16),
                        onTap: () =>
                            context.push('/admin/patients/${patient.id}'),
                        child: Row(
                          children: [
                            const SukunIconBadge(
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient.fullName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    patient.patientCode,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: SukunColors.deepTide),
                                  ),
                                  if (patient.phone != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      patient.phone!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: SukunColors.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SukunStatusPill(
                              label: 'ACTIVE',
                              tone: SukunStatusTone.success,
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: SukunColors.deepTide,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
