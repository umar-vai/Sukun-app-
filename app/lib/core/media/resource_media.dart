import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

enum ResourceMediaKind { audio, video, youtube, pdf, webpage }

class ResourceMediaTarget {
  const ResourceMediaTarget({
    required this.kind,
    this.uri,
    this.youtubeVideoId,
  });

  final ResourceMediaKind kind;
  final Uri? uri;
  final String? youtubeVideoId;
}

ResourceMediaTarget? resolveResourceMedia(LinkedResource resource) {
  if (resource.mediaSourceType == 'youtube') {
    final videoId = resource.youtubeVideoId?.trim();
    if (videoId == null ||
        !RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(videoId)) {
      return null;
    }
    return ResourceMediaTarget(
      kind: ResourceMediaKind.youtube,
      youtubeVideoId: videoId,
    );
  }

  final value = resource.mediaUrl?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;

  final kind = switch (resource.mediaSourceType) {
    'direct_audio_url' => ResourceMediaKind.audio,
    'direct_video_url' => ResourceMediaKind.video,
    'external_pdf' => ResourceMediaKind.pdf,
    'external_web' => ResourceMediaKind.webpage,
    _ => null,
  };
  if (kind == null) return null;
  final directUri = kind == ResourceMediaKind.pdf ? _directPdfUri(uri) : uri;
  return directUri == null
      ? null
      : ResourceMediaTarget(kind: kind, uri: directUri);
}

/// A GitHub /blob/ URL returns an HTML page, not PDF bytes. Convert only
/// clearly identified GitHub PDF file pages to the raw file host. Other hosts
/// must serve a readable PDF directly and permit browser CORS access.
Uri? _directPdfUri(Uri uri) {
  if (uri.host.toLowerCase() != 'github.com') return uri;
  final parts = uri.pathSegments;
  if (parts.length < 5 ||
      parts[0].isEmpty ||
      parts[1].isEmpty ||
      (parts[2] != 'blob' && parts[2] != 'raw') ||
      parts[3].isEmpty ||
      !parts.last.toLowerCase().endsWith('.pdf')) {
    return null;
  }
  return Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    pathSegments: [parts[0], parts[1], ...parts.skip(3)],
  );
}
