import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/config/web_preview_config.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_launch_screen.dart';

/// Browser entrypoint for the ACTUAL Flutter app, including authenticated
/// Patient/Admin routes where a separate staging Supabase is configured.
/// No Firebase messaging or native audio background service is started here.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _WebBootstrap()));
}

class _WebBootstrap extends StatefulWidget {
  const _WebBootstrap();

  @override
  State<_WebBootstrap> createState() => _WebBootstrapState();
}

class _WebBootstrapState extends State<_WebBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    validateWebPreviewConfiguration(
      environment: AppEnvironment.name,
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabasePublishableKey,
      publicMemberSignupEnabled: AppEnvironment.publicMemberSignupEnabled,
      emailOtpEnabled: AppEnvironment.emailOtpEnabled,
      phoneOtpEnabled: AppEnvironment.phoneOtpEnabled,
      googleOAuthEnabled: AppEnvironment.googleOAuthEnabled,
    );
    await AppEnvironment.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'Sukun Life Preview',
            debugShowCheckedModeBanner: false,
            theme: SukunTheme.light(),
            home: const SukunLaunchScreen(),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Sukun Life Preview',
            debugShowCheckedModeBanner: false,
            theme: SukunTheme.light(),
            home: Scaffold(
              body: AppErrorState(
                message: 'Preview could not start securely. Check staging configuration.',
                onRetry: () => setState(() {
                  _initialization = _initialize();
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
