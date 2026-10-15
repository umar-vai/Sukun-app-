import 'package:sukun_life/core/config/app_environment.dart';

/// Fail closed before starting the publicly hosted role-aware web client.
///
/// The Pages build uses the real Flutter app. Private Patient/Admin data remains
/// protected by Supabase Auth, database RLS and server-side authorization.
///
/// After the explicit production cutover, the public Pages bundle may contain
/// ONLY the production Supabase *publishable* key, never service credentials.
/// Production builds must target the single approved project and pass the
/// anonymous-data isolation gate in CI before deployment.
void validateWebPreviewConfiguration({
  required String environment,
  required String url,
  required String publishableKey,
  bool publicMemberSignupEnabled = false,
  bool emailOtpEnabled = false,
  bool phoneOtpEnabled = false,
  bool googleOAuthEnabled = false,
}) {
  validateSupabaseRuntimeConfiguration(
    environment: environment,
    url: url,
    publishableKey: publishableKey,
  );

  if (environment != 'local' &&
      environment != 'staging' &&
      environment != 'production') {
    throw StateError('Unsupported web environment.');
  }
  if (environment == 'local' &&
      (publicMemberSignupEnabled ||
          emailOtpEnabled ||
          phoneOtpEnabled ||
          googleOAuthEnabled)) {
    throw StateError(
      'Web authentication requires a configured Supabase backend.',
    );
  }
  if (url.isEmpty) {
    if (environment != 'local') {
      throw StateError('Configured web environment requires Supabase.');
    }
    return;
  }
  final host = Uri.parse(url).host;
  if (!host.endsWith('.supabase.co')) {
    throw StateError('Web app requires a Supabase project host.');
  }
  if (environment == 'production') {
    if (url != AppEnvironment.productionSupabaseUrl ||
        !publishableKey.startsWith('sb_publishable_')) {
      throw StateError(
        'Production web requires the approved project and a public key.',
      );
    }
  } else if (host == Uri.parse(AppEnvironment.productionSupabaseUrl).host) {
    throw StateError('Non-production web cannot use Production Supabase.');
  }
}
