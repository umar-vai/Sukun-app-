import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/public_signin_gateway.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/auth/domain/public_auth_inputs.dart';

/// OTP is restricted to existing accounts; no implicit patient-account link.
class PublicOtpSignInScreen extends ConsumerStatefulWidget {
  const PublicOtpSignInScreen({super.key, required this.channel});
  final PublicOtpChannel channel;

  @override
  ConsumerState<PublicOtpSignInScreen> createState() =>
      _PublicOtpSignInScreenState();
}

class _PublicOtpSignInScreenState extends ConsumerState<PublicOtpSignInScreen> {
  final _recipient = TextEditingController();
  final _code = TextEditingController();
  final _recipientForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  Timer? _timer;
  int _wait = 0;
  bool _requested = false;
  bool _busy = false;

  bool get _available => AppEnvironment.isSupabaseConfigured &&
      (widget.channel == PublicOtpChannel.email
          ? AppEnvironment.emailOtpEnabled
          : AppEnvironment.phoneOtpEnabled);

  @override
  void dispose() {
    _timer?.cancel();
    _recipient.dispose();
    _code.dispose();
    super.dispose();
  }

  void _cooldown() {
    _timer?.cancel();
    setState(() => _wait = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_wait <= 1) {
        timer.cancel();
        setState(() => _wait = 0);
      } else {
        setState(() => _wait--);
      }
    });
  }

  Future<void> _send() async {
    if (!_available || _busy || _wait > 0) return;
    // During code entry the recipient Form is unmounted; resend must not
    // dereference an absent FormState.
    if (!_requested && !_recipientForm.currentState!.validate()) return;
    if (validateOtpRecipient(_recipient.text, widget.channel) != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(publicSignInGatewayProvider).requestCode(
        channel: widget.channel,
        identifier: _recipient.text.trim(),
      );
      if (!mounted) return;
      setState(() => _requested = true);
      _cooldown();
    } catch (_) {
      _error('কোড পাঠানো যায়নি। কিছুক্ষণ পরে আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (!_available || _busy || !_codeForm.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(publicSignInGatewayProvider).verifyCode(
        channel: widget.channel,
        identifier: _recipient.text.trim(),
        code: _code.text.trim(),
      );
      if (mounted) context.go('/');
    } catch (_) {
      _error('কোডটি সঠিক নয় বা মেয়াদ শেষ হয়েছে। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.channel == PublicOtpChannel.email;
    return Scaffold(
      appBar: AppBar(title: Text(email ? 'ইমেইল কোডে লগইন' : 'SMS কোডে লগইন')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: !_available
                  ? const Text('এই লগইন সুবিধা এখনো চালু হয়নি।',
                      textAlign: TextAlign.center)
                  : _requested
                    ? Form(
                        key: _codeForm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('যাচাইকরণ কোড লিখুন',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text('কোডটি কাউকে দেবেন না।'),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('otp-code'),
                              controller: _code,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '৬–৮ সংখ্যার কোড'),
                              validator: validateOtpCode,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _busy ? null : _verify,
                              child: Text(_busy ? 'যাচাই হচ্ছে…' : 'কোড যাচাই করে লগইন'),
                            ),
                            TextButton(
                              onPressed: _busy || _wait > 0 ? null : _send,
                              child: Text(_wait > 0
                                  ? 'আবার পাঠাতে $_wait সেকেন্ড'
                                  : 'আবার কোড পাঠান'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : () {
                                setState(() { _requested = false; _code.clear(); });
                              },
                              child: const Text('ইমেইল বা ফোন পরিবর্তন করুন'),
                            ),
                          ],
                        ),
                      )
                    : Form(
                        key: _recipientForm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(email ? 'আপনার ইমেইল দিন' : 'আপনার ফোন নম্বর দিন',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(email
                                ? 'আগে নিবন্ধিত ইমেইলে কোড পাঠানো হবে।'
                                : 'আগে নিবন্ধিত ফোন নম্বর দেশের কোডসহ দিন।'),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('otp-recipient'),
                              controller: _recipient,
                              keyboardType: email
                                  ? TextInputType.emailAddress
                                  : TextInputType.phone,
                              decoration: InputDecoration(labelText: email
                                  ? 'ইমেইল ঠিকানা' : 'ফোন নম্বর (+880...)'),
                              validator: (value) =>
                                  validateOtpRecipient(value, widget.channel),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _busy ? null : _send,
                              child: Text(_busy
                                  ? 'কোড পাঠানো হচ্ছে…' : 'যাচাইকরণ কোড পাঠান'),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('পাসওয়ার্ড দিয়ে লগইন'),
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
}
