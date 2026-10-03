import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:uuid/uuid.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

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
    return showSukunDecisionDialog(
      context: context,
      barrierDismissible: false,
      showCancel: false,
      title: 'Patient created',
      message:
          'Patient ID: ${patient.patientCode}\n\n'
          'Share the temporary sign-in details securely. The patient will be '
          'required to change the temporary credential.',
      confirmLabel: 'Done',
      icon: Icons.person_add_alt_1_rounded,
    ).then((_) {});
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
                  const SukunPageIntro(
                    eyebrow: 'Secure onboarding',
                    title: 'Create a patient account',
                    subtitle: 'Create a private login and share the temporary credential through a secure channel.',
                  ),
                  const SizedBox(height: 24),
                  SukunSurface(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: validatePatientName,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone_outlined),
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
                            prefixIcon: Icon(Icons.badge_outlined),
                            helperText:
                                'Leave blank to generate a unique Sukun ID.',
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
                            prefixIcon: const Icon(Icons.key_outlined),
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
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            _submitting
                                ? 'Creating securely…'
                                : 'Create patient',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    radius: 18,
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The patient must replace the temporary password before private care information opens.',
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
