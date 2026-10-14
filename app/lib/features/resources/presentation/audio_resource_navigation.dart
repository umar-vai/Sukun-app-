import 'package:flutter/material.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';

/// Playable audio tiles open the full shared player without an intermediate
/// "audio source / listen" resource-details action screen.
bool isDirectPlayableAudio(ContentResource resource) =>
    resolveResourceMedia(resource.linkedResource)?.kind ==
    ResourceMediaKind.audio;

bool openAudioResourceDirectly(
  BuildContext context,
  ContentResource resource,
) {
  if (!isDirectPlayableAudio(resource)) return false;
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AudioPlayerScreen(resource: resource.linkedResource),
    ),
  );
  return true;
}
