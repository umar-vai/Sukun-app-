import 'package:sukun_life/core/config/app_environment.dart';

/// Fail closed before starting the publicly hosted role-aware web client.
///
/// The Pages build can render public resources without Supabase, but private
/// Patient/Admin workflows are enabled only with an isolated staging backend.
/// A production backend must never be used for public preview testing.
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

  if (environment != 'local' && environment != 'staging') {
    throw StateError('Web preview supports local or staging only.');
  }
  if (environment != 'staging' &&
      (publicMemberSignupEnabled ||
          emailOtpEnabled ||
          phoneOtpEnabled ||
          googleOAuthEnabled)) {
    throw StateError(
      'Web authentication feature flags require isolated staging.',
    );
  }
  if (url.isEmpty) {
    if (environment != 'local') {
      throw StateError('Staging web preview requires backend configuration.');
    }
    return;
  }
  if (environment != 'staging') {
    throw StateError('Web preview backend requires staging mode.');
  }
  final host = Uri.parse(url).host;
  if (!host.endsWith('.supabase.co') ||
      host == Uri.parse(AppEnvironment.productionSupabaseUrl).host) {
    throw StateError(
      'Web preview must use an isolated Supabase staging project.',
    );
  }
}
