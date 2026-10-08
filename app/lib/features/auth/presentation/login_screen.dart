import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';
import 'package:sukun_life/core/errors/friendly_failures.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(FriendlyFailures.signIn(context))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                      tooltip: copy?.goBack ?? 'ফিরে যান',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(child: SukunLifeLogo(height: 78)),
                  const SizedBox(height: 18),
                  SukunPageIntro(
                    eyebrow: copy?.signInEyebrow ?? 'ব্যক্তিগত অ্যাকাউন্ট',
                    title: copy?.signInWelcome ?? 'স্বাগতম',
                    subtitle: copy?.signInSubtitle ?? 'আপনার পরিকল্পনা দেখতে বা অ্যাডমিনের কাজ করতে প্রবেশ করুন।',
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
                            copy?.signInDetails ?? 'অ্যাকাউন্টে প্রবেশ',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            copy?.signInIdentifierHelp ?? 'রোগী নম্বর, ফোন নম্বর বা অ্যাডমিনের ইমেইল দিন।',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: SukunColors.muted),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _identifierController,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText:
                                  copy?.signInIdentifier ??
                                  'রোগী নম্বর, ফোন বা ইমেইল',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                            ),
                            validator: (value) =>
                                validateSignInIdentifier(value) == null
                                ? null
                                : (copy?.signInIdentifierError ??
                                      'রোগী নম্বর, ফোন নম্বর বা ইমেইল ঠিকভাবে লিখুন।'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: copy?.password ?? 'পাসওয়ার্ড',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                tooltip: _obscure
                                    ? (copy?.showPassword ?? 'পাসওয়ার্ড দেখুন')
                                    : (copy?.hidePassword ?? 'পাসওয়ার্ড লুকান'),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                validateAccountPassword(value) == null
                                ? null
                                : (copy?.passwordError ??
                                      'পাসওয়ার্ডে ৮ থেকে ৭২টি অক্ষর থাকতে হবে।'),
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
                              _submitting
                                  ? (copy?.signingIn ?? 'প্রবেশ করা হচ্ছে…')
                                  : (copy?.continueSecurely ?? 'প্রবেশ করুন'),
                            ),
                          ),
                          if (!AppEnvironment.isSupabaseConfigured) ...[
                            const SizedBox(height: 12),
                            Text(
                              copy?.signInNotConfigured ??
                                  'এটি শুধু অ্যাপের ডিজাইন দেখার সংস্করণ। লগইন পরীক্ষা করতে সংযুক্ত পরীক্ষামূলক অ্যাপ প্রয়োজন।',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 17,
                        color: SukunColors.deepTide,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          copy?.patientDataPrivate ??
                              'আপনার ব্যক্তিগত তথ্য সুরক্ষিত রাখা হয়।',
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
