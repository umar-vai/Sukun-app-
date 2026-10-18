import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/core/updates/android_update_panel.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/features/personal_routines/data/personal_reminder_service.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/notifications/notification_tap_relay.dart';
import 'package:sukun_life/core/widgets/global_audio_dock.dart';
import 'package:sukun_life/l10n/app_localizations.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_push.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_notice_auto_popup.dart';

class SukunLifeApp extends ConsumerStatefulWidget {
  const SukunLifeApp({super.key});

  @override
  ConsumerState<SukunLifeApp> createState() => _SukunLifeAppState();
}

class _SukunLifeAppState extends ConsumerState<SukunLifeApp> {
  StreamSubscription<String>? _openedSubscription;
  StreamSubscription<String>? _openedPersonalSubscription;
  StreamSubscription<RemoteMessage>? _openedUniversalSubscription;
  bool _nativeNotificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _openedSubscription = ref
        .read(notificationTapRelayProvider)
        .openedTaskIds
        .listen((_) => _routePendingTask());
    _openedPersonalSubscription = ref
        .read(notificationTapRelayProvider)
        .openedPersonalActionIds
        .listen((_) => _routePendingPersonal());
    if (!kIsWeb && AppEnvironment.isFirebaseConfigured) {
      _openedUniversalSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen((message) => _openUniversalAnnouncement(message.data));
      unawaited(
        FirebaseMessaging.instance
            .getInitialMessage()
            .then((message) {
              if (message == null) return;
              final payload = message.data;
              if (universalNoticeIdFromPush(payload) != null) {
                _openUniversalAnnouncement(payload);
                return;
              }
              // getInitialMessage is consumptive: retain the existing
              // patient-task cold-start route rather than stealing its tap.
              if (payload['type'] == 'care_reminder') {
                final id = payload['task_id'];
                if (id is String) {
                  ref
                      .read(notificationTapRelayProvider)
                      .accept('care_task:$id');
                }
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  void _openUniversalAnnouncement(Map<String, dynamic> payload) {
    final noticeId = universalNoticeIdFromPush(payload);
    if (noticeId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appRouterProvider).go('/announcements/$noticeId');
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
    unawaited(_openedSubscription?.cancel());
    unawaited(_openedPersonalSubscription?.cancel());
    unawaited(_openedUniversalSubscription?.cancel());
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
    final session = ref.watch(appSessionProvider).value;
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
    return MaterialApp.router(
      title: 'Sukun Life',
      debugShowCheckedModeBanner: false,
      theme: SukunTheme.light(),
      locale: const Locale('bn', 'BD'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => AndroidUpdateAutoPopup(
        child: UniversalNoticeAutoPopup(
          child: Stack(children: [?child, const GlobalAudioDock()]),
        ),
      ),
    );
  }
}
