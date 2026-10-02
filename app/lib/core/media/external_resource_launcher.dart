import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:url_launcher/url_launcher.dart';

final resourceLauncherProvider = Provider<ResourceLauncher>(
  (ref) => const ExternalResourceLauncher(),
);

abstract interface class ResourceLauncher {
  Future<void> open(LinkedResource resource);
}

final class ExternalResourceLauncher implements ResourceLauncher {
  const ExternalResourceLauncher();

  @override
  Future<void> open(LinkedResource resource) async {
    final uri = externalResourceUri(resource);
    if (uri == null) {
      throw const ResourceOpenException(
        'This resource does not have a valid external link yet.',
      );
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw const ResourceOpenException(
        'This resource could not be opened on this device.',
      );
    }
  }
}

Uri? externalResourceUri(LinkedResource resource) {
  if (resource.mediaSourceType == 'youtube') {
    final videoId = resource.youtubeVideoId?.trim();
    if (videoId == null ||
        !RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(videoId)) {
      return null;
    }
    return Uri.https('www.youtube.com', '/watch', {'v': videoId});
  }

  final value = resource.mediaUrl?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

class ResourceOpenException implements Exception {
  const ResourceOpenException(this.message);

  final String message;

  @override
  String toString() => message;
}
