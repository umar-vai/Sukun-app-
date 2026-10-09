import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

final audioPlaybackControllerProvider = Provider<AudioPlaybackController>((
  ref,
) {
  final controller = AudioPlaybackController(
    AudioPlayer(),
    SharedPreferencesPlaybackPositionStore(),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

abstract interface class PlaybackPositionStore {
  Future<Duration?> read(String resourceId);

  Future<void> write(String resourceId, Duration position);

  Future<void> clear(String resourceId);
}

final class SharedPreferencesPlaybackPositionStore
    implements PlaybackPositionStore {
  SharedPreferencesPlaybackPositionStore({
    Future<SharedPreferences>? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferences;

  String _key(String resourceId) => 'media.audio.position.$resourceId';

  @override
  Future<Duration?> read(String resourceId) async {
    final preferences = await _preferences;
    final milliseconds = preferences.getInt(_key(resourceId));
    return milliseconds == null ? null : Duration(milliseconds: milliseconds);
  }

  @override
  Future<void> write(String resourceId, Duration position) async {
    final preferences = await _preferences;
    await preferences.setInt(_key(resourceId), position.inMilliseconds);
  }

  @override
  Future<void> clear(String resourceId) async {
    final preferences = await _preferences;
    await preferences.remove(_key(resourceId));
  }
}

/// The same CMS resource can receive a refreshed signed or corrected URL.
/// Reusing a player by ID alone can keep the wrong audio or defeat retry.
bool audioResourceNeedsReload(LinkedResource? current, LinkedResource next) =>
    current == null ||
    current.id != next.id ||
    current.mediaSourceType != next.mediaSourceType ||
    current.mediaUrl?.trim() != next.mediaUrl?.trim();

class AudioPlaybackController {
  AudioPlaybackController(this._player, this._positions) {
    _positionSubscription = _player.positionStream.listen(_rememberPosition);
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        final resourceId = _resource?.id;
        if (resourceId != null) unawaited(_positions.clear(resourceId));
      }
    });
  }

  final AudioPlayer _player;
  final PlaybackPositionStore _positions;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<PlayerState> _stateSubscription;
  LinkedResource? _resource;
  int _lastSavedSecond = -1;

  AudioPlayer get player => _player;
  LinkedResource? get resource => _resource;

  Future<void> load(LinkedResource resource) async {
    final target = resolveResourceMedia(resource);
    if (target?.kind != ResourceMediaKind.audio || target?.uri == null) {
      throw const AudioPlaybackException(
        'This audio resource does not have a valid secure URL.',
      );
    }
    if (!audioResourceNeedsReload(_resource, resource)) return;

    // Playback must still work when optional resume storage is unavailable.
    try {
      await _persistCurrentPosition();
    } on Exception {
      // Persistence failure must not block a playable audio source.
    }
    _resource = resource;
    _lastSavedSecond = -1;
    try {
      Duration savedPosition = Duration.zero;
      try {
        savedPosition = await _positions.read(resource.id) ?? Duration.zero;
      } on Exception {
        // Retry from the beginning if a saved bookmark cannot be read.
      }
      final artUri = _validHttpsUri(resource.thumbnailUrl);
      final duration = await _player.setAudioSource(
        AudioSource.uri(
          target!.uri!,
          tag: MediaItem(
            id: resource.id,
            title: resource.titleBn?.trim().isNotEmpty == true
                ? resource.titleBn!
                : resource.title,
            album: 'Sukun Life',
            artUri: artUri,
          ),
        ),
        initialPosition: savedPosition,
      );
      if (duration != null && savedPosition >= duration) {
        await _player.seek(Duration.zero);
        await _positions.clear(resource.id);
      }
    } on PlayerException {
      _resource = null;
      throw const AudioPlaybackException(
        'This audio could not be loaded. Check the media link and try again.',
      );
    } on PlayerInterruptedException {
      _resource = null;
      throw const AudioPlaybackException('Audio loading was interrupted.');
    } on Exception {
      _resource = null;
      throw const AudioPlaybackException(
        'Audio loading failed. Check the link and try again.',
      );
    }
  }

  Future<void> play() async {
    try {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } on PlayerException {
      throw const AudioPlaybackException(
        'Playback failed. The media link may be unavailable.',
      );
    }
  }

  Future<void> pause() async {
    await _player.pause();
    await _persistCurrentPosition();
  }

  Future<void> seek(Duration position) async {
    final duration = _player.duration;
    final bounded = position.isNegative
        ? Duration.zero
        : duration != null && position > duration
        ? duration
        : position;
    await _player.seek(bounded);
    await _persistCurrentPosition();
  }

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  void _rememberPosition(Duration position) {
    final resourceId = _resource?.id;
    if (resourceId == null || position.inSeconds == _lastSavedSecond) return;
    if (position.inSeconds % 5 != 0) return;
    _lastSavedSecond = position.inSeconds;
    unawaited(_positions.write(resourceId, position));
  }

  Future<void> _persistCurrentPosition() async {
    final resourceId = _resource?.id;
    if (resourceId == null) return;
    await _positions.write(resourceId, _player.position);
  }

  Future<void> dispose() async {
    await _persistCurrentPosition();
    await _positionSubscription.cancel();
    await _stateSubscription.cancel();
    await _player.dispose();
  }
}

Uri? _validHttpsUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  return uri?.scheme == 'https' && uri?.host.isNotEmpty == true ? uri : null;
}

class AudioPlaybackException implements Exception {
  const AudioPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}
