import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(
            identifier: _identifierController.text,
            password: _passwordController.text,
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(child: SukunLifeLogo(height: 96)),
                  const SizedBox(height: 24),
                  const SukunPageIntro(
                    eyebrow: 'Private care access',
                    title: 'Welcome back',
                    subtitle: 'Sign in securely to continue to your personal care plan or Super Admin workspace.',
                  ),
                  const SizedBox(height: 24),
                  SukunSurface(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign in details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Use your Patient ID, phone number, or administrator email.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: SukunColors.muted),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _identifierController,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Patient ID, phone, or email',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: validateSignInIdentifier,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: validateAccountPassword,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                                !AppEnvironment.isSupabaseConfigured ||
                                    _submitting
                                ? null
                                : _submit,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _submitting ? 'Signing in…' : 'Continue securely',
                            ),
                          ),
                          if (!AppEnvironment.isSupabaseConfigured) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Supabase client configuration is required for sign in.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 17,
                        color: SukunColors.deepTide,
                      ),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Your patient information stays protected.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
