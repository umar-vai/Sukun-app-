import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';

/// Rebuilds [child] from scratch whenever the selected profile changes.
///
/// Patient screens keep their loaded data in `State`. Giving the subtree a
/// key per profile discards that State on a switch, so one profile's numbers
/// (for example 6/10) can never remain on screen for another (3/8).
class ProfileScoped extends ConsumerWidget {
  const ProfileScoped({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientId = ref.watch(activePatientIdProvider);
    return KeyedSubtree(key: ValueKey<String?>(patientId), child: child);
  }
}

/// App-level reaction to a profile switch. Place once above the router.
///
/// When the selected profile changes it re-registers this device with the
/// new patient ID, cancels the previous profile's pending local reminders
/// and schedules the new profile's, without duplicates (see
/// `NotificationCoordinator.resyncForActiveProfile`).
class ActiveProfileEffects extends ConsumerWidget {
  const ActiveProfileEffects({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(activePatientIdProvider, (previous, next) {
      if (next == null || previous == next) return;
      unawaited(
        ref
            .read(notificationCoordinatorProvider)
            .resyncForActiveProfile()
            .catchError((Object _) {}),
      );
    });
    return child;
  }
}
