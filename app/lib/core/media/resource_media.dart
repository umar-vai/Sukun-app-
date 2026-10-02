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
  return kind == null ? null : ResourceMediaTarget(kind: kind, uri: uri);
}
