import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your new password is ready.')),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure your account'),
        actions: [
          IconButton(
            onPressed: _submitting
                ? null
                : () => ref.read(authRepositoryProvider).signOut(),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SukunIconBadge(
                    icon: Icons.lock_reset_rounded,
                    size: 62,
                  ),
                  const SizedBox(height: 18),
                  const SukunPageIntro(
                    eyebrow: 'First sign in',
                    title: 'Create your private password',
                    subtitle: 'Replace the temporary password before opening patient information. This protects your private care account.',
                  ),
                  const SizedBox(height: 24),
                  SukunSurface(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _currentController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Temporary password',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                          validator: validateAccountPassword,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _newController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'New password',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          validator: validateAccountPassword,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                          validator: (value) => validateConfirmedPassword(
                            _newController.text,
                            value ?? '',
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.shield_outlined),
                          label: Text(
                            _submitting ? 'Updating…' : 'Secure my account',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    radius: 18,
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: SukunColors.deepTide),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Use at least 8 characters and do not reuse your temporary password.',
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
