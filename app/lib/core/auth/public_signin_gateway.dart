import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PublicOtpChannel { email, phone }

/// No phone/email matching or client metadata may upgrade the account to patient.
abstract interface class PublicSignInGateway {
  Future<void> requestCode({
    required PublicOtpChannel channel,
    required String identifier,
  });
  Future<void> verifyCode({
    required PublicOtpChannel channel,
    required String identifier,
    required String code,
  });
  Future<void> signInWithGoogle();
}

class PublicSignInException implements Exception {
  const PublicSignInException();
}

const approvedGoogleWebCallback = 'https://app.sukunlife.com/';
const legacyGoogleWebCallback = 'https://umar-vai.github.io/Sukun-app-/';

/// Return to the real Flutter app, not the legacy website or a guessed
/// Supabase Site URL. OAuth sessions are still verified by Supabase Auth.
String googleOAuthWebRedirectUrl(Uri current) {
  if (current.scheme == 'https' && current.host == 'app.sukunlife.com') {
    return approvedGoogleWebCallback;
  }
  if (current.scheme == 'https' &&
      current.host == 'umar-vai.github.io' &&
      (current.path == '/Sukun-app-' ||
          current.path.startsWith('/Sukun-app-/'))) {
    return legacyGoogleWebCallback;
  }
  if (current.host == 'localhost' || current.host == '127.0.0.1') {
    return '${current.origin}/';
  }
  throw const PublicSignInException();
}

final class SupabasePublicSignInGateway implements PublicSignInGateway {
  const SupabasePublicSignInGateway(this._client);
  final SupabaseClient _client;

  bool _enabled(PublicOtpChannel channel) => channel == PublicOtpChannel.email
      ? AppEnvironment.emailOtpEnabled
      : AppEnvironment.phoneOtpEnabled;

  @override
  Future<void> requestCode({
    required PublicOtpChannel channel,
    required String identifier,
  }) async {
    if (!_enabled(channel)) throw const PublicSignInException();
    try {
      if (channel == PublicOtpChannel.email) {
        await _client.auth.signInWithOtp(
          email: identifier.trim(),
          shouldCreateUser: false,
          emailRedirectTo: kIsWeb ? null : AppEnvironment.mobileAuthRedirectUrl,
        );
      } else {
        await _client.auth.signInWithOtp(
          phone: identifier.trim(),
          shouldCreateUser: false,
        );
      }
    } on AuthException {
      throw const PublicSignInException();
    }
  }

  @override
  Future<void> verifyCode({
    required PublicOtpChannel channel,
    required String identifier,
    required String code,
  }) async {
    if (!_enabled(channel)) throw const PublicSignInException();
    try {
      final response = await _client.auth.verifyOTP(
        type: channel == PublicOtpChannel.email ? OtpType.email : OtpType.sms,
        token: code.trim(),
        email: channel == PublicOtpChannel.email ? identifier.trim() : null,
        phone: channel == PublicOtpChannel.phone ? identifier.trim() : null,
      );
      if (response.session == null) throw const PublicSignInException();
    } on AuthException {
      throw const PublicSignInException();
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    if (!AppEnvironment.googleOAuthEnabled) throw const PublicSignInException();
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? googleOAuthWebRedirectUrl(Uri.base)
            : AppEnvironment.mobileAuthRedirectUrl,
      );
      if (!launched) throw const PublicSignInException();
      // Browser launch != authenticated. Supabase onAuthStateChange is authoritative.
    } on AuthException {
      throw const PublicSignInException();
    }
  }
}

final publicSignInGatewayProvider = Provider<PublicSignInGateway>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailablePublicSignInGateway();
  }
  return SupabasePublicSignInGateway(Supabase.instance.client);
});

final class UnavailablePublicSignInGateway implements PublicSignInGateway {
  const UnavailablePublicSignInGateway();

  @override
  Future<void> requestCode({
    required PublicOtpChannel channel,
    required String identifier,
  }) async => throw const PublicSignInException();

  @override
  Future<void> verifyCode({
    required PublicOtpChannel channel,
    required String identifier,
    required String code,
  }) async => throw const PublicSignInException();

  @override
  Future<void> signInWithGoogle() async => throw const PublicSignInException();
}
