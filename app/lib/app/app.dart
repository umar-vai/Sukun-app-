import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/core/updates/android_update_panel.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/features/personal_routines/data/personal_reminder_service.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/notifications/public_notice_tap_qa_diagnostics.dart';
import 'package:sukun_life/core/notifications/notification_tap_relay.dart';
import 'package:sukun_life/core/widgets/global_audio_dock.dart';
import 'package:sukun_life/l10n/app_localizations.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_notice_auto_popup.dart';

class SukunLifeApp extends ConsumerStatefulWidget {
  const SukunLifeApp({super.key});

  @override
  ConsumerState<SukunLifeApp> createState() => _SukunLifeAppState();
}

class _SukunLifeAppState extends ConsumerState<SukunLifeApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _openedSubscription;
  StreamSubscription<String>? _openedPersonalSubscription;
  StreamSubscription<String>? _openedRichLocalSubscription;
  bool _nativeNotificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(BengaliFontSettings.instance.load());
    unawaited(AppDisplaySettings.instance.load());
    _openedSubscription = ref
        .read(notificationTapRelayProvider)
        .openedTaskIds
        .listen((_) => _routePendingTask());
    _openedRichLocalSubscription = ref
        .read(notificationTapRelayProvider)
        .openedUniversalNoticeIds
        .listen((_) {
          // StreamController delivery can happen after a completed UI frame.
          // Android may resume into an otherwise idle Flutter frame scheduler.
          WidgetsBinding.instance.scheduleFrame();
          _routePendingUniversal();
        });
    _openedPersonalSubscription = ref
        .read(notificationTapRelayProvider)
        .openedPersonalActionIds
        .listen((_) => _routePendingPersonal());
    // Native Android public notices are guest opt-in too. Create the OS
    // channel before any background FCM, without registering patient tokens,
    // requesting notification permission, or enabling global broadcasts.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !AppEnvironment.isFirebaseConfigured) {
      unawaited(
        ref
            .read(localNotificationsGatewayProvider)
            .initialize()
            .catchError((Object _) {}),
      );
    }
    // Guest subscribers need the same foreground and notification-tap
    // listener as signed-in patients. initialize() only creates channels and
    // listens for FCM; it does not register patient tokens or request consent.
    // A single coordinator consumes the cold-start FCM message so the public
    // notice route cannot race a second getInitialMessage() consumer.
    if (!kIsWeb && AppEnvironment.isFirebaseConfigured) {
      unawaited(
        ref
            .read(notificationCoordinatorProvider)
            .initialize()
            .then((_) {
              _routePendingTask();
              _routePendingPersonal();
              _routePendingUniversal();
            })
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    // The platform can resume before a pending FCM tap callback reaches
    // Flutter. Retry after the resumed frame without consuming an early UUID.
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _routePendingUniversal();
    });
  }

  void _routePendingUniversal() {
    // An Android FCM tap may arrive before the asynchronous Guest session
    // and MaterialApp.router are ready. Never consume the UUID that early.
    if (!mounted || !ref.read(appSessionProvider).hasValue) return;
    if (ref.read(notificationTapRelayProvider).pendingUniversalNotice == null) {
      return;
    }
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(appSessionProvider).hasValue) return;
      final relay = ref.read(notificationTapRelayProvider);
      final id = relay.pendingUniversalNotice;
      if (id == null) return;
      // Read the live router *after* session restoration. Earlier GoRouter
      // instances are replaced by the role-aware provider during startup.
      final router = ref.read(appRouterProvider);
      if (relay.takePendingUniversalNotice() != id) return;
      router.go('/announcements/$id');
      PublicNoticeTapQaDiagnostics.routeRequested();
    });
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

  void _routePendingPersonal() {
    final session = ref.read(appSessionProvider).value;
    if (session?.isAuthenticated != true || session!.requiresCredentialChange) {
      return;
    }
    final actionId = ref
        .read(notificationTapRelayProvider)
        .takePendingPersonalAction();
    if (actionId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ref.read(appSessionProvider).value?.isAuthenticated != true) {
        return;
      }
      // Destination will independently query owner-scoped action via RLS.
      ref.read(appRouterProvider).go(personalActionRoute(actionId));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_openedSubscription?.cancel());
    unawaited(_openedPersonalSubscription?.cancel());
    unawaited(_openedRichLocalSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSessionProvider, (previous, next) {
      final oldId = previous?.value?.userId;
      final newId = next.value?.userId;
      if (oldId == newId) return;
      final service = ref.read(personalReminderServiceProvider);
      // Cancel old-owner reminders on shared devices before a new account
      // can use the app. No patient records are consulted or modified.
      if (oldId != null) {
        unawaited(service.cancelOwner(oldId).catchError((Object _) {}));
      }
      if (newId != null && next.value?.requiresCredentialChange != true) {
        unawaited(service.refresh().catchError((Object _) => 0));
      }
    });
    final sessionState = ref.watch(appSessionProvider);
    final session = sessionState.value;
    if (sessionState.hasValue) {
      // Guest users must also finish a deferred background/cold-start tap.
      // MaterialApp.router is attached by this frame's end.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _routePendingUniversal();
      });
    }
    if (session?.isAuthenticated == true) {
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
                .then((_) {
                  _routePendingTask();
                  _routePendingPersonal();
                  _routePendingUniversal();
                })
                .catchError((Object _) {}),
          );
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _routePendingTask();
          _routePendingPersonal();
        }
      });
    }
    return ValueListenableBuilder<BengaliFontChoice>(
      valueListenable: BengaliFontSettings.instance,
      builder: (context, selectedFont, _) =>
          ValueListenableBuilder<AppDisplayPreferences>(
            valueListenable: AppDisplaySettings.instance,
            builder: (context, display, _) => MaterialApp.router(
              title: 'Sukun Life',
              debugShowCheckedModeBanner: false,
              theme: SukunTheme.light(
                bengaliFont: selectedFont,
                bengaliScale: display.bengaliScale,
                accentPalette: display.accentPalette,
              ),
              darkTheme: SukunTheme.dark(
                bengaliFont: selectedFont,
                bengaliScale: display.bengaliScale,
                accentPalette: display.accentPalette,
              ),
              themeMode: display.themeMode,
              locale: const Locale('bn', 'BD'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: ref.watch(appRouterProvider),
              builder: (context, child) => AndroidUpdateAutoPopup(
                child: UniversalNoticeAutoPopup(
                  child: Stack(children: [?child, const GlobalAudioDock()]),
                ),
              ),
            ),
          ),
    );
  }
}
