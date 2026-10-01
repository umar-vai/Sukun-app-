import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_repository.dart';
import 'package:sukun_life/core/auth/supabase_auth_repository.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const GuestAuthRepository();
  }
  return SupabaseAuthRepository(Supabase.instance.client);
});

final appSessionProvider = StreamProvider<AppSession>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});
