import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/config/app_environment.dart';

// Browser-only visual preview of the actual Flutter guest experience.
// Never initialize Supabase, credentials, Firebase, or patient/admin sessions.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppEnvironment.isSupabaseConfigured || AppEnvironment.name != 'local') {
    throw StateError('Web preview must not connect to a backend.');
  }
  runApp(const ProviderScope(child: SukunLifeApp()));
}
