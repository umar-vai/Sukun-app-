import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return AdminScaffold(
      title: copy?.adminDashboard ?? 'কাজের সারসংক্ষেপ',
      selectedIndex: 0,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.page,
              SukunSpace.sm,
              SukunSpace.page,
              40,
            ),
            children: [
              SukunSurface(
                key: const Key('admin-home-hero'),
                tone: SukunSurfaceTone.navy,
                radius: SukunRadius.hero,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SukunColors.sukunBlue.withValues(
                                alpha: 0.22,
                              ),
                              borderRadius: BorderRadius.circular(
                                SukunRadius.chip,
                              ),
                            ),
                            child: Text(
                              'অ্যাডমিন',
                              style: textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF9FD6F0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayName == null
                                ? (copy?.adminWelcome ??
                                      'আপনার কাজের জায়গায় স্বাগতম')
                                : '${copy?.adminWelcome ?? 'স্বাগতম'}, $displayName',
                            style: textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            copy?.adminWelcomeSubtitle ?? 'রোগীর পরিকল্পনা ও উপকরণ এক জায়গা থেকে পরিচালনা করুন.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB9CCDB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 30,
                      color: Color(0xFF9FD6F0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SukunSpace.section),
              SukunSectionHeader(
                title: copy?.adminQuickActions ?? 'দ্রুত কাজ শুরু করুন',
                subtitle:
                    copy?.adminQuickActionsHelp ??
                    'যে কাজটি করতে চান, সরাসরি সেখানে যান।',
              ),
              const SizedBox(height: SukunSpace.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 4 : 2;
                  final tiles = [
                    _QuickTile(
                      icon: Icons.person_add_alt_1_outlined,
                      label: copy?.addPatient ?? 'নতুন রোগী যোগ করুন',
                      primary: true,
                      onTap: () => context.go('/admin/patients/new'),
                    ),
                    _QuickTile(
                      icon: Icons.search_rounded,
                      label: copy?.findPatient ?? 'রোগী খুঁজুন',
                      onTap: () => context.go('/admin/patients'),
                    ),
                    _QuickTile(
                      icon: Icons.people_alt_outlined,
                      label: 'সকল ব্যবহারকারী',
                      onTap: () => context.go('/admin/users'),
                    ),
                    _QuickTile(
                      icon: Icons.assignment_ind_outlined,
                      label: 'ব্যবহারকারীর রুটিন ও অগ্রগতি',
                      onTap: () => context.go('/admin/user-routines'),
                    ),
                  ];
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: SukunSpace.md,
                    crossAxisSpacing: SukunSpace.md,
                    childAspectRatio: columns == 4 ? 1.5 : 1.35,
                    children: tiles,
                  );
                },
              ),
              const SizedBox(height: SukunSpace.sectionLarge),
              const SukunSectionHeader(title: 'রোগী ও অগ্রগতি'),
              const SizedBox(height: SukunSpace.md),
              _AdminLinkGroup(
                children: [
                  _AdminLinkRow(
                    icon: Icons.people_alt_outlined,
                    title: 'রোগীর পরিকল্পনা ও অগ্রগতি',
                    description:
                        'রোগী বাছুন। প্রোফাইলে পরিকল্পনা তৈরি ও অগ্রগতি দেখার '
                        'অনুমোদিত টুলস পাবেন।',
                    onTap: () => context.go('/admin/patients'),
                  ),
                ],
              ),
              const SizedBox(height: SukunSpace.sectionLarge),
              SukunSectionHeader(
                title: 'একই উপকরণ, সবার জন্য',
                action: TextButton(
                  onPressed: () => context.push('/resources'),
                  child: const Text('সবার লাইব্রেরি'),
                ),
              ),
              const SizedBox(height: SukunSpace.md),
              _AdminLinkGroup(
                children: [
                  _AdminLinkRow(
                    icon: Icons.menu_book_outlined,
                    title: 'পাবলিক উপকরণ লাইব্রেরি',
                    description:
                        'সাধারণ ইউজার ও রোগী যেভাবে কুরআন, হাদিস, দোয়া ও '
                        'রুকইয়াহ দেখেন, সেই একই তালিকা।',
                    onTap: () => context.push('/resources'),
                  ),
                  _AdminLinkRow(
                    icon: Icons.edit_note_outlined,
                    title: copy?.manageResources ?? 'উপকরণ পরিচালনা করুন',
                    description: 'Draft, Review, Publish ও Content Editor।',
                    onTap: () => context.go('/admin/content'),
                  ),
                  _AdminLinkRow(
                    icon: Icons.playlist_add_check_rounded,
                    title: 'রুটিন টেমপ্লেট (প্রস্তুত রুটিন)',
                    description:
                        'প্রকাশযোগ্য রুটিন প্রস্তুত করুন। ব্যক্তিগত রুটিন '
                        'স্বয়ংক্রিয়ভাবে বদলাবে না।',
                    onTap: () => context.go('/admin/routine-templates'),
                  ),
                  _AdminLinkRow(
                    icon: Icons.campaign_outlined,
                    title: 'সবার জন্য নোটিশ',
                    description:
                        'নোটিশ, ছবি ও অনুমোদিত লিংক যোগ করে প্রকাশ করুন।',
                    onTap: () => context.go('/admin/announcements'),
                  ),
                ],
              ),
              const SizedBox(height: SukunSpace.sectionLarge),
              SukunSectionHeader(
                title: 'প্রয়োজনীয় টুলস',
                action: TextButton(
                  onPressed: () => context.go('/resources'),
                  child: const Text('রিসোর্স'),
                ),
              ),
              const SizedBox(height: SukunSpace.md),
              Row(
                children: [
                  Expanded(
                    child: _UtilityCard(
                      icon: Icons.schedule_rounded,
                      label: 'নামাজের সময়',
                      caption: 'দৈনিক সময়সূচি',
                      onTap: () => context.push('/prayer-times'),
                    ),
                  ),
                  const SizedBox(width: SukunSpace.md),
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
        ),
      ),
    );
  }
}

/// A large, calm shortcut tile. The first one is the main admin action.
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: SukunSurface(
      padding: const EdgeInsets.all(SukunSpace.lg),
      radius: SukunRadius.tile + 2,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SukunIconBadge(
            icon: icon,
            size: 42,
            backgroundColor: primary ? SukunColors.deepTide : null,
            color: primary ? Colors.white : null,
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// One white card holding related admin destinations as tidy rows.
class _AdminLinkGroup extends StatelessWidget {
  const _AdminLinkGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SukunSurface(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 72, color: Color(0xFFEEF4F9)),
          children[i],
        ],
      ],
    ),
  );
}

class _AdminLinkRow extends StatelessWidget {
  const _AdminLinkRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SukunSpace.lg,
        vertical: 14,
      ),
      child: Row(
        children: [
          SukunIconBadge(icon: icon, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: SukunColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8AA3B5)),
        ],
      ),
    ),
  );
}
