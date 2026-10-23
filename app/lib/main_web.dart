import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/auth/google_oauth_web_failure.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/config/web_preview_config.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_launch_screen.dart';

/// Browser entrypoint for the ACTUAL Flutter app, including authenticated
/// Patient/Admin routes where Supabase Auth and RLS grant access.
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
  String? _oauthFailure;

  @override
  void initState() {
    super.initState();
    // Supabase can redirect back with a fragment/query error. Capture only a
    // fixed safe message; never show provider text or access tokens.
    _oauthFailure = googleOAuthWebFailureMessage(Uri.base);
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
                message: 'App could not start securely. Check backend configuration.',
                onRetry: () => setState(() {
                  _initialization = _initialize();
                }),
              ),
            ),
          );
        }
        final failure = _oauthFailure;
        if (failure != null) {
          return MaterialApp(
            title: 'Sukun Life',
            debugShowCheckedModeBanner: false,
            theme: SukunTheme.light(),
            home: Scaffold(
              appBar: AppBar(title: const Text('Google লগইন')),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 48),
                          const SizedBox(height: 16),
                          Text(failure, textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () =>
                                setState(() => _oauthFailure = null),
                            child: const Text('অ্যাপে ফিরে যান'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return const SukunLifeApp();
      },
    );
  }
}
