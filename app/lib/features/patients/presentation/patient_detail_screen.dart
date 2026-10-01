import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
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
  late Future<(Patient?, List<Prescription>)> _details;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<(Patient?, List<Prescription>)> _load() async {
    final repository = ref.read(patientsRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.getPatient(widget.patientId),
      repository.getPrescriptions(widget.patientId),
    ]);
    return (results[0] as Patient?, results[1] as List<Prescription>);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient details')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPrescription,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Add prescription'),
      ),
      body: FutureBuilder<(Patient?, List<Prescription>)>(
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
                    _PrescriptionCard(prescription: prescription),
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
  const _PrescriptionCard({required this.prescription});

  final Prescription prescription;

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
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
