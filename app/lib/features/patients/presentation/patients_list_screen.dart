import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
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

  void _reload() => setState(() => _patients = _search());

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search name, phone, or patient ID',
              leading: const Icon(Icons.search),
              trailing: [
                IconButton(
                  tooltip: 'Search',
                  onPressed: _reload,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
              onSubmitted: (_) => _reload(),
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
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: SukunColors.mist,
                            foregroundColor: SukunColors.deepTide,
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(patient.fullName),
                          subtitle: Text(
                            '${patient.patientCode}\n${patient.phone ?? 'No phone'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/admin/patients/${patient.id}'),
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
