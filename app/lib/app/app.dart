import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/notifications/notification_tap_relay.dart';
import 'package:sukun_life/core/widgets/global_audio_dock.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class SukunLifeApp extends ConsumerStatefulWidget {
  const SukunLifeApp({super.key});

  @override
  ConsumerState<SukunLifeApp> createState() => _SukunLifeAppState();
}

class _SukunLifeAppState extends ConsumerState<SukunLifeApp> {
  StreamSubscription<String>? _openedSubscription;
  bool _nativeNotificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _openedSubscription = ref
        .read(notificationTapRelayProvider)
        .openedTaskIds
        .listen((_) => _routePendingTask());
  }

  void _routePendingTask() {
    // Auth is verified before opening the route. The destination independently
    // checks today's RLS-visible patient task before opening any resource.
    if (ref.read(appSessionProvider).value?.isPatient != true) return;
    final taskId = ref.read(notificationTapRelayProvider).takePending();
    if (taskId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(appSessionProvider).value?.isPatient != true) {
        return;
      }
      ref.read(appRouterProvider).go(patientTodayTaskRoute(taskId));
    });
  }

  @override
  void dispose() {
    unawaited(_openedSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).value;
    if (session?.isPatient == true) {
      // Browser app uses guarded URL navigation; unsupported native local
      // notification initialization is never run by this root on Web.
      if (!kIsWeb && !_nativeNotificationsInitialized) {
        _nativeNotificationsInitialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref
                .read(notificationCoordinatorProvider)
                .initialize()
                .then((_) => _routePendingTask())
                .catchError((Object _) {}),
          );
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _routePendingTask();
      });
    }
    return MaterialApp.router(
      title: 'Sukun Life',
      debugShowCheckedModeBanner: false,
      theme: SukunTheme.light(),
      locale: const Locale('bn', 'BD'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) =>
          Stack(children: [?child, const GlobalAudioDock()]),
    );
  }
}
