import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/public_signin_gateway.dart';

void main() {
  test('Google returns to approved Flutter Web origins', () {
    expect(
      googleOAuthWebRedirectUrl(Uri.parse('https://app.sukunlife.com/#/login')),
      approvedGoogleWebCallback,
    );
    expect(
      googleOAuthWebRedirectUrl(
        Uri.parse('https://umar-vai.github.io/Sukun-app-/#/login'),
      ),
      legacyGoogleWebCallback,
    );
    expect(
      googleOAuthWebRedirectUrl(
        Uri.parse('https://umar-vai.github.io/Sukun-app-/resources?q=1'),
      ),
      legacyGoogleWebCallback,
    );
  });

  test('Google OAuth will not redirect to an unapproved origin', () {
    expect(
      () => googleOAuthWebRedirectUrl(Uri.parse('https://sukunlife.com/')),
      throwsA(isA<PublicSignInException>()),
    );
    expect(
      () => googleOAuthWebRedirectUrl(
        Uri.parse('https://malicious.example/Sukun-app-/'),
      ),
      throwsA(isA<PublicSignInException>()),
    );
    expect(
      () => googleOAuthWebRedirectUrl(Uri.parse('http://app.sukunlife.com/')),
      throwsA(isA<PublicSignInException>()),
    );
    expect(
      () => googleOAuthWebRedirectUrl(
        Uri.parse('https://app.sukunlife.com.evil.example/'),
      ),
      throwsA(isA<PublicSignInException>()),
    );
  });

  test('Local developer OAuth return URL remains on local origin', () {
    expect(
      googleOAuthWebRedirectUrl(Uri.parse('http://localhost:8080/login')),
      'http://localhost:8080/',
    );
  });
}
