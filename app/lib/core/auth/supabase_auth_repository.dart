import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_repository.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppSession> watchSession() {
    return _client.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user;
      if (user == null) {
        return const AppSession.guest();
      }

      final profile = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final roleRows = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id);
      final roles = roleRows
          .map((row) => UserRole.fromDatabaseValue(row['role'] as String?))
          .toSet();

      final role = roles.contains(UserRole.superAdmin)
          ? UserRole.superAdmin
          : roles.contains(UserRole.patient)
          ? UserRole.patient
          : UserRole.guest;

      return AppSession(
        role: role,
        userId: user.id,
        displayName: profile?['display_name'] as String?,
      );
    });
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
