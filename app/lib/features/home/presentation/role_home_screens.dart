import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/home/presentation/unified_home_screen.dart';
import 'package:sukun_life/features/home/presentation/public_welcome_screen.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => kIsWeb
      ? const PublicWelcomeScreen()
      : const UnifiedHomeScreen(isPatient: false);
}

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key, this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) => UnifiedHomeScreen(
    isPatient: false,
    isSignedInMember: true,
    displayName: displayName,
  );
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SukunSurface(
    padding: const EdgeInsets.all(17),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SukunIconBadge(icon: icon),
        const SizedBox(height: 16),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 3),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SukunColors.muted),
        ),
      ],
    ),
  );
}

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return AdminScaffold(
      title: copy?.adminDashboard ?? 'কাজের সারসংক্ষেপ',
      selectedIndex: 0,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          SukunPageIntro(
            eyebrow: copy?.adminDashboard ?? 'কাজের সারসংক্ষেপ',
            title: displayName == null
                ? (copy?.adminWelcome ?? 'আপনার কাজের জায়গায় স্বাগতম')
                : '${copy?.adminWelcome ?? 'স্বাগতম'}, $displayName',
            subtitle:
                copy?.adminWelcomeSubtitle ??
                'রোগীর পরিকল্পনা ও উপকরণ এক জায়গা থেকে পরিচালনা করুন.',
            trailing: const SukunIconBadge(
              icon: Icons.admin_panel_settings_outlined,
              size: 54,
            ),
          ),
          const SizedBox(height: 24),
          SukunSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy?.adminQuickActions ?? 'দ্রুত কাজ শুরু করুন',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  copy?.adminQuickActionsHelp ??
                      'যে কাজটি করতে চান, সরাসরি সেখানে যান।',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/admin/patients/new'),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(copy?.addPatient ?? 'নতুন রোগী যোগ করুন'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/patients'),
                      icon: const Icon(Icons.search_rounded),
                      label: Text(copy?.findPatient ?? 'রোগী খুঁজুন'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/routine-templates'),
                      icon: const Icon(Icons.checklist_outlined),
                      label: const Text('প্রস্তুত রুটিন'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/users'),
                      icon: const Icon(Icons.assignment_ind_outlined),
                      label: const Text('ব্যবহারকারীর রুটিন ও অগ্রগতি'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/content'),
                      icon: const Icon(Icons.library_books_outlined),
                      label: Text(
                        copy?.manageResources ?? 'উপকরণ পরিচালনা করুন',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SukunSectionHeader(
            title: 'রোগী ও অগ্রগতি',
            action: TextButton(
              onPressed: () => context.go('/admin/patients'),
              child: const Text('রোগীর তালিকা'),
            ),
          ),
          const SizedBox(height: 10),
          _DashboardAction(
            icon: Icons.people_alt_outlined,
            title: 'রোগীর পরিকল্পনা ও অগ্রগতি',
            description:
                'নির্বাচিত রোগীর প্রোফাইলে যান। সেখানে পরিকল্পনা তৈরি ও '
                'অগ্রগতি দেখার অনুমোদিত টুলস পাবেন।',
            actionLabel: 'রোগী বাছুন',
            onTap: () => context.go('/admin/patients'),
          ),
          const SizedBox(height: 18),
          SukunSectionHeader(
            title: 'একই উপকরণ, সবার জন্য',
            action: TextButton(
              onPressed: () => context.push('/resources'),
              child: const Text('সবার লাইব্রেরি'),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _DashboardAction(
                      icon: Icons.menu_book_outlined,
                      title: 'পাবলিক উপকরণ লাইব্রেরি',
                      description:
                          'সাধারণ ইউজার ও রোগী যেভাবে কুরআন, হাদিস, '
                          'দোয়া ও রুকইয়াহ দেখেন, সেই একই তালিকা দেখুন।',
                      actionLabel: 'লাইব্রেরি খুলুন',
                      onTap: () => context.push('/resources'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _DashboardAction(
                      icon: Icons.edit_note_outlined,
                      title: 'উপকরণ পরিচালনা',
                      description:
                          'অ্যাডমিনের আলাদা Draft, Review, '
                          'Publish ও Content Editor।',
                      actionLabel: 'কনটেন্ট পরিচালনা',
                      onTap: () => context.go('/admin/content'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _DashboardAction(
                      icon: Icons.playlist_add_check_rounded,
                      title: 'রুটিন টেমপ্লেট',
                      description:
                          'প্রকাশযোগ্য রুটিন প্রস্তুত ও পরিচালনা করুন। '
                          'ব্যক্তিগত রুটিন স্বয়ংক্রিয়ভাবে বদলাবে না।',
                      actionLabel: 'রুটিন দেখুন',
                      onTap: () => context.go('/admin/routine-templates'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _DashboardAction(
                      icon: Icons.campaign_outlined,
                      title: 'সবার জন্য নোটিশ',
                      description:
                          'নোটিশ, ছবি ও অনুমোদিত লিংক '
                          'যোগ করে প্রকাশ করুন।',
                      actionLabel: 'নোটিশ পরিচালনা',
                      onTap: () => context.go('/admin/announcements'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          SukunSectionHeader(
            title: 'প্রয়োজনীয় টুলস',

            action: TextButton(
              onPressed: () => context.go('/resources'),
              child: const Text('রিসোর্স'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _UtilityCard(
                  icon: Icons.schedule_rounded,
                  label: 'নামাজের সময়',
                  caption: 'দৈনিক সময়সূচি',
                  onTap: () => context.push('/prayer-times'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _UtilityCard(
                  icon: Icons.explore_rounded,
                  label: 'কিবলা',
                  caption: 'দিকনির্দেশনা',
                  onTap: () => context.push('/qibla'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SukunSurface(
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SukunIconBadge(icon: icon, size: 54),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: SukunColors.muted),
              ),
              const SizedBox(height: 12),
              Text(
                actionLabel,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: SukunColors.deepTide),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: SukunColors.deepTide),
      ],
    ),
  );
}
