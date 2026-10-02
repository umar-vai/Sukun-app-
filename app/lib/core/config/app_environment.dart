import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppEnvironment {
  static const productionProjectRef = 'vydfafumxptanpkmtrpr';
  static const productionSupabaseUrl =
      'https://$productionProjectRef.supabase.co';

  static const name = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: 'local',
  );
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isProduction => name == 'production';

  static Future<void> initialize() async {
    validateSupabaseRuntimeConfiguration(
      environment: name,
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );

    if (isSupabaseConfigured) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
    }
  }
}

void validateSupabaseRuntimeConfiguration({
  required String environment,
  required String url,
  required String publishableKey,
}) {
  const supportedEnvironments = {
    'local',
    'development',
    'staging',
    'production',
  };
  if (!supportedEnvironments.contains(environment)) {
    throw StateError('APP_ENVIRONMENT has an unsupported value.');
  }

  final hasUrl = url.trim().isNotEmpty;
  final hasKey = publishableKey.trim().isNotEmpty;
  if (hasUrl != hasKey) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be supplied together.',
    );
  }
  if (!hasUrl) {
    if (environment == 'production') {
      throw StateError(
        'Production Supabase runtime configuration is required.',
      );
    }
    return;
  }

  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw StateError('SUPABASE_URL must be a valid HTTPS URL.');
  }
  if (environment == 'production' &&
      url != AppEnvironment.productionSupabaseUrl) {
    throw StateError(
      'Production builds must target the approved Sukun Mobile App project.',
    );
  }
}
