import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/notifications/notification_coordinator.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, this.displayName});

  final String? displayName;

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  late Future<CareNotificationStatus> _notificationStatus;
  bool _updatingNotifications = false;

  @override
  void initState() {
    super.initState();
    _refreshNotificationStatus();
  }

  void _refreshNotificationStatus() {
    _notificationStatus = ref.read(notificationCoordinatorProvider).status();
  }

  Future<void> _enableNotifications() async {
    if (_updatingNotifications) return;
    setState(() => _updatingNotifications = true);
    final enabled = await ref.read(notificationCoordinatorProvider).enable();
    if (!mounted) return;
    setState(() {
      _updatingNotifications = false;
      _refreshNotificationStatus();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'মনে করিয়ে দেওয়ার অনুমতি চালু হয়েছে।' : 'অনুমতি পাওয়া যায়নি। ফোনের সেটিংস থেকে চালু করতে পারেন।',
        ),
      ),
    );
  }

  Future<void> _disableNotifications() async {
    if (_updatingNotifications) return;
    setState(() => _updatingNotifications = true);
    await ref.read(notificationCoordinatorProvider).disable();
    if (!mounted) return;
    setState(() {
      _updatingNotifications = false;
      _refreshNotificationStatus();
    });
  }

  Future<void> _enablePreciseTiming() async {
    if (_updatingNotifications) return;
    setState(() => _updatingNotifications = true);
    final granted = await ref
        .read(notificationCoordinatorProvider)
        .requestPreciseTimingAccess();
    if (!mounted) return;
    setState(() {
      _updatingNotifications = false;
      _refreshNotificationStatus();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted ? 'নির্দিষ্ট সময়ে মনে করিয়ে দেওয়ার অনুমতি চালু হয়েছে।' : 'নির্দিষ্ট সময়ের অনুমতি পাওয়া যায়নি। ফোন কিছুটা দেরিতে জানাতে পারে।',
        ),
      ),
    );
  }

  Future<void> _retryNotifications() async {
    if (_updatingNotifications) return;
    setState(() => _updatingNotifications = true);
    await ref.read(notificationCoordinatorProvider).syncIfEnabled();
    if (!mounted) return;
    setState(() {
      _updatingNotifications = false;
      _refreshNotificationStatus();
    });
  }

  Future<void> _signOut() async {
    await ref.read(notificationCoordinatorProvider).disable();
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      title: 'আমার তথ্য',
      selectedIndex: 4,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SukunPageIntro(
            eyebrow: 'অ্যাকাউন্ট ও সেটিংস',
            title: 'আমার তথ্য',
            subtitle: 'মনে করিয়ে দেওয়া, প্রয়োজনীয় সুবিধা ও অ্যাকাউন্টের সেটিংস।',
          ),
          const SizedBox(height: 20),
          SukunSurface(
            tone: SukunSurfaceTone.navy,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName ?? 'রোগী',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'সুকুন লাইফ রোগীর অ্যাকাউন্ট',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_user_outlined, color: Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<CareNotificationStatus>(
            future: _notificationStatus,
            builder: (context, snapshot) {
              final status = snapshot.data;
              final enabled =
                  status?.enabled == true && status?.permissionGranted == true;
              return SukunSurface(
                tone: enabled
                    ? SukunSurfaceTone.success
                    : SukunSurfaceTone.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SukunIconBadge(
                          icon: Icons.notifications_active_outlined,
                          color: enabled
                              ? SukunColors.success
                              : SukunColors.deepTide,
                          backgroundColor: enabled
                              ? Colors.white
                              : SukunColors.softBlue,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'কাজের কথা মনে করিয়ে দেওয়া',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      enabled
                          ? status!.preciseTimingAvailable
                                ? 'নির্ধারিত সময় দেওয়া ও অনুমোদিত কাজের জন্য মনে করিয়ে দেওয়ার অনুমতি আছে।'
                                : 'মনে করিয়ে দেওয়া চালু আছে। নির্দিষ্ট সময়ের অনুমতি না থাকলে ফোন কিছুটা দেরিতে জানাতে পারে।'
                          : 'শুধু আপনার অনুমোদিত পরিকল্পনার নির্ধারিত কাজের সময় মনে করিয়ে দেওয়া হবে।',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'পরে মনে করিয়ে দেওয়ার সময়ও আপনি ঠিক করতে পারবেন। ফোনের বিরক্ত করবেন না সেটিংস চালু থাকলে শব্দ নাও হতে পারে।',
                    ),
                    const SizedBox(height: 14),
                    if (enabled && status?.lastSyncSucceeded == false) ...[
                      const Text(
                        'মনে করিয়ে দেওয়ার অনুমতি আছে, তবে সময় ঠিক করা যায়নি। আবার চেষ্টা করুন।',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _retryNotifications,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('আবার সময় ঠিক করুন'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        _updatingNotifications)
                      const Center(child: CircularProgressIndicator())
                    else if (enabled)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (!status!.preciseTimingAvailable)
                            FilledButton.tonalIcon(
                              onPressed: _enablePreciseTiming,
                              icon: const Icon(Icons.alarm_outlined),
                              label: const Text('নির্দিষ্ট সময়ের অনুমতি দিন'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _disableNotifications,
                            icon: const Icon(Icons.notifications_off_outlined),
                            label: const Text('মনে করিয়ে দেওয়া বন্ধ করুন'),
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: _enableNotifications,
                        icon: const Icon(Icons.notifications_outlined),
                        label: const Text('মনে করিয়ে দেওয়া চালু করুন'),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/patient/notifications'),
            icon: const Icon(Icons.mark_email_unread_outlined),
            label: const Text('আমার বার্তাগুলো দেখুন'),
          ),
          const SizedBox(height: 16),
          SukunSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ইসলামিক সুবিধা',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/prayer-times'),
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('নামাজের সময়'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/qibla'),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('কিবলার দিক'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('বের হয়ে যান'),
          ),
        ],
      ),
    );
  }
}
