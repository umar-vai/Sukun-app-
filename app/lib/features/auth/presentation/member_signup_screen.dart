import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/member_registration_repository.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';

/// Public registration never links a clinical patient identity automatically.
class MemberSignUpScreen extends ConsumerStatefulWidget {
  const MemberSignUpScreen({super.key});

  @override
  ConsumerState<MemberSignUpScreen> createState() =>
      _MemberSignUpScreenState();
}

class _MemberSignUpScreenState extends ConsumerState<MemberSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting ||
        !AppEnvironment.publicMemberSignupEnabled ||
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(memberRegistrationRepositoryProvider).registerWithEmail(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('অ্যাকাউন্ট তৈরি করা যায়নি। আবার চেষ্টা করুন।'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('নতুন অ্যাকাউন্ট')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _submitted
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 56),
                      const SizedBox(height: 16),
                      const Text(
                        'আপনার নিবন্ধনের অনুরোধ গ্রহণ করা হয়েছে।',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ইমেইল যাচাই প্রয়োজন হলে ইনবক্স দেখুন। এরপর লগইন করুন।',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('লগইনে ফিরে যান'),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: SukunLifeLogo(height: 66)),
                        const SizedBox(height: 22),
                        Text(
                          'সুকুন লাইফে অ্যাকাউন্ট তৈরি করুন',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'বিনামূল্যের উপকরণ ও ভবিষ্যতের ব্যক্তিগত সুবিধা ব্যবহার করুন। '
                          'রোগীর প্রেসক্রিপশন এই অ্যাকাউন্টে স্বয়ংক্রিয়ভাবে যুক্ত হবে না।',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const Key('member-email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'ইমেইল',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: validateRegistrationEmail,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('member-password'),
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'পাসওয়ার্ড',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) =>
                              validateAccountPassword(value) == null
                                  ? null
                                  : '৮ থেকে ৭২টি অক্ষরের পাসওয়ার্ড লিখুন।',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('member-password-confirm'),
                          controller: _confirmation,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'পাসওয়ার্ড নিশ্চিত করুন',
                          ),
                          validator: (value) =>
                              validateConfirmedPassword(
                                    _password.text,
                                    value ?? '',
                                  ) ==
                                  null
                              ? null
                              : 'পাসওয়ার্ড দুটি মিলছে না।',
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: !AppEnvironment.isSupabaseConfigured ||
                                  !AppEnvironment.publicMemberSignupEnabled ||
                                  _submitting
                              ? null
                              : _submit,
                          child: Text(
                            _submitting
                                ? 'অ্যাকাউন্ট তৈরি হচ্ছে…'
                                : 'অ্যাকাউন্ট তৈরি করুন',
                          ),
                        ),
                        if (!AppEnvironment.publicMemberSignupEnabled) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'নতুন অ্যাকাউন্ট খোলার সুবিধা প্রস্তুত করা হচ্ছে।',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
