import 'package:youtube_player_flutter/youtube_player_flutter.dart';

enum VideoLoadPhase { loading, ready, buffering, failed }

/// The official YouTube controller reports when a video is cued/playing,
/// buffering or has a playback error. Don't mistake an initializing iframe
/// for a playable video.
VideoLoadPhase videoLoadPhase(
  YoutubePlayerValue value, {
  required bool hasLoaded,
}) {
  if (value.hasError) return VideoLoadPhase.failed;
  return switch (value.playerState) {
    PlayerState.unStarted ||
    PlayerState.cued ||
    PlayerState.playing ||
    PlayerState.paused ||
    PlayerState.ended => VideoLoadPhase.ready,
    PlayerState.buffering =>
      hasLoaded ? VideoLoadPhase.buffering : VideoLoadPhase.loading,
    _ => hasLoaded ? VideoLoadPhase.ready : VideoLoadPhase.loading,
  };
}
