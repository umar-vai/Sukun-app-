import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/core/media/resource_media.dart';
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
  final target = resolveResourceMedia(resource);
  if (target?.kind == ResourceMediaKind.youtube) {
    return Uri.https('www.youtube.com', '/watch', {
      'v': target!.youtubeVideoId!,
    });
  }
  return target?.uri;
}

class ResourceOpenException implements Exception {
  const ResourceOpenException(this.message);

  final String message;

  @override
  String toString() => message;
}
