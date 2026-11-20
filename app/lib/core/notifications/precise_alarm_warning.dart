import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// Shown only on Android when the system denies exact alarms. Without that
/// access Android may deliver a waqt or amal reminder long after its time,
/// so the user is told plainly and offered the one-tap system setting.
/// Renders nothing while access is granted or still being checked.
class PreciseAlarmWarning extends ConsumerStatefulWidget {
  const PreciseAlarmWarning({
    this.onGranted,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  /// Space around the card, applied only while it is visible.
  final EdgeInsetsGeometry margin;

  /// Called once access turns on, so callers can reschedule precisely.
  final VoidCallback? onGranted;

  @override
  ConsumerState<PreciseAlarmWarning> createState() =>
      _PreciseAlarmWarningState();
}

class _PreciseAlarmWarningState extends ConsumerState<PreciseAlarmWarning>
    with WidgetsBindingObserver {
  bool? _precise;
  bool _busy = false;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    if (_supported) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user grants access in system settings and comes back.
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final gateway = ref.read(localNotificationsGatewayProvider);
      await gateway.initialize();
      final precise = await gateway.canSchedulePrecisely();
      if (!mounted) return;
      final turnedOn = _precise == false && precise;
      setState(() => _precise = precise);
      if (turnedOn) widget.onGranted?.call();
    } on Object {
      // Unknown state: stay quiet rather than show a false alarm.
    }
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(localNotificationsGatewayProvider)
          .requestPreciseSchedulingPermission();
      await _check();
    } on Object {
      // The setting can still be opened from notification settings.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported || _precise != false) return const SizedBox.shrink();
    return Padding(padding: widget.margin, child: _card());
  }

  Widget _card() {
    return SukunSurface(
      key: const Key('precise-alarm-warning'),
      tone: SukunSurfaceTone.warning,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.alarm_off_outlined, color: SukunColors.nightNavy),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'নোটিফিকেশন দেরিতে আসতে পারে। ঠিক সময়ে নামাজ ও আমলের '
                  'নোটিফিকেশন পেতে "অ্যালার্ম ও রিমাইন্ডার" অনুমতি চালু করুন।',
                  style: TextStyle(color: SukunColors.nightNavy),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => unawaited(_request()),
              child: const Text('অনুমতি দিন'),
            ),
          ),
        ],
      ),
    );
  }
}
