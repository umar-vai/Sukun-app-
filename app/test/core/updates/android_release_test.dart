import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sukun_life/core/updates/android_release.dart';
import 'package:sukun_life/core/updates/android_update_service.dart';

void main() {
  const sha = 'aabbccddeeff00112233445566778899'
      'aabbccddeeff00112233445566778899';
  const asset =
      'https://github.com/umar-vai/Sukun-app-/releases/download/v1.0.2/SukunLife.apk';

  Map<String, dynamic> manifest({
    int code = 2,
    bool enabled = true,
    String url = asset,
  }) => {
    'schema_version': 1,
    'platform': 'android',
    'package_name': 'com.sukunlife.app',
    'enabled': enabled,
    'version_code': code,
    'version_name': '1.0.2',
    'min_supported_version_code': 0,
    'apk_url': url,
    'sha256': sha,
    'size_bytes': 23000000,
    'notes_bn': 'নতুন নিরাপদ অ্যাপ আপডেট।',
  };

  test('disabled release feed is safe and never prompts install', () {
    final data = manifest(enabled: false);
    data['apk_url'] = '';
    data['sha256'] = '';
    expect(AndroidRelease.fromJson(data), isNull);
    expect(AndroidRelease.fromJson({'schema_version': 1}), isNull);
  });

  test('identifies a newer signed release and never downgrades', () {
    final release = AndroidRelease.fromJson(manifest())!;
    expect(release.versionCode, 2);
    expect(release.isNewerThan(1), isTrue);
    expect(release.isNewerThan(2), isFalse);
    expect(release.isNewerThan(5), isFalse);
    expect(release.apkUrl.toString(), asset);
  });

  test('rejects untrusted, spoofed or cleartext APK links', () {
    for (final bad in [
      'http://github.com/umar-vai/Sukun-app-/releases/download/v1.0.2/app.apk',
      'https://github.com.evil.example/umar-vai/Sukun-app-/releases/download/v1.0.2/app.apk',
      'https://github.com/other/repo/releases/download/v1.0.2/app.apk',
      'https://github.com/umar-vai/Sukun-app-/blob/main/app.apk',
      'https://downloads.sukunlife.com.evil.example/android/app.apk',
      'https://github.com/umar-vai/Sukun-app-/releases/download/v1.0.2/app.apk?redirect=https://evil.test',
      'https://attacker.example/android/app.apk',
    ]) {
      expect(
        () => AndroidRelease.fromJson(manifest(url: bad)),
        throwsFormatException,
        reason: bad,
      );
    }
  });

  test('only exact official GitHub Release/CDN asset paths are accepted', () {
    expect(isApprovedApkUri(Uri.parse(asset)), isTrue);
    expect(
      isApprovedApkUri(
        Uri.parse('https://downloads.sukunlife.com/android/1.0.2/app.apk'),
      ),
      isTrue,
    );
    expect(
      isApprovedApkUri(
        Uri.parse('https://downloads.sukunlife.com/other/app.apk'),
      ),
      isFalse,
    );
  });

  test('rejects wrong package, checksum and version metadata', () {
    final wrongPackage = manifest()..['package_name'] = 'com.attacker.app';
    expect(
      () => AndroidRelease.fromJson(wrongPackage),
      throwsFormatException,
    );
    final wrongDigest = manifest()..['sha256'] = '123';
    expect(
      () => AndroidRelease.fromJson(wrongDigest),
      throwsFormatException,
    );
    final wrongVersion = manifest()..['version_code'] = 0;
    expect(
      () => AndroidRelease.fromJson(wrongVersion),
      throwsFormatException,
    );
  });

  test('HTTP feed only returns newer official releases', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'app.sukunlife.com');
      expect(request.url.path, '/updates/android.json');
      return http.Response(
        jsonEncode(manifest()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AndroidUpdateService(client: client);
    addTearDown(service.dispose);
    final release = await service.check(installedVersionCodeOverride: 1);
    expect(release?.versionCode, 2);
    expect(await service.check(installedVersionCodeOverride: 2), isNull);
  });

  test('offline feed raises a recoverable exception; app need not sign out', () async {
    final service = AndroidUpdateService(
      client: MockClient((request) async => http.Response('offline', 503)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.check(installedVersionCodeOverride: 1),
      throwsFormatException,
    );
  });
}
