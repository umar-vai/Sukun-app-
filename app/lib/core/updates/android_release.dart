/// Public release metadata only. Never includes tokens, patient data or secrets.
/// Unpublished releases must never result in a download button.
final class AndroidRelease {
  const AndroidRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.notesBn,
    required this.minSupportedCode,
  });

  static const packageName = 'com.sukunlife.app';

  final int versionCode;
  final String versionName;
  final Uri apkUrl;
  final String sha256;
  final int sizeBytes;
  final String notesBn;
  final int minSupportedCode;

  bool isNewerThan(int installedCode) => versionCode > installedCode;

  bool isMandatoryFor(int installedCode) =>
      minSupportedCode > 0 && installedCode < minSupportedCode;

  static AndroidRelease? fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1 || json['enabled'] != true) {
      return null;
    }
    if (json['platform'] != 'android' ||
        json['package_name'] != packageName) {
      throw const FormatException('Unsupported release identity.');
    }
    final code = json['version_code'];
    final name = json['version_name'];
    final bytes = json['size_bytes'];
    final digest = json['sha256'];
    final url = json['apk_url'];
    final minimum = json['min_supported_version_code'] ?? 0;

    if (code is! int ||
        code <= 0 ||
        minimum is! int ||
        minimum < 0 ||
        minimum > code ||
        name is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(name) ||
        bytes is! int ||
        bytes < 1024 * 1024 ||
        bytes > 512 * 1024 * 1024 ||
        digest is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest) ||
        url is! String) {
      throw const FormatException('Invalid release metadata.');
    }
    final target = Uri.tryParse(url);
    if (target == null || !isApprovedApkUri(target)) {
      throw const FormatException('Unapproved APK download host or path.');
    }
    final notes = json['notes_bn'];
    return AndroidRelease(
      versionCode: code,
      versionName: name,
      apkUrl: target,
      sha256: digest.toLowerCase(),
      sizeBytes: bytes,
      notesBn: notes is String ? notes.trim() : '',
      minSupportedCode: minimum,
    );
  }
}

/// An APK URL cannot be supplied by a patient, URL query, or arbitrary server.
/// Only official GitHub Release assets or the future approved download CDN.
bool isApprovedApkUri(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment ||
      uri.hasQuery ||
      !uri.path.toLowerCase().endsWith('.apk')) {
    return false;
  }
  if (uri.host == 'github.com') {
    final segments = uri.pathSegments;
    return segments.length == 6 &&
        segments[0] == 'umar-vai' &&
        segments[1] == 'Sukun-app-' &&
        segments[2] == 'releases' &&
        segments[3] == 'download' &&
        segments[4].isNotEmpty &&
        segments[5].isNotEmpty;
  }
  if (uri.host == 'downloads.sukunlife.com') {
    return uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'android' &&
        !uri.pathSegments.contains('..');
  }
  return false;
}
