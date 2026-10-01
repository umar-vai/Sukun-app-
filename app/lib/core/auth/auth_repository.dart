import 'package:sukun_life/core/auth/app_session.dart';

abstract interface class AuthRepository {
  Stream<AppSession> watchSession();

  Future<void> signIn({required String identifier, required String password});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class GuestAuthRepository implements AuthRepository {
  const GuestAuthRepository();

  @override
  Stream<AppSession> watchSession() => Stream.value(const AppSession.guest());

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => throw const AuthenticationException(
    'Connect Supabase to change account credentials.',
  );

  @override
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async =>
      throw const AuthenticationException('Connect Supabase to sign in.');

  @override
  Future<void> signOut() async {}
}
