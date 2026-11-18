import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/notifications/power_settings_gateway.dart';

bool get _isAndroidDevice =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Shown right after the user turns on prayer or care alerts. The two steps
/// below are what decide, on phones with aggressive power management (for
/// example Honor/Huawei, Xiaomi, Oppo, Vivo), whether a Maghrib or Isha alert
/// rings while the screen is off. Nothing is changed without the user's tap.
Future<void> showReliableDeliveryGuide(BuildContext context) async {
  if (!_isAndroidDevice) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SingleChildScrollView(child: ReliableDeliveryCard()),
      ),
    ),
  );
}

/// Live status plus one-tap fixes for background delivery on Android.
class ReliableDeliveryCard extends ConsumerStatefulWidget {
  const ReliableDeliveryCard({super.key});

  @override
  ConsumerState<ReliableDeliveryCard> createState() =>
      _ReliableDeliveryCardState();
}

class _ReliableDeliveryCardState extends ConsumerState<ReliableDeliveryCard>
    with WidgetsBindingObserver {
  bool? _unrestricted;
  bool _vendorStep = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user comes back from the system dialog: show the new state.
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final gateway = ref.read(powerSettingsGatewayProvider);
    final unrestricted = await gateway.isUnrestricted();
    final maker = await gateway.manufacturer();
    if (!mounted) return;
    setState(() {
      _unrestricted = unrestricted;
      _vendorStep = needsVendorAutostartStep(maker);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroidDevice) return const SizedBox.shrink();
    final gateway = ref.read(powerSettingsGatewayProvider);
    final ok = _unrestricted == true;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'নোটিফিকেশন যেন ঠিক সময়ে আসে',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'কিছু ফোন ব্যাটারি বাঁচাতে অ্যাপ বন্ধ করে দেয়, তখন মাগরিব বা ইশার '
          'নোটিফিকেশন আসে না। নিচের ধাপগুলো একবার করে নিন।',
        ),
        const SizedBox(height: 12),
        ListTile(
          key: const Key('reliable-delivery-battery'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            ok ? Icons.check_circle_outline : Icons.battery_alert_outlined,
          ),
          title: const Text('১. ব্যাটারি সীমাবদ্ধতা তুলে দিন'),
          subtitle: Text(
            _unrestricted == null
                ? 'অবস্থা দেখা হচ্ছে'
                : ok
                ? 'ঠিক আছে। ফোন এই অ্যাপের অ্যালার্ম আটকাবে না।'
                : 'এখন চালু নেই। বাটনে চাপ দিয়ে "অনুমতি দিন" বা "Allow" বেছে নিন।',
          ),
          trailing: ok
              ? null
              : FilledButton(
                  onPressed: () => unawaited(gateway.requestUnrestricted()),
                  child: const Text('ঠিক করুন'),
                ),
        ),
        if (_vendorStep)
          ListTile(
            key: const Key('reliable-delivery-autostart'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.power_settings_new_outlined),
            title: const Text('২. অটোস্টার্ট / Protected apps চালু করুন'),
            subtitle: const Text(
              'Honor, Huawei, Xiaomi, Oppo, Vivo ও Samsung ফোনে এটি বাধ্যতামূলক। '
              'তালিকায় Sukun Life খুঁজে চালু করুন, আর "ম্যানুয়ালি পরিচালনা" '
              'থাকলে তিনটি অপশনই (Auto-launch, Secondary launch, Run in '
              'background) চালু করুন।',
            ),
            trailing: OutlinedButton(
              onPressed: () => unawaited(gateway.openAutostartSettings()),
              child: const Text('খুলুন'),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'ফোন থেকে অ্যাপটি "Force stop" বা ক্লিয়ার করবেন না। তাতে সব '
          'শিডিউল করা অ্যালার্ম মুছে যায়।',
        ),
      ],
    );
  }
}
