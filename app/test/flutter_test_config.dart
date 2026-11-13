import 'dart:async';

import 'package:sukun_life/features/home/presentation/public_welcome_screen.dart';

/// The public landing reads the release manifest over the network in
/// production. Tests keep it closed by default so no real request or pending
/// timer is created; a test may set the override to `true` to opt in.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugPublicApkDownloadOverride = false;
  await testMain();
}
