import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/home/presentation/unified_home_screen.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const UnifiedHomeScreen(isPatient: false);
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
          SukunSurface(
            tone: SukunSurfaceTone.navy,
            padding: const EdgeInsets.all(22),
            onTap: () => context.go('/admin/patients'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    SukunStatusPill(
                      label: 'PRIMARY WORKFLOW',
                      tone: SukunStatusTone.brand,
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Patient care',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Create patients, preserve prescriptions, review actions, publish plans, and follow progress.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkflowStep(number: '01', label: 'Patient'),
                    _WorkflowStep(number: '02', label: 'Prescription'),
                    _WorkflowStep(number: '03', label: 'Plan'),
                    _WorkflowStep(number: '04', label: 'Progress'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DashboardAction(
            icon: Icons.library_books_outlined,
            title: 'Content & Islamic Resources',
            description: 'Create, verify, preview, publish, and archive reusable canonical resources.',
            actionLabel: 'Open content workspace',
            onTap: () => context.go('/admin/content'),
          ),
          const SizedBox(height: 28),
          SukunSectionHeader(
            title: 'Review & utilities',
            subtitle: 'Preview public content or open daily tools',
            action: TextButton(
              onPressed: () => context.go('/resources'),
              child: const Text('Public preview'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _UtilityCard(
                  icon: Icons.schedule_rounded,
                  label: 'Prayer times',
                  caption: 'Daily timetable',
                  onTap: () => context.push('/prayer-times'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _UtilityCard(
                  icon: Icons.explore_rounded,
                  label: 'Qibla',
                  caption: 'Direction utility',
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

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24),
    ),
    child: Text('$number  $label', style: const TextStyle(color: Colors.white)),
  );
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
