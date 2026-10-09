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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'রোগীর অ্যাকাউন্ট তৈরি করা যায়নি। তথ্যগুলো দেখে আবার চেষ্টা করুন।',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccess(Patient patient) {
    return showSukunDecisionDialog(
      context: context,
      barrierDismissible: false,
      showCancel: false,
      title: 'রোগীর অ্যাকাউন্ট তৈরি হয়েছে',
      message:
          'রোগী নম্বর: ${patient.patientCode}\n\n'
          'অস্থায়ী লগইন তথ্য নিরাপদভাবে রোগীকে দিন। রোগী প্রথমবার প্রবেশের সময় '
          'নিজের পাসওয়ার্ড তৈরি করবেন।',
      confirmLabel: 'ঠিক আছে',
      icon: Icons.person_add_alt_1_rounded,
    ).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন রোগী যোগ করুন')),
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
                    eyebrow: 'নতুন অ্যাকাউন্ট',
                    title: 'নতুন রোগীর তথ্য দিন',
                    subtitle: 'রোগীর জন্য অ্যাকাউন্ট খুলুন এবং অস্থায়ী পাসওয়ার্ড নিরাপদে জানান।',
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
                            labelText: 'রোগীর পুরো নাম',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              validatePatientName(value) == null
                              ? null
                              : 'রোগীর পুরো নাম লিখুন।',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: 'ফোন নম্বর',
                            prefixIcon: Icon(Icons.phone_outlined),
                            helperText: 'যেমন: +8801712345678',
                          ),
                          validator: (value) =>
                              validateInternationalPhone(value) == null
                              ? null
                              : 'দেশের কোডসহ সঠিক ফোন নম্বর লিখুন।',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _patientCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'রোগী নম্বর (না দিলেও হবে)',
                            prefixIcon: Icon(Icons.badge_outlined),
                            helperText:
                                'ফাঁকা রাখলে নিজে থেকেই নতুন নম্বর তৈরি হবে।',
                          ),
                          validator: (value) =>
                              validatePatientCode(value) == null
                              ? null
                              : 'রোগী নম্বরটি সঠিকভাবে লিখুন অথবা ফাঁকা রাখুন।',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'অস্থায়ী পাসওয়ার্ড',
                            prefixIcon: const Icon(Icons.key_outlined),
                            helperText: 'অন্তত ৮ অক্ষরের পাসওয়ার্ড দিন।',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'পাসওয়ার্ড দেখুন'
                                  : 'পাসওয়ার্ড লুকান',
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
                          validator: (value) =>
                              validateTemporaryPassword(value) == null ? null : 'কমপক্ষে ৮ অক্ষরের একটি অস্থায়ী পাসওয়ার্ড লিখুন।',
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
                                ? 'রোগীর অ্যাকাউন্ট তৈরি হচ্ছে…'
                                : 'রোগী যোগ করুন',
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
                            'ব্যক্তিগত তথ্য দেখার আগে রোগীকে অস্থায়ী পাসওয়ার্ড বদলাতে হবে।',
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
