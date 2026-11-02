// Browser entrypoint for the design-review preview.
//
// Runs the real app against an in-memory sample backend (lib/preview/) so
// signed-in Patient, Member and Super Admin screens can be reviewed without
// a Supabase project. Build with:
//   flutter build web --target lib/main_preview.dart \
//     --dart-define=APP_ENVIRONMENT=development \
//     --dart-define=SUPABASE_URL=https://preview.supabase.co \
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_preview
// Never point this entrypoint at a real Supabase project.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/preview/preview_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppEnvironment.supabaseUrl.startsWith('https://preview.')) {
    throw StateError('The preview entrypoint only runs against sample data.');
  }
  await Supabase.initialize(
    url: AppEnvironment.supabaseUrl,
    publishableKey: AppEnvironment.supabasePublishableKey,
    httpClient: PreviewHttpClient(),
  );
  runApp(
    const ProviderScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [SukunLifeApp(), _PreviewSwitcher()]),
      ),
    ),
  );
}

class _PreviewSwitcher extends StatefulWidget {
  const _PreviewSwitcher();

  @override
  State<_PreviewSwitcher> createState() => _PreviewSwitcherState();
}

class _PreviewSwitcherState extends State<_PreviewSwitcher> {
  bool _open = false;
  bool _busy = false;

  String _currentLabel() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    for (final account in previewAccounts) {
      if (account.userId == userId) return account.label;
    }
    return 'অতিথি';
  }

  Future<void> _signIn(PreviewAccount? account) async {
    setState(() => _busy = true);
    final auth = Supabase.instance.client.auth;
    try {
      if (auth.currentSession != null) await auth.signOut();
      if (account != null) {
        await auth.signInWithPassword(
          email: account.email,
          password: 'preview',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _open = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SukunTheme.light();
    final scheme = theme.colorScheme;
    final textStyle =
        theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    Widget option(String label, PreviewAccount? account) {
      final selected = _currentLabel() == (account?.label ?? 'অতিথি');
      return InkWell(
        onTap: _busy ? null : () => _signIn(account),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Text(label, style: textStyle.copyWith(color: scheme.onSurface)),
            ],
          ),
        ),
      );
    }

    return Positioned(
      left: 12,
      bottom: 96,
      child: Theme(
        data: theme,
        child: Material(
          color: scheme.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_open) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'প্রিভিউ: কে হিসেবে দেখবেন?',
                    style: textStyle.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                option('রোগী (SL-1001)', previewPatient),
                option('Super Admin', previewAdmin),
                option('সদস্য', previewMember),
                option('অতিথি (লগআউট)', null),
                InkWell(
                  onTap: PreviewBackend.resetSampleData,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restart_alt, size: 18, color: scheme.error),
                        const SizedBox(width: 10),
                        Text(
                          'নমুনা ডেটা শুরু থেকে',
                          style: textStyle.copyWith(color: scheme.error),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
              InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _busy ? 'অপেক্ষা করুন…' : 'প্রিভিউ: ${_currentLabel()}',
                        style: textStyle.copyWith(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
