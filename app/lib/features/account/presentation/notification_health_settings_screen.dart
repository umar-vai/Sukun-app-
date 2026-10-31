import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/notifications/notification_coordinator.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/features/personal_routines/data/personal_reminder_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_notification_service.dart';

String notificationPermissionHint({
  required bool granted,
  required bool isWeb,
}) {
  if (!granted) {
    return isWeb
        ? 'ব্রাউজারে নোটিফিকেশন অনুমতি দেওয়া নেই। সাইটের অনুমতি পরীক্ষা করুন।'
        : 'নোটিফিকেশন অনুমতি বন্ধ। ফোনের অ্যাপ সেটিংসও পরীক্ষা করুন।';
  }
  return isWeb
      ? 'অনুমতি আছে। ট্যাব বন্ধ অবস্থায় রিমাইন্ডারের জন্য Web Push-ও সচল থাকতে হবে।'
      : 'নোটিফিকেশন অনুমতি আছে। ফোনের ব্যাটারি নীতি ডেলিভারি বিলম্ব করতে পারে।';
}

/// Read-only diagnostics plus explicit opt-ins routed through the existing
/// owner-scoped reminder services. Never pretends that a permission alone
/// guarantees notification delivery on browsers or battery-limited devices.
class NotificationHealthSettingsScreen extends ConsumerStatefulWidget {
  const NotificationHealthSettingsScreen({super.key});

  @override
  ConsumerState<NotificationHealthSettingsScreen> createState() =>
      _NotificationHealthSettingsScreenState();
}

class _NotificationHealthSettingsScreenState
    extends ConsumerState<NotificationHealthSettingsScreen> {
  bool _loading = true;
  bool _busy = false;
  bool? _permissionGranted;
  bool? _preciseAvailable;
  bool? _personalEnabled;
  bool? _prayerEnabled;
  CareNotificationStatus? _care;
  String? _notice;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final originalUser = ref.read(appSessionProvider).value?.userId;
    if (originalUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final gateway = ref.read(localNotificationsGatewayProvider);
      await gateway.initialize();
      final permission = await gateway.isPermissionGranted();
      final precise = await gateway.canSchedulePrecisely();
      final personal = await ref
          .read(personalReminderServiceProvider)
          .isEnabled();
      final prayerEnabled = await ref
          .read(prayerNotificationServiceProvider)
          .isEnabled();
      final isPatient = ref.read(appSessionProvider).value?.isPatient == true;
      final care = isPatient
          ? await ref.read(notificationCoordinatorProvider).status()
          : null;
      if (!mounted ||
          ref.read(appSessionProvider).value?.userId != originalUser) {
        return;
      }
      setState(() {
        _permissionGranted = permission;
        _preciseAvailable = precise;
        _personalEnabled = personal;
        _prayerEnabled = prayerEnabled;
        _care = care;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notice = 'এখন নোটিফিকেশনের অবস্থা জানা যাচ্ছে না। আবার চেষ্টা করুন।';
      });
    }
  }

  Future<void> _change(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'সেটিংস পরিবর্তন করা যায়নি। আবার চেষ্টা করুন।',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _refresh();
  }

  Future<void> _requestPermission() => _change(() async {
    final gateway = ref.read(localNotificationsGatewayProvider);
    await gateway.initialize();
    if (!await gateway.requestPermission()) {
      if (mounted) {
        setState(
          () => _notice = 'অনুমতি পাওয়া যায়নি। ডিভাইসের সেটিংস পরীক্ষা করুন।',
        );
      }
    }
  });

  Future<void> _sendTestNotification() => _change(() async {
    final gateway = ref.read(localNotificationsGatewayProvider);
    await gateway.initialize();
    if (!await gateway.isPermissionGranted()) {
      if (mounted) {
        setState(() => _notice = 'প্রথমে ফোনে নোটিফিকেশন অনুমতি দিন।');
      }
      return;
    }
    await gateway.showRemote(
      title: 'সুকুন লাইফ · টেস্ট নোটিফিকেশন',
      body: 'এই বার্তাটি আপনার ফোনের নোটিফিকেশন প্যানেলে দেখা যাওয়ার কথা।',
    );
    if (mounted) {
      setState(
        () => _notice = 'টেস্ট নোটিফিকেশন পাঠানো হয়েছে। ফোনের নোটিফিকেশন প্যানেল পরীক্ষা করুন।',
      );
    }
  });

  Future<void> _reschedulePersonal() => _change(() async {
    final service = ref.read(personalReminderServiceProvider);
    if (!await service.isEnabled()) {
      if (mounted) {
        setState(
          () => _notice = 'নিজের তৈরি রুটিনের রিমাইন্ডার আগে চালু করুন।',
        );
      }
      return;
    }
    final count = await service.refresh();
    if (mounted) {
      setState(
        () => _notice = count == 0
            ? 'এখন কোনো ভবিষ্যৎ রিমাইন্ডার শিডিউল হয়নি। সক্রিয় রুটিন ও সময় পরীক্ষা করুন।'
            : '$countটি আসন্ন রিমাইন্ডার শিডিউল করা হয়েছে। ফোনের ব্যাটারি ও অ্যালার্ম অনুমতি ডেলিভারি প্রভাবিত করতে পারে।',
      );
    }
  });

  Future<void> _togglePersonal(bool enabled) => _change(() async {
    final service = ref.read(personalReminderServiceProvider);
    if (enabled) {
      if (!await service.enable()) {
        throw StateError('Permission not granted');
      }
    } else {
      await service.disable();
    }
  });

  Future<void> _togglePrayer(bool enabled) => _change(() async {
    final service = ref.read(prayerNotificationServiceProvider);
    if (enabled) {
      if (!await service.enable()) {
        throw StateError('Permission denied');
      }
    } else {
      await service.disable();
    }
  });

  Future<void> _toggleCare(bool enabled) => _change(() async {
    final coordinator = ref.read(notificationCoordinatorProvider);
    if (enabled) {
      if (!await coordinator.enable()) {
        throw StateError('Permission not granted');
      }
    } else {
      await coordinator.disable();
    }
  });

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).value;
    final signedIn = session?.isAuthenticated == true;
    final patient = session?.isPatient == true;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(
        title: const Text('নোটিফিকেশন ও রিমাইন্ডার'),
        actions: [
          IconButton(
            tooltip: 'অবস্থা আবার পরীক্ষা করুন',
            onPressed: _busy ? null : () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !signedIn
          ? const Center(child: Text('রিমাইন্ডার নিয়ন্ত্রণ করতে লগইন করুন।'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
              children: [
                Text(
                  'নোটিফিকেশন স্বাস্থ্য পরীক্ষা',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (_loading) const LinearProgressIndicator(),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_notice!),
                  ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          _permissionGranted == true
                              ? Icons.check_circle_outline
                              : Icons.notifications_off_outlined,
                        ),
                        title: const Text('নোটিফিকেশন অনুমতি'),
                        subtitle: Text(
                          _permissionGranted == null
                              ? 'অবস্থা পরীক্ষা চলছে'
                              : notificationPermissionHint(
                                  granted: _permissionGranted!,
                                  isWeb: kIsWeb,
                                ),
                        ),
                      ),
                      if (_permissionGranted == true)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => unawaited(_sendTestNotification()),
                            icon: const Icon(Icons.notification_add_outlined),
                            label: const Text('এখন টেস্ট নোটিফিকেশন পাঠান'),
                          ),
                        ),
                      if (_permissionGranted == false)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => unawaited(_requestPermission()),
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                            label: const Text('অনুমতি দিন'),
                          ),
                        ),
                      if (android) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            _preciseAvailable == true
                                ? Icons.schedule
                                : Icons.alarm_off_outlined,
                          ),
                          title: const Text('নির্দিষ্ট সময়ে অ্যালার্ম'),
                          subtitle: Text(
                            _preciseAvailable == true
                                ? 'নির্ভুলভাবে সময় নির্ধারণের অনুমতি পাওয়া গেছে।'
                                : 'নির্ভুল অ্যালার্মের অনুমতি প্রয়োজন হতে পারে।',
                          ),
                          trailing: TextButton(
                            onPressed: _busy
                                ? null
                                : () => unawaited(
                                    _change(() async {
                                      final granted = await ref
                                          .read(
                                            localNotificationsGatewayProvider,
                                          )
                                          .requestPreciseSchedulingPermission();
                                      if (granted &&
                                          await ref
                                              .read(
                                                personalReminderServiceProvider,
                                              )
                                              .isEnabled()) {
                                        await ref
                                            .read(
                                              personalReminderServiceProvider,
                                            )
                                            .refresh();
                                      }
                                    }),
                                  ),
                            child: const Text('পরীক্ষা করুন'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'আপনার সক্রিয় রিমাইন্ডার',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('personal-reminder-opt-in'),
                        title: const Text('নিজের তৈরি রুটিন'),
                        subtitle: const Text(
                          'আপনি তৈরি করা আমলের সময়সূচি অনুযায়ী',
                        ),
                        value: _personalEnabled ?? false,
                        onChanged: _busy || _loading || _personalEnabled == null
                            ? null
                            : (value) => unawaited(_togglePersonal(value)),
                      ),
                      if (_personalEnabled == true) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => unawaited(_reschedulePersonal()),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('রিমাইন্ডার আবার শিডিউল করুন'),
                          ),
                        ),
                      ],
                      if (patient) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          key: const Key('patient-care-reminder-opt-in'),
                          title: const Text('অনুমোদিত চিকিৎসা পরিকল্পনা'),
                          subtitle: const Text(
                            'আপনার নিজের রোগী পরিকল্পনার রিমাইন্ডার',
                          ),
                          value: _care?.enabled ?? false,
                          onChanged: _busy || _loading || _care == null
                              ? null
                              : (value) => unawaited(_toggleCare(value)),
                        ),
                        if (_care != null && !_care!.lastSyncSucceeded)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              'শেষবার রিমাইন্ডার আপডেট সফল হয়নি। আবার পরীক্ষা করুন।',
                            ),
                          ),
                      ],
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const Key('prayer-waqt-alert-settings-opt-in'),
                        secondary: const Icon(Icons.mosque_outlined),
                        title: const Text('পাঁচ ওয়াক্তের নোটিফিকেশন'),
                        subtitle: Text(
                          kIsWeb
                              ? 'ট্যাব চালু থাকা অবস্থায় ওয়াক্তের সময় নোটিফিকেশন। বন্ধ ব্রাউজারে Web Push এখনো নেই।'
                              : 'নিজের শহর অনুযায়ী পাঁচ ওয়াক্ত শুরু হলে ফোনে নোটিফিকেশন।',
                        ),
                        value: _prayerEnabled ?? false,
                        onChanged: _busy || _loading || _prayerEnabled == null
                            ? null
                            : (enabled) => unawaited(_togglePrayer(enabled)),
                      ),
                      ListTile(
                        title: const Text('শহর ও হিসাবপদ্ধতি'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/prayer-times/settings'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.event_repeat_outlined),
                        title: const Text('রুটিনের সময় পরিবর্তন'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/my-routines'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'সমস্যা হলে কী করবেন?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (kIsWeb)
                  const Text(
                    'ব্রাউজারে Sukun Life-এর নোটিফিকেশন অনুমতি চালু আছে কি না দেখুন।',
                  )
                else if (android)
                  const Text(
                    'ফোনের Settings → Apps → Sukun Life → Notifications চালু করুন।',
                  )
                else
                  const Text(
                    'ফোনের নোটিফিকেশন অনুমতি ও Do Not Disturb সেটিংস দেখুন।',
                  ),
              ],
            ),
    );
  }
}
