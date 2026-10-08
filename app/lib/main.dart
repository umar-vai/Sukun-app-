import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/platform/platform_startup.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_launch_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppEnvironment.isFirebaseConfigured) return;
  if (Firebase.apps.isEmpty) {
    await AppEnvironment.initialize();
  }
  if (message.data['type'] == 'plan_updated') {
    final container = ProviderContainer();
    try {
      await container.read(notificationCoordinatorProvider).syncIfEnabled();
    } finally {
      container.dispose();
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _SukunBootstrap()));
}

Future<void> _initializeServices() async {
  await initializePlatformServices();
  await AppEnvironment.initialize();
  if (AppEnvironment.isFirebaseConfigured) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
}

class _SukunBootstrap extends StatefulWidget {
  const _SukunBootstrap();

  @override
  State<_SukunBootstrap> createState() => _SukunBootstrapState();
}

class _SukunBootstrapState extends State<_SukunBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'Sukun Life',
            debugShowCheckedModeBanner: false,
            theme: SukunTheme.light(),
            home: const SukunLaunchScreen(),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Sukun Life',
            debugShowCheckedModeBanner: false,
            theme: SukunTheme.light(),
            home: Scaffold(
              body: AppErrorState(
                message: 'Sukun Life could not start securely.',
                onRetry: () => setState(() {
                  _initialization = _initializeServices();
                }),
              ),
            ),
          );
        }
        return const SukunLifeApp();
      },
    );
  }
}
