import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sukun_life/core/updates/android_release.dart';

const androidUpdateManifestUrl =
    'https://app.sukunlife.com/updates/android.json';

/// Uses the same signed Flutter APK package, without embedding release secrets.
class AndroidUpdateService {
  AndroidUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const nativeChannel = MethodChannel('sukunlife/app_updates');

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<int?> installedVersionCode() async {
    if (!isSupported) return null;
    final value = await nativeChannel.invokeMethod<int>('installedVersionCode');
    return value;
  }

  Future<AndroidRelease?> check({
    int? installedVersionCodeOverride,
  }) async {
    final installed =
        installedVersionCodeOverride ?? await installedVersionCode();
    if (installed == null) return null;
    final uri = Uri.parse(androidUpdateManifestUrl).replace(
      queryParameters: {'checked': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    final response = await _client.get(
      uri,
      headers: const {'Cache-Control': 'no-cache', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 9));
    if (response.statusCode != 200 ||
        response.bodyBytes.length > 64 * 1024) {
      throw const FormatException('The release feed is unavailable.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid release feed.');
    }
    final release = AndroidRelease.fromJson(decoded);
    if (release == null || !release.isNewerThan(installed)) return null;
    return release;
  }

  Future<int> startDownload(AndroidRelease release) async {
    if (!isSupported) throw UnsupportedError('Only Android can install APKs.');
    final id = await nativeChannel.invokeMethod<int>('enqueueVerifiedApk', {
      'url': release.apkUrl.toString(),
      'sha256': release.sha256,
      'sizeBytes': release.sizeBytes,
      'versionCode': release.versionCode,
    });
    if (id == null || id <= 0) {
      throw StateError('Android could not begin the download.');
    }
    return id;
  }

  Future<AndroidDownloadStatus> status(int id) async {
    final response = await nativeChannel.invokeMapMethod<String, dynamic>(
      'downloadStatus', {'id': id},
    );
    final value = response ?? {};
    return AndroidDownloadStatus(
      state: value['state'] as String? ?? 'failed',
      received: (value['received'] as num?)?.toInt() ?? 0,
      total: (value['total'] as num?)?.toInt() ?? -1,
    );
  }

  /// Android shows its own install confirmation. No silent installation.
  Future<String> requestInstallation(int id) async {
    final status = await nativeChannel.invokeMethod<String>(
      'openInstaller', {'id': id},
    );
    return status ?? 'error';
  }

  void dispose() => _client.close();
}

final class AndroidDownloadStatus {
  const AndroidDownloadStatus({
    required this.state,
    required this.received,
    required this.total,
  });

  final String state;
  final int received;
  final int total;

  double? get progress =>
      total <= 0 ? null : (received / total).clamp(0.0, 1.0);
}
