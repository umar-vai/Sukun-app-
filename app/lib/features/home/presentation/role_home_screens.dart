import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/widgets/sukun_bangla_format.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/home/presentation/staff_access.dart';
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

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final theme = Theme.of(context);
    // A raqi sees patient work only; the database enforces the same.
    final raqi = isRaqiSession(context);
    final tools = <_AdminTool>[
      _AdminTool(
        Icons.alarm_add_rounded,
        'রুটিন ও অগ্রগতি',
        () => context.go('/admin/user-routines'),
      ),
      _AdminTool(
        Icons.medical_information_outlined,
        'চিকিৎসা ফাইল',
        () => context.go('/admin/patients'),
      ),
      if (!raqi) ...[
        _AdminTool(
          Icons.fact_check_outlined,
          'সুকুন অফিসিয়াল টেমপ্লেট',
          () => context.go('/admin/care-templates'),
        ),
        _AdminTool(
          Icons.edit_note_outlined,
          copy?.manageResources ?? 'উপকরণ পরিচালনা করুন',
          () => context.go('/admin/content'),
        ),
        _AdminTool(
          Icons.playlist_add_check_rounded,
          'রুটিন টেমপ্লেট',
          () => context.go('/admin/routine-templates'),
        ),
        _AdminTool(
          Icons.campaign_outlined,
          'সবার জন্য নোটিশ',
          () => context.go('/admin/announcements'),
        ),
        _AdminTool(
          Icons.groups_2_outlined,
          'রাকি ও টিম',
          () => context.push('/admin/staff'),
        ),
        _AdminTool(
          Icons.menu_book_outlined,
          'সবার লাইব্রেরি',
          () => context.push('/resources'),
        ),
      ],
      _AdminTool(
        Icons.schedule_rounded,
        'নামাজের সময়',
        () => context.push('/prayer-times'),
      ),
      _AdminTool(Icons.explore_rounded, 'কিবলা', () => context.push('/qibla')),
    ];
    return AdminScaffold(
      title: copy?.adminDashboard ?? 'কাজের সারসংক্ষেপ',
      selectedIndex: 0,
      heroAppBar: true,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              SukunHeroHeader(
                greeting: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${banglaWeekdayDate(DateTime.now())} · ${raqi ? 'রাকি' : 'অ্যাডমিন'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: SukunColors.saffron,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayName == null
                          ? (copy?.adminWelcome ??
                                'আপনার কাজের জায়গায় স্বাগতম')
                          : '${copy?.adminWelcome ?? 'স্বাগতম'}, $displayName',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
                overlap: _AdminStats(includeContent: !raqi),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SukunSurface(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'আজকের কাজ',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final primary = FilledButton.icon(
                                onPressed: () =>
                                    context.go('/admin/patients/new'),
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                                label: Text(
                                  copy?.addPatient ?? 'নতুন রোগী যোগ করুন',
                                ),
                              );
                              final secondary = OutlinedButton.icon(
                                onPressed: () => context.go('/admin/users'),
                                icon: const Icon(Icons.search_rounded),
                                label: Text(copy?.findPatient ?? 'রোগী খুঁজুন'),
                              );
                              if (raqi) return secondary;
                              if (constraints.maxWidth < 440) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    primary,
                                    const SizedBox(height: 10),
                                    secondary,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: primary),
                                  const SizedBox(width: 10),
                                  Expanded(child: secondary),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 720
                                  ? 4
                                  : constraints.maxWidth >= 460
                                  ? 3
                                  : 2;
                              return GridView.count(
                                crossAxisCount: columns,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: columns == 2 ? 2.35 : 2.6,
                                children: [
                                  for (final tool in tools)
                                    _AdminToolTile(tool),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    SukunSectionHeader(
                      title: 'সাম্প্রতিক রোগী',
                      action: TextButton(
                        onPressed: () => context.go('/admin/users'),
                        child: const Text('সব রোগী'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _RecentPatients(),
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

class _AdminTool {
  const _AdminTool(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _AdminToolTile extends StatelessWidget {
  const _AdminToolTile(this.tool);

  final _AdminTool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SukunGlass(
      borderRadius: BorderRadius.circular(16),
      tone: SukunGlassTone.surface,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tool.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                SukunIconBadge(
                  icon: tool.icon,
                  size: 36,
                  backgroundColor: theme.colorScheme.surface,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tool.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatValue {
  const _StatValue(this.icon, this.label, this.value, this.tone);

  final IconData icon;
  final String label;
  final int? value;
  final SukunStatusTone tone;
}

/// Live counts read through the admin's own RLS-verified session.
/// Shows a dash instead of guessing when the backend is unavailable.
class _AdminStats extends StatefulWidget {
  const _AdminStats({this.includeContent = true});

  /// Raqi staff work with patients only, so the content review count is
  /// left out for them.
  final bool includeContent;

  @override
  State<_AdminStats> createState() => _AdminStatsState();
}

class _AdminStatsState extends State<_AdminStats> {
  late final Future<List<int?>> _counts = _load();

  Future<int?> _count(
    PostgrestFilterBuilder<PostgrestList> Function(SupabaseClient c) query,
  ) async {
    try {
      final response = await query(Supabase.instance.client).count();
      return response.count;
    } catch (_) {
      return null;
    }
  }

  Future<List<int?>> _load() async {
    if (!AppEnvironment.isSupabaseConfigured) return [null, null, null, null];
    return Future.wait([
      _count((c) => c.from('patients').select('id').eq('status', 'active')),
      _count((c) => c.from('care_plans').select('id').eq('status', 'active')),
      _count(
        (c) => c
            .from('plan_actions')
            .select('id')
            .eq('review_status', 'needs_review'),
      ),
      _count(
        (c) => c.from('content_items').select('id').eq('status', 'review'),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<int?>>(
    future: _counts,
    builder: (context, snapshot) {
      final values = snapshot.data ?? const [null, null, null, null];
      final loading = snapshot.connectionState == ConnectionState.waiting;
      final stats = <_StatValue>[
        _StatValue(
          Icons.people_alt_outlined,
          'সক্রিয় রোগী',
          values[0],
          SukunStatusTone.brand,
        ),
        _StatValue(
          Icons.event_note_outlined,
          'চালু পরিকল্পনা',
          values[1],
          SukunStatusTone.success,
        ),
        _StatValue(
          Icons.rate_review_outlined,
          'রিভিউ বাকি কাজ',
          values[2],
          SukunStatusTone.warning,
        ),
        if (widget.includeContent)
          _StatValue(
            Icons.library_books_outlined,
            'রিভিউতে উপকরণ',
            values[3],
            SukunStatusTone.neutral,
          ),
      ];
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 560 ? stats.length : 2;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: columns > 2 ? 1.75 : 1.85,
            children: [
              for (final stat in stats) _StatTile(stat: stat, loading: loading),
            ],
          );
        },
      );
    },
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.loading});

  final _StatValue stat;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (foreground, background) = switch (stat.tone) {
      SukunStatusTone.success => (SukunColors.success, SukunColors.successSoft),
      SukunStatusTone.warning => (
        const Color(0xFF8A5A00),
        SukunColors.warningSoft,
      ),
      SukunStatusTone.danger => (SukunColors.error, SukunColors.errorSoft),
      SukunStatusTone.neutral => (
        SukunColors.navySoft,
        theme.colorScheme.surfaceContainerLow,
      ),
      SukunStatusTone.brand => (
        theme.colorScheme.secondary,
        theme.colorScheme.primaryContainer,
      ),
    };
    final value = stat.value;
    return SukunSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SukunIconBadge(
                icon: stat.icon,
                size: 32,
                color: foreground,
                backgroundColor: background,
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            loading ? '…' : (value == null ? '—' : banglaDigits(value)),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: SukunColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPatients extends StatefulWidget {
  const _RecentPatients();

  @override
  State<_RecentPatients> createState() => _RecentPatientsState();
}

class _RecentPatientsState extends State<_RecentPatients> {
  late final Future<List<Patient>?> _patients = _load();

  Future<List<Patient>?> _load() async {
    if (!AppEnvironment.isSupabaseConfigured) return null;
    try {
      final rows = await Supabase.instance.client.rpc(
        'admin_search_patients',
        params: {'p_query': '', 'p_limit': 4, 'p_offset': 0},
      );
      return (rows as List<dynamic>)
          .map((row) => Patient.fromJson(Map<String, dynamic>.from(row as Map)))
          .take(4)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Patient>?>(
    future: _patients,
    builder: (context, snapshot) {
      final theme = Theme.of(context);
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SukunSurface(
          child: SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        );
      }
      final patients = snapshot.data;
      if (patients == null || patients.isEmpty) {
        return SukunSurface(
          onTap: () => context.go('/admin/patients'),
          child: Row(
            children: [
              const SukunIconBadge(icon: Icons.person_search_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  patients == null
                      ? 'রোগীর তালিকা খুলে প্রোফাইল দেখুন।'
                      : 'এখনো কোনো রোগী যোগ করা হয়নি।',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        );
      }
      return SukunSurface(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < patients.length; i++) ...[
              if (i > 0) const Divider(indent: 72, endIndent: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                onTap: () => context.go('/admin/patients/${patients[i].id}'),
                leading: CircleAvatar(
                  radius: 21,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.secondary,
                  child: Text(
                    patients[i].fullName.characters.first,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(
                  patients[i].fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  patients[i].patientCode,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SukunColors.muted,
                  ),
                ),
                trailing: SukunStatusPill(
                  label: patients[i].status == PatientStatus.active
                      ? 'চালু'
                      : 'নিষ্ক্রিয়',
                  tone: patients[i].status == PatientStatus.active
                      ? SukunStatusTone.success
                      : SukunStatusTone.neutral,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
