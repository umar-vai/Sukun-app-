import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:uuid/uuid.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

class CreatePrescriptionScreen extends ConsumerStatefulWidget {
  const CreatePrescriptionScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState
    extends ConsumerState<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _requestId = const Uuid().v4();
  DateTime? _sessionDate;
  bool _patientVisible = true;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _sessionDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (selected != null) setState(() => _sessionDate = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(patientsRepositoryProvider)
          .createPrescription(
            CreatePrescriptionInput(
              patientId: widget.patientId,
              rawText: _textController.text,
              visibility: _patientVisible
                  ? PrescriptionVisibility.patient
                  : PrescriptionVisibility.staffOnly,
              sessionDate: _sessionDate,
              requestId: _requestId,
            ),
          );
      if (mounted) context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('প্রেসক্রিপশন সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record prescription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SukunPageIntro(
                    eyebrow: 'Source record',
                    title: 'Record the prescription',
                    subtitle: 'Preserve the practitioner’s original human-authored instruction before creating structured actions.',
                  ),
                  const SizedBox(height: 20),
                  const SukunSurface(
                    tone: SukunSurfaceTone.warning,
                    showBorder: false,
                    radius: 18,
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enter the original instruction exactly. Never add a dose, repetition, exact time, or ruling that was not supplied.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SukunSurface(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _textController,
                          minLines: 7,
                          maxLines: 14,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Original prescription / instruction',
                            alignLabelWithHint: true,
                          ),
                          validator: validatePrescriptionText,
                        ),
                        const SizedBox(height: 14),
                        SukunSurface(
                          radius: 18,
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.event_outlined),
                            title: const Text('Session date'),
                            subtitle: Text(
                              _sessionDate == null
                                  ? 'Not specified'
                                  : _formatDate(_sessionDate!),
                            ),
                            trailing: _sessionDate == null
                                ? const Icon(Icons.chevron_right)
                                : IconButton(
                                    tooltip: 'Clear date',
                                    onPressed: () =>
                                        setState(() => _sessionDate = null),
                                    icon: const Icon(Icons.close),
                                  ),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          value: _patientVisible,
                          onChanged: (value) =>
                              setState(() => _patientVisible = value),
                          title: const Text('Visible to patient'),
                          subtitle: Text(
                            _patientVisible
                                ? 'The patient may read this prescription.'
                                : 'Staff-only notes are hidden from the patient.',
                          ),
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
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _submitting ? 'Saving…' : 'Save prescription',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
