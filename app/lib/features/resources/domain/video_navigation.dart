import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Published video cards should take the user straight to playback. Other
/// resources retain their details page, and invalid YouTube ids never play.
bool opensYoutubePlayerDirectly(ContentResource resource) =>
    resource.type == 'video' &&
    resolveResourceMedia(resource.linkedResource)?.kind ==
        ResourceMediaKind.youtube;
