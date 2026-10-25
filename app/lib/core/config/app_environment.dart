import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppEnvironment {
  static const stagingProjectRef = 'qacklgqvxvjjzsimjoip';
  static const stagingSupabaseUrl = 'https://$stagingProjectRef.supabase.co';

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
  // Off until member-role migrations, email confirmation and abuse protection
  // are verified in a controlled environment.
  static const publicMemberSignupEnabled = bool.fromEnvironment(
    'ENABLE_MEMBER_SIGNUP',
    defaultValue: false,
  );

  // Off until OAuth consent, OTP providers, rate limits, and staging QA pass.
  static const emailOtpEnabled = bool.fromEnvironment(
    'ENABLE_EMAIL_OTP',
    defaultValue: false,
  );
  static const phoneOtpEnabled = bool.fromEnvironment(
    'ENABLE_PHONE_OTP',
    defaultValue: false,
  );
  static const googleOAuthEnabled = bool.fromEnvironment(
    'ENABLE_GOOGLE_OAUTH',
    defaultValue: false,
  );
  static const mobileAuthRedirectUrl = 'com.sukunlife.app://login-callback';

  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.sukunlife.app',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isProduction => name == 'production';

  static bool get isFirebaseConfigured {
    final platformValues = switch (defaultTargetPlatform) {
      TargetPlatform.android => [firebaseAndroidApiKey, firebaseAndroidAppId],
      TargetPlatform.iOS => [firebaseIosApiKey, firebaseIosAppId],
      _ => const <String>[],
    };
    return firebaseProjectId.isNotEmpty &&
        firebaseMessagingSenderId.isNotEmpty &&
        platformValues.isNotEmpty &&
        platformValues.every((value) => value.isNotEmpty);
  }

  static FirebaseOptions get firebaseOptions => switch (defaultTargetPlatform) {
    TargetPlatform.android => FirebaseOptions(
      apiKey: firebaseAndroidApiKey,
      appId: firebaseAndroidAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
    ),
    TargetPlatform.iOS => FirebaseOptions(
      apiKey: firebaseIosApiKey,
      appId: firebaseIosAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      iosBundleId: firebaseIosBundleId,
    ),
    _ => throw UnsupportedError('Firebase messaging supports Android and iOS.'),
  };

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
    validateFirebaseRuntimeConfiguration(
      projectId: firebaseProjectId,
      messagingSenderId: firebaseMessagingSenderId,
      androidApiKey: firebaseAndroidApiKey,
      androidAppId: firebaseAndroidAppId,
      iosApiKey: firebaseIosApiKey,
      iosAppId: firebaseIosAppId,
    );
    if (isFirebaseConfigured && Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseOptions);
    }
  }
}

void validateFirebaseRuntimeConfiguration({
  required String projectId,
  required String messagingSenderId,
  required String androidApiKey,
  required String androidAppId,
  required String iosApiKey,
  required String iosAppId,
}) {
  final shared = [projectId, messagingSenderId];
  final android = [androidApiKey, androidAppId];
  final ios = [iosApiKey, iosAppId];
  final anyValue = [...shared, ...android, ...ios].any(
    (value) => value.trim().isNotEmpty,
  );
  if (!anyValue) return; // Explicitly unconfigured: local reminders still work.

  // Native pilot releases can register only their own Firebase app. Never
  // require iOS keys for Android-only QA (or vice versa).
  final sharedComplete = shared.every((value) => value.trim().isNotEmpty);
  final androidComplete = android.every((value) => value.trim().isNotEmpty);
  final iosComplete = ios.every((value) => value.trim().isNotEmpty);
  final androidEmpty = android.every((value) => value.trim().isEmpty);
  final iosEmpty = ios.every((value) => value.trim().isEmpty);
  if (!sharedComplete ||
      (!androidComplete && !androidEmpty) ||
      (!iosComplete && !iosEmpty) ||
      (!androidComplete && !iosComplete)) {
    throw StateError(
      'Firebase requires project and sender IDs plus complete platform credentials.',
    );
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
    if (environment == 'staging' || environment == 'production') {
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
  // No preview/mobile build may point staging at an arbitrary external project.
  if (environment == 'staging' && url != AppEnvironment.stagingSupabaseUrl) {
    throw StateError(
      'Staging builds must target the approved isolated project.',
    );
  }
  if (environment == 'production' &&
      url != AppEnvironment.productionSupabaseUrl) {
    throw StateError(
      'Production builds must target the approved Sukun Mobile App project.',
    );
  }
}
