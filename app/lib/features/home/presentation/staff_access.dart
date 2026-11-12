import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';

/// True when the signed-in admin-area user is a raqi (not the main admin).
/// Used only to hide controls a raqi may not use; the database enforces the
/// same rules. Outside a ProviderScope (widget tests) it returns false.
bool isRaqiSession(BuildContext context) {
  try {
    return ProviderScope.containerOf(
          context,
          listen: false,
        ).read(appSessionProvider).value?.isRaqi ==
        true;
  } catch (_) {
    return false;
  }
}
