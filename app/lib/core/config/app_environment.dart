import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppEnvironment {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static Future<void> initialize() async {
    final hasPartialSupabaseConfiguration =
        supabaseUrl.isNotEmpty != supabaseAnonKey.isNotEmpty;
    if (hasPartialSupabaseConfiguration) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be supplied together.',
      );
    }

    if (isSupabaseConfigured) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    }
  }
}
