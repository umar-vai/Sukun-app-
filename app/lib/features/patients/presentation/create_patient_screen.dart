import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:uuid/uuid.dart';

class CreatePatientScreen extends ConsumerStatefulWidget {
  const CreatePatientScreen({super.key});

  @override
  ConsumerState<CreatePatientScreen> createState() =>
      _CreatePatientScreenState();
}

class _CreatePatientScreenState extends ConsumerState<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+880');
  final _patientCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _requestId = const Uuid().v4();
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _patientCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final patient = await ref
          .read(patientsRepositoryProvider)
          .createPatient(
            CreatePatientInput(
              fullName: _nameController.text,
              phone: _phoneController.text,
              temporaryPassword: _passwordController.text,
              patientCode: _patientCodeController.text,
              requestId: _requestId,
            ),
          );
      if (!mounted) return;
      await _showSuccess(patient);
      if (mounted) context.pop(patient);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccess(Patient patient) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Patient created'),
        content: Text(
          'Patient ID: ${patient.patientCode}\n\n'
          'Share the temporary sign-in details securely. The patient will be '
          'required to change the temporary credential.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create patient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Patient account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This creates a private patient login. Keep temporary credentials out of notes and messages that are not secure.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: validatePatientName,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      helperText:
                          'International format, such as +8801712345678',
                    ),
                    validator: validateInternationalPhone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _patientCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Patient ID (optional)',
                      helperText: 'Leave blank to generate a unique Sukun ID.',
                    ),
                    validator: validatePatientCode,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Temporary password',
                      helperText: 'Use at least 8 characters.',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: validateTemporaryPassword,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(
                      _submitting ? 'Creating securely…' : 'Create patient',
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
