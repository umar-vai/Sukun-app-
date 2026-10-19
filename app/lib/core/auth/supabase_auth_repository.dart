import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_repository.dart';
import 'package:sukun_life/core/auth/replayed_auth_stream.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppSession> watchSession() {
    // Replaying the current session is essential: an invalidated Riverpod
    // StreamProvider cannot rely on a *new* broadcast Auth event arriving.
    // Listen to future events before reading the snapshot to avoid losing
    // sign-in/sign-out changes during setup.
    final signals =
        replaySnapshotAndEvents<({String? userId, bool allowRefresh})>(
          events: _client.auth.onAuthStateChange.map(
            (state) => (
              userId: state.session?.user.id,
              allowRefresh: state.event != AuthChangeEvent.tokenRefreshed,
            ),
          ),
          snapshot: () => (
            userId: _client.auth.currentSession?.user.id,
            allowRefresh: true,
          ),
        );

    return signals.asyncMap((signal) async {
      final userId = signal.userId;
      if (userId == null) return const AppSession.guest();

      final verified = await retryRoleLookupOnJwtFailure(
        load: () => _loadVerifiedSession(userId),
        refresh: () async {
          final refreshed = await _client.auth.refreshSession();
          if (refreshed.session?.user.id != userId) {
            throw StateError('Verified session identity changed.');
          }
        },
        allowRefresh: signal.allowRefresh,
      );

      // An event may race with sign-out or account switching while queries
      // are in flight. Never show the previous user's patient/admin UI.
      if (_client.auth.currentSession?.user.id != userId) {
        return const AppSession.guest();
      }
      return verified;
    });
  }

  Future<AppSession> _loadVerifiedSession(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('display_name,requires_credential_change')
        .eq('id', userId)
        .maybeSingle();
    final roleRows = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId);
    final roles = roleRows
        .map((row) => UserRole.fromDatabaseValue(row['role'] as String?))
        .toSet();

    final role = roles.contains(UserRole.superAdmin)
        ? UserRole.superAdmin
        : roles.contains(UserRole.patient)
        ? UserRole.patient
        : roles.contains(UserRole.member)
        ? UserRole.member
        : UserRole.guest;

    // Roles are always loaded from RLS-visible server data, never from a
    // cached token claim or client metadata.
    return AppSession(
      role: role,
      userId: userId,
      displayName: profile?['display_name'] as String?,
      requiresCredentialChange:
          profile?['requires_credential_change'] as bool? ?? false,
    );
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

bool isJwtLookupFailure(PostgrestException error) =>
    const {'PGRST301', 'PGRST302', 'PGRST303'}.contains(error.code);

/// Retry a role lookup at most once for a PostgREST JWT rejection. Other
/// errors (including authorization/RLS and network failures) fail closed.
Future<T> retryRoleLookupOnJwtFailure<T>({
  required Future<T> Function() load,
  required Future<void> Function() refresh,
  bool allowRefresh = true,
}) async {
  try {
    return await load();
  } on PostgrestException catch (error) {
    if (!allowRefresh || !isJwtLookupFailure(error)) rethrow;
    await refresh();
    return load();
  }
}

String safeSessionFailureCode(Object error) {
  if (error is PostgrestException) {
    return isJwtLookupFailure(error) ? 'S-AUTH-01' : 'S-DATA-02';
  }
  if (error is AuthException) return 'S-AUTH-03';
  return 'S-CLIENT-04';
}
