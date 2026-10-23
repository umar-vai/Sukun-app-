import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/google_oauth_web_failure.dart';

void main() {
  test('never treats successful OAuth fragments as errors', () {
    expect(
      googleOAuthWebFailureMessage(
        Uri.parse(
          'https://app.sukunlife.com/#access_token=example&token_type=bearer',
        ),
      ),
      isNull,
    );
    expect(
      googleOAuthWebFailureMessage(Uri.parse('https://app.sukunlife.com/')),
      isNull,
    );
  });

  test('reports cancellation without showing raw provider text', () {
    final message = googleOAuthWebFailureMessage(
      Uri.parse(
        'https://app.sukunlife.com/#error=access_denied'
        '&error_description=private-personal-provider-details',
      ),
    );
    expect(message, contains('S-OAUTH-01'));
    expect(message, isNot(contains('private-personal-provider-details')));
  });

  test('recognizes query callback errors without reflecting attacker text', () {
    final message = googleOAuthWebFailureMessage(
      Uri.parse(
        'https://app.sukunlife.com/?error=server_error'
        '&error_description=malicious-personal-string',
      ),
    );
    expect(message, contains('S-OAUTH-03'));
    expect(message, isNot(contains('malicious-personal-string')));
  });

  test('disabled provider produces an actionable code', () {
    final message = googleOAuthWebFailureMessage(
      Uri.parse(
        'https://app.sukunlife.com/#error=server_error'
        '&error_code=provider_disabled',
      ),
    );
    expect(message, contains('S-OAUTH-02'));
  });
}
