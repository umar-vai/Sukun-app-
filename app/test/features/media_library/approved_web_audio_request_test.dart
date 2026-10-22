import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/media_library/data/approved_web_audio_request.dart';

void main() {
  final source = Uri.parse(
    'https://files.ruqyahbd.org/audio/approved.mp3',
  );
  final pinned = {source.toString()};
  const staging = 'https://qacklgqvxvjjzsimjoip.supabase.co';
  const id = '00000000-0000-4000-8000-000000000123';

  test('approved signed-in Web MP3 uses staging gateway with JWT', () {
    final target = approvedWebAudioRequest(
      isWeb: true,
      source: source,
      resourceId: id,
      pinnedUrls: pinned,
      backendUrl: staging,
      publishableKey: 'synthetic-publishable-key',
      accessToken: 'synthetic-member-token',
    );
    expect(target, isNotNull);
    expect(target!.uri.host, 'qacklgqvxvjjzsimjoip.supabase.co');
    expect(target.uri.path, '/functions/v1/approved-audio-download');
    expect(target.uri.queryParameters['id'], id);
    expect(target.headers['Authorization'], 'Bearer synthetic-member-token');
    expect(target.headers['apikey'], 'synthetic-publishable-key');
    expect(target.uri.queryParameters.containsKey('url'), isFalse);
  });

  test('pinned MP3 denies guest and missing Web backend; never falls back', () {
    for (final token in <String?>[null, '']) {
      expect(
        () => approvedWebAudioRequest(
          isWeb: true,
          source: source,
          resourceId: id,
          pinnedUrls: pinned,
          backendUrl: staging,
          publishableKey: 'synthetic-publishable-key',
          accessToken: token,
        ),
        throwsStateError,
      );
    }
    expect(
      () => approvedWebAudioRequest(
        isWeb: true,
        source: source,
        resourceId: id,
        pinnedUrls: pinned,
        backendUrl: '',
        publishableKey: '',
        accessToken: 'synthetic-member-token',
      ),
      throwsStateError,
    );
  });

  test('rejects host substitution and unsigned source URL expansion', () {
    for (final url in [
      'https://evil.example/audio/approved.mp3',
      'https://files.ruqyahbd.org.evil.example/audio/approved.mp3',
      'https://files.ruqyahbd.org/audio/approved.mp3?signature=secret',
    ]) {
      final target = approvedWebAudioRequest(
        isWeb: true,
        source: Uri.parse(url),
        resourceId: id,
        pinnedUrls: pinned,
        backendUrl: staging,
        publishableKey: 'synthetic-publishable-key',
        accessToken: 'synthetic-member-token',
      );
      expect(target, isNull);
    }
  });

  test('native app never routes through browser-only gateway', () {
    expect(
      approvedWebAudioRequest(
        isWeb: false,
        source: source,
        resourceId: id,
        pinnedUrls: pinned,
        backendUrl: staging,
        publishableKey: 'synthetic-publishable-key',
        accessToken: null,
      ),
      isNull,
    );
  });

  test('gateway cannot be redirected to unapproved backend', () {
    expect(
      () => approvedWebAudioRequest(
        isWeb: true,
        source: source,
        resourceId: id,
        pinnedUrls: pinned,
        backendUrl: 'https://attacker.example',
        publishableKey: 'synthetic-publishable-key',
        accessToken: 'synthetic-member-token',
      ),
      throwsStateError,
    );
  });
}
