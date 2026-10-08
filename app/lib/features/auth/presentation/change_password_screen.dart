import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

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
        SnackBar(
          content: Text(
            Localizations.of<AppLocalizations>(
                  context,
                  AppLocalizations,
                )?.passwordChanged ??
                'আপনার পাসওয়ার্ড পরিবর্তন হয়েছে।',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.of<AppLocalizations>(
                  context,
                  AppLocalizations,
                )?.passwordChangeFailed ??
                'পাসওয়ার্ড বদলানো যায়নি। দেওয়া তথ্য ঠিক আছে কি না দেখে আবার চেষ্টা করুন।',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy?.passwordTitle ?? 'অ্যাকাউন্ট সুরক্ষিত করুন'),
        actions: [
          IconButton(
            onPressed: _submitting
                ? null
                : () => ref.read(authRepositoryProvider).signOut(),
            tooltip: copy?.signOut ?? 'বের হয়ে যান',
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
                  SukunPageIntro(
                    eyebrow: copy?.firstSignIn ?? 'প্রথমবার প্রবেশ',
                    title:
                        copy?.createPrivatePassword ??
                        'নিজের পাসওয়ার্ড তৈরি করুন',
                    subtitle: copy?.passwordResetSubtitle ?? 'রোগীর ব্যক্তিগত তথ্য দেখার আগে অস্থায়ী পাসওয়ার্ড বদলে নিন।',
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
                          decoration: InputDecoration(
                            labelText:
                                copy?.temporaryPassword ?? 'অস্থায়ী পাসওয়ার্ড',
                            prefixIcon: const Icon(Icons.key_outlined),
                          ),
                          validator: (value) =>
                              validateAccountPassword(value) == null
                              ? null
                              : (copy?.passwordError ??
                                    'পাসওয়ার্ডে ৮ থেকে ৭২টি অক্ষর থাকতে হবে।'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _newController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: copy?.newPassword ?? 'নতুন পাসওয়ার্ড',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                          ),
                          validator: (value) =>
                              validateAccountPassword(value) == null
                              ? null
                              : (copy?.passwordError ??
                                    'পাসওয়ার্ডে ৮ থেকে ৭২টি অক্ষর থাকতে হবে।'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText:
                                copy?.confirmNewPassword ??
                                'নতুন পাসওয়ার্ড আবার লিখুন',
                            prefixIcon: const Icon(
                              Icons.verified_user_outlined,
                            ),
                          ),
                          validator: (value) {
                            if (validateAccountPassword(_newController.text) !=
                                null) {
                              return copy?.passwordError ??
                                  'পাসওয়ার্ডে ৮ থেকে ৭২টি অক্ষর থাকতে হবে।';
                            }
                            if (value != _newController.text) {
                              return copy?.passwordNotMatch ??
                                  'দুটি পাসওয়ার্ড এক হয়নি। আবার লিখুন।';
                            }
                            return null;
                          },
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
                            _submitting
                                ? (copy?.updatingPassword ??
                                      'পাসওয়ার্ড বদলানো হচ্ছে…')
                                : (copy?.secureMyAccount ??
                                      'নতুন পাসওয়ার্ড সংরক্ষণ করুন'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    radius: 18,
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: SukunColors.deepTide,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            copy?.passwordSafetyHint ?? 'অন্তত ৮ অক্ষরের পাসওয়ার্ড দিন। অস্থায়ী পাসওয়ার্ডটি আবার ব্যবহার করবেন না।',
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
