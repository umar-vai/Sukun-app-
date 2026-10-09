import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public accounts never acquire patient, raqi, staff or admin permissions
/// from client-side role data. The Auth trigger provisions member identity.
abstract interface class MemberRegistrationRepository {
  Future<void> registerWithEmail({
    required String email,
    required String password,
  });
}

class MemberRegistrationException implements Exception {
  const MemberRegistrationException();
}

final class SupabaseMemberRegistrationRepository
    implements MemberRegistrationRepository {
  const SupabaseMemberRegistrationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) throw const MemberRegistrationException();
    } on AuthException {
      // Avoid exposing email existence and internal provider diagnostics.
      throw const MemberRegistrationException();
    }
  }
}

final class UnavailableMemberRegistrationRepository
    implements MemberRegistrationRepository {
  const UnavailableMemberRegistrationRepository();

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async => throw const MemberRegistrationException();
}

final memberRegistrationRepositoryProvider =
    Provider<MemberRegistrationRepository>((ref) {
      if (!AppEnvironment.isSupabaseConfigured ||
          !AppEnvironment.publicMemberSignupEnabled) {
        return const UnavailableMemberRegistrationRepository();
      }
      return SupabaseMemberRegistrationRepository(Supabase.instance.client);
    });
