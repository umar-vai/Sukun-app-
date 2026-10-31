import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/updates/android_update_panel.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One role-aware account destination for Members and Patients.
/// Profile identity is read-only here: all sensitive edits stay server-authorized.
class UnifiedAccountScreen extends ConsumerStatefulWidget {
  const UnifiedAccountScreen({super.key});

  @override
  ConsumerState<UnifiedAccountScreen> createState() =>
      _UnifiedAccountScreenState();
}

class _UnifiedAccountScreenState extends ConsumerState<UnifiedAccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('লগআউট করা যাচ্ছে না। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).value;
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = session?.displayName?.trim();
    final name = displayName == null || displayName.isEmpty
        ? 'সুকুন সদস্য'
        : displayName;
    final email = user?.email?.trim();
    final isPatient = session?.isPatient == true;
    final theme = Theme.of(context);

    final daily = <_AccountEntry>[
      _AccountEntry(
        key: const Key('account-audio-library'),
        icon: Icons.library_music_outlined,
        title: 'আমার প্লেলিস্ট ও ডাউনলোড',
        subtitle: 'অফলাইন অডিও ও সংরক্ষিত প্লেলিস্ট',
        onTap: () => context.push('/my-media'),
      ),
      _AccountEntry(
        key: const Key('account-routines'),
        icon: Icons.fact_check_outlined,
        title: 'আমার রুটিন',
        subtitle: 'দৈনিক করণীয় ও নিজের নির্ধারিত আমল',
        onTap: () => context.push('/my-routines'),
      ),
      _AccountEntry(
        key: const Key('account-progress'),
        icon: Icons.insights_outlined,
        title: 'অগ্রগতি ও হিস্ট্রি',
        subtitle: '৭ ও ৩০ দিনের কাজের রেকর্ড',
        onTap: () => context.push('/progress'),
      ),
      _AccountEntry(
        icon: Icons.campaign_outlined,
        title: 'নোটিশ',
        subtitle: 'সর্বশেষ ঘোষণা ও প্রয়োজনীয় খবর',
        onTap: () => context.push('/announcements'),
      ),
    ];
    final preferences = <_AccountEntry>[
      _AccountEntry(
        key: const Key('account-appearance'),
        icon: Icons.palette_outlined,
        title: 'অ্যাপের চেহারা ও পড়ার সুবিধা',
        subtitle: 'থিম, রং, বাংলা ও আরবি ফন্ট',
        onTap: () => context.push('/settings/appearance'),
      ),
      _AccountEntry(
        key: const Key('account-notifications'),
        icon: Icons.notifications_active_outlined,
        title: 'নোটিফিকেশন ও রিমাইন্ডার',
        subtitle: 'অনুমতি, ব্যক্তিগত সময়সূচি ও পরীক্ষা',
        onTap: () => context.push('/settings/notifications'),
      ),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        _AccountEntry(
          icon: Icons.system_update_alt_outlined,
          title: 'অ্যাপ আপডেট',
          subtitle: 'অফিসিয়াল নতুন সংস্করণ পরীক্ষা করুন',
          onTap: () => checkAndroidUpdateManually(context),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('আমার অ্যাকাউন্ট')),
      body: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 760;
          final horizontal = wide ? 28.0 : 16.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                key: const Key('account-page-scroll'),
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
                children: [
                  const SukunPageIntro(
                    eyebrow: 'আমার জায়গা',
                    title: 'অ্যাকাউন্ট ও সেটিংস',
                    subtitle: 'আপনার রুটিন, সংরক্ষিত উপকরণ ও পছন্দ এক জায়গায়।',
                  ),
                  const SizedBox(height: 20),
                  SukunSurface(
                    tone: SukunSurfaceTone.navy,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                email == null || email.isEmpty
                                    ? 'লগইন করা অ্যাকাউন্ট'
                                    : email,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.79),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    isPatient ? 'রোগী অ্যাকাউন্ট' : 'সদস্য অ্যাকাউন্ট',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _AccountPanel(
                            title: 'আমার কার্যক্রম',
                            subtitle: 'নিয়মিত ব্যবহার করা সুবিধা',
                            entries: daily,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _AccountPanel(
                            title: 'পছন্দ ও সেটিংস',
                            subtitle: 'নিজের মতো করে অ্যাপ ব্যবহার করুন',
                            entries: preferences,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _AccountPanel(
                      title: 'আমার কার্যক্রম',
                      subtitle: 'নিয়মিত ব্যবহার করা সুবিধা',
                      entries: daily,
                    ),
                    const SizedBox(height: 18),
                    _AccountPanel(
                      title: 'পছন্দ ও সেটিংস',
                      subtitle: 'নিজের মতো করে অ্যাপ ব্যবহার করুন',
                      entries: preferences,
                    ),
                  ],
                  if (isPatient) ...[
                    const SizedBox(height: 18),
                    _AccountPanel(
                      title: 'আমার যত্ন',
                      subtitle: 'শুধু আপনার অনুমোদিত রোগী-সংক্রান্ত তথ্য',
                      entries: [
                        _AccountEntry(
                          icon: Icons.assignment_outlined,
                          title: 'আমার চিকিৎসা পরিকল্পনা',
                          subtitle: 'অনুমোদিত কাজ ও সংযুক্ত উপকরণ',
                          onTap: () => context.push('/patient/plan'),
                        ),
                        _AccountEntry(
                          icon: Icons.health_and_safety_outlined,
                          title: 'চিকিৎসা-সংক্রান্ত সেটিংস',
                          subtitle: 'আপনার অনুমোদিত রিমাইন্ডার নিয়ন্ত্রণ',
                          onTap: () => context.push('/patient/profile'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('account-sign-out'),
                      onPressed: _signingOut ? null : _signOut,
                      icon: _signingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: Text(
                        _signingOut ? 'লগআউট হচ্ছে…' : 'অ্যাকাউন্ট থেকে লগআউট',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'আপনার অ্যাকাউন্ট ও ব্যক্তিগত তথ্য অনুমতি অনুযায়ী সুরক্ষিত থাকে।',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccountEntry {
  const _AccountEntry({
    this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key? key;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final List<_AccountEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SukunSurface(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 12),
            child: Text(subtitle, style: theme.textTheme.bodySmall),
          ),
          for (var i = 0; i < entries.length; i++) ...[
            if (i != 0) const Divider(height: 1, indent: 60),
            ListTile(
              key: entries[i].key,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              leading: SukunIconBadge(icon: entries[i].icon, size: 42),
              title: Text(
                entries[i].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                entries[i].subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: entries[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}
