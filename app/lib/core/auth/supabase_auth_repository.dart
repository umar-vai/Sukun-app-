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
          .select('display_name,requires_credential_change')
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
        requiresCredentialChange:
            profile?['requires_credential_change'] as bool? ?? false,
      );
    });
  }

  @override
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final normalized = identifier.trim();
    try {
      if (normalized.contains('@')) {
        await _client.auth.signInWithPassword(
          email: normalized,
          password: password,
        );
        return;
      }

      final response = await _client.functions.invoke(
        'patient-sign-in',
        body: {'identifier': normalized, 'password': password},
      );
      final body = response.data;
      if (body is! Map || body['refresh_token'] is! String) {
        throw const AuthenticationException(
          'Patient ID or password is incorrect.',
        );
      }
      await _client.auth.setSession(body['refresh_token'] as String);
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['message'] is String) {
        throw AuthenticationException(details['message'] as String);
      }
      throw const AuthenticationException(
        'Sign in is temporarily unavailable. Please try again.',
      );
    } on AuthException {
      throw const AuthenticationException(
        'Patient ID, phone/email, or password is incorrect.',
      );
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.functions.invoke(
        'patient-change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      await _client.auth.refreshSession();
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['message'] is String) {
        throw AuthenticationException(details['message'] as String);
      }
      throw const AuthenticationException(
        'Password change is temporarily unavailable. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
