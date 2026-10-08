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
    return AdminScaffold(
      title: 'রোগীদের তালিকা',
      selectedIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPatient,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('নতুন রোগী যোগ করুন'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              children: [
                const SukunPageIntro(
                  eyebrow: 'রোগীর তথ্য',
                  title: 'রোগী খুঁজুন',
                  subtitle: 'রোগী খুঁজে তথ্য দেখুন অথবা নতুন রোগী যোগ করুন।',
                ),
                const SizedBox(height: 18),
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
                    message: 'রোগীদের তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
                    onRetry: _reload,
                  );
                }
                final patients = snapshot.data ?? const <Patient>[];
                if (patients.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'কোনো রোগী পাওয়া যায়নি',
                    message: 'অন্য নাম বা নম্বর দিয়ে খুঁজুন, অথবা নতুন রোগী যোগ করুন।',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
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
                              label: 'চালু',
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
