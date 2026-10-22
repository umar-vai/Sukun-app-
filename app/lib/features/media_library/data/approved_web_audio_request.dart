// Authenticated browser requests for the finite, owner-attested public MP3
// catalog. This deliberately does NOT proxy arbitrary media or patient files.
class ApprovedWebAudioRequest {
  const ApprovedWebAudioRequest({required this.uri, required this.headers});

  final Uri uri;
  final Map<String, String> headers;
}

/// Returns null only when the resource is not one of the 19 pinned publisher
/// MP3s, or the caller is not Web. A recognized Web source must never
/// silently fall back to a cross-origin direct download.
ApprovedWebAudioRequest? approvedWebAudioRequest({
  required bool isWeb,
  required Uri source,
  required String resourceId,
  required Set<String> pinnedUrls,
  required String backendUrl,
  required String publishableKey,
  required String? accessToken,
}) {
  if (!isWeb ||
      source.host != 'files.ruqyahbd.org' ||
      !pinnedUrls.contains(source.toString())) {
    return null;
  }
  final backend = Uri.tryParse(backendUrl);
  if (backend == null ||
      backend.scheme != 'https' ||
      !{
        'qacklgqvxvjjzsimjoip.supabase.co',
        'vydfafumxptanpkmtrpr.supabase.co',
      }.contains(backend.host) ||
      publishableKey.trim().isEmpty) {
    throw StateError('ওয়েব অডিও ডাউনলোড সার্ভার প্রস্তুত নয়।');
  }
  if (accessToken == null || accessToken.trim().isEmpty) {
    throw StateError('অফলাইন ডাউনলোডের জন্য লগইন করুন।');
  }
  return ApprovedWebAudioRequest(
    uri: backend.replace(
      path: '/functions/v1/approved-audio-download',
      queryParameters: {'id': resourceId},
      fragment: '',
    ),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'apikey': publishableKey,
    },
  );
}
