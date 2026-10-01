import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:uuid/uuid.dart';

class CreateCarePlanScreen extends ConsumerStatefulWidget {
  const CreateCarePlanScreen({
    super.key,
    required this.patientId,
    this.initialPrescriptionId,
    this.copyFromPlanId,
  });

  final String patientId;
  final String? initialPrescriptionId;
  final String? copyFromPlanId;

  @override
  ConsumerState<CreateCarePlanScreen> createState() =>
      _CreateCarePlanScreenState();
}

class _CreateCarePlanScreenState extends ConsumerState<CreateCarePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Care Plan');
  final _requestId = const Uuid().v4();
  late Future<List<Prescription>> _prescriptions;
  late DateTime _startDate;
  DateTime? _endDate;
  String _prescriptionId = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(DateTime.now());
    _prescriptionId = widget.initialPrescriptionId ?? '';
    _prescriptions = ref
        .read(patientsRepositoryProvider)
        .getPrescriptions(widget.patientId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null) return;
    setState(() {
      _startDate = selected;
      if (_endDate?.isBefore(selected) == true) _endDate = null;
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => _endDate = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final plan = await ref
          .read(carePlansRepositoryProvider)
          .createDraft(
            CreateCarePlanInput(
              patientId: widget.patientId,
              name: _nameController.text,
              startDate: _startDate,
              endDate: _endDate,
              prescriptionId: _prescriptionId.isEmpty ? null : _prescriptionId,
              copyFromPlanId: widget.copyFromPlanId,
              requestId: _requestId,
            ),
          );
      if (mounted) context.pop(plan);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewVersion = widget.copyFromPlanId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewVersion ? 'Create new version' : 'Create care plan'),
      ),
      body: FutureBuilder<List<Prescription>>(
        future: _prescriptions,
        builder: (context, snapshot) {
          final prescriptions = snapshot.data ?? const <Prescription>[];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isNewVersion) ...[
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Actions and resource links will be copied into a new draft. Every copied action is marked “Needs review” and must be approved again before publishing.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Plan name',
                        ),
                        validator: validatePlanName,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _prescriptionId,
                        decoration: const InputDecoration(
                          labelText: 'Source prescription',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('No prescription selected'),
                          ),
                          for (final prescription in prescriptions)
                            DropdownMenuItem(
                              value: prescription.id,
                              child: Text(
                                prescription.rawText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _prescriptionId = value ?? ''),
                      ),
                      const SizedBox(height: 14),
                      _DateTile(
                        label: 'Start date',
                        value: _startDate,
                        onTap: _pickStartDate,
                      ),
                      const SizedBox(height: 10),
                      _DateTile(
                        label: 'End date',
                        value: _endDate,
                        onTap: _pickEndDate,
                        onClear: _endDate == null
                            ? null
                            : () => setState(() => _endDate = null),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_task),
                        label: Text(
                          _submitting ? 'Creating draft…' : 'Create draft plan',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: Text(label),
        subtitle: Text(value == null ? 'No end date' : _formatDate(value!)),
        trailing: onClear == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                onPressed: onClear,
                tooltip: 'Clear date',
                icon: const Icon(Icons.close),
              ),
        onTap: onTap,
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
