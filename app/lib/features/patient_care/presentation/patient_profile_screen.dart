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
          enabled ? 'Care reminders are enabled on this device.' : 'Notification permission was not granted. You can enable it in device settings.',
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
          granted ? 'Precise reminder timing is enabled.' : 'Precise timing was not enabled. Android may deliver reminders within a time window.',
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await ref.read(notificationCoordinatorProvider).disable();
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      title: 'Profile',
      selectedIndex: 4,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SukunPageIntro(
            eyebrow: 'Account & preferences',
            title: 'Your profile',
            subtitle: 'Manage reminders, utilities, and secure access.',
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
                        widget.displayName ?? 'Patient',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sukun Life patient account',
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
                            'Care reminders',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      enabled
                          ? status!.preciseTimingAvailable
                                ? 'Enabled with precise timing for approved actions that have an exact reminder time.'
                                : 'Enabled for approved actions. Android may deliver reminders within a time window until precise timing is allowed.'
                          : 'Get reminders only for actions and times approved in your care plan.',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Snooze times you choose are also scheduled. Reminders never override Do Not Disturb.',
                    ),
                    const SizedBox(height: 14),
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
                              label: const Text('Allow precise timing'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _disableNotifications,
                            icon: const Icon(Icons.notifications_off_outlined),
                            label: const Text('Turn off reminders'),
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: _enableNotifications,
                        icon: const Icon(Icons.notifications_outlined),
                        label: const Text('Enable reminders'),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SukunSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Islamic utilities',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/prayer-times'),
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Prayer times'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/qibla'),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Qibla'),
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
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
