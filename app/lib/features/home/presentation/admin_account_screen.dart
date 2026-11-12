import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/updates/android_update_panel.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';

/// Account and settings for the main admin and raqis (owner request
/// 2026-11-12): reachable from the admin bottom menu.
class AdminAccountScreen extends ConsumerWidget {
  const AdminAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider).value;
    final theme = Theme.of(context);
    final name = session?.displayName?.trim();
    final shown = name == null || name.isEmpty ? 'অ্যাডমিন' : name;
    final raqi = session?.isRaqi == true;
    final rows = <(IconData, String, VoidCallback)>[
      (
        Icons.palette_outlined,
        'অ্যাপের চেহারা ও পড়ার সুবিধা',
        () => context.push('/settings/appearance'),
      ),
      (
        Icons.notifications_active_outlined,
        'নোটিফিকেশন ও রিমাইন্ডার',
        () => context.push('/settings/notifications'),
      ),
      if (!raqi)
        (
          Icons.groups_2_outlined,
          'রাকি ও টিম',
          () => context.push('/admin/staff'),
        ),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        (
          Icons.system_update_alt_outlined,
          'অ্যাপ আপডেট',
          () => checkAndroidUpdateManually(context),
        ),
    ];
    return AdminScaffold(
      title: 'অ্যাকাউন্ট',
      selectedIndex: AdminScaffold.accountIndex,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.page,
              SukunSpace.sm,
              SukunSpace.page,
              40,
            ),
            children: [
              SukunSurface(
                key: const Key('admin-account-card'),
                tone: SukunSurfaceTone.soft,
                showBorder: false,
                radius: SukunRadius.hero,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(
                        shown.characters.first,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: SukunColors.deepTide,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shown,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SukunStatusPill(
                            label: raqi ? 'রাকি' : 'মূল অ্যাডমিন',
                            tone: SukunStatusTone.brand,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SukunSpace.section),
              const SukunSectionHeader(title: 'সেটিংস'),
              const SizedBox(height: SukunSpace.md),
              SukunSurface(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 68),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: SukunIconBadge(icon: rows[i].$1, size: 42),
                        title: Text(
                          rows[i].$2,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: rows[i].$3,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
