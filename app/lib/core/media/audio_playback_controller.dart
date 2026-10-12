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
  Future<void> _loadQueue = Future<void>.value();
  int _requestedLoad = 0;

  AudioPlayer get player => _player;
  LinkedResource? get resource => _resource;

  /// Serialize changes of audio sources: a previous asynchronous load must
  /// never install its old stream after the listener selected another track.
  Future<void> load(LinkedResource resource) {
    final previous = _loadQueue;
    final completion = Completer<void>();
    _loadQueue = completion.future;
    final request = ++_requestedLoad;

    return () async {
      try {
        await previous;
        if (request != _requestedLoad) {
          throw const AudioPlaybackException('Audio selection was changed.');
        }
        await _loadSelectedResource(resource, request);
      } finally {
        completion.complete();
      }
    }();
  }

  Future<void> _loadSelectedResource(
    LinkedResource resource,
    int request,
  ) async {
    final target = resolveResourceMedia(resource);
    if (target?.kind != ResourceMediaKind.audio || target?.uri == null) {
      throw const AudioPlaybackException(
        'This audio resource does not have a valid secure URL.',
      );
    }
    if (!audioResourceNeedsReload(_resource, resource)) return;

    try {
      await _persistCurrentPosition();
    } on Exception {
      // Resume data is optional and must never block the selected track.
    }

    // The player is shared across routes. Immediately stop the old stream
    // before loading the new URL, including on web/mobile browsers.
    _resource = null;
    _lastSavedSecond = -1;
    try {
      await _player.stop();
      if (request != _requestedLoad) {
        throw const AudioPlaybackException('Audio selection was changed.');
      }
      Duration savedPosition = Duration.zero;
      try {
        savedPosition = await _positions.read(resource.id) ?? Duration.zero;
      } on Exception {
        // Start from the beginning if the resume store is unavailable.
      }
      if (request != _requestedLoad) {
        throw const AudioPlaybackException('Audio selection was changed.');
      }
      final duration = await _player.setAudioSource(
        AudioSource.uri(
          target!.uri!,
          tag: MediaItem(
            id: resource.id,
            title: resource.titleBn?.trim().isNotEmpty == true
                ? resource.titleBn!
                : resource.title,
            album: 'Sukun Life',
            artUri: _validHttpsUri(resource.thumbnailUrl),
          ),
        ),
        initialPosition: savedPosition,
      );
      if (request != _requestedLoad) {
        await _player.stop();
        throw const AudioPlaybackException('Audio selection was changed.');
      }
      _resource = resource;
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
    } on AudioPlaybackException {
      _resource = null;
      rethrow;
    } on Exception {
      _resource = null;
      throw const AudioPlaybackException(
        'Audio loading failed. Check the link and try again.',
      );
    }
  }

  Future<void> play({LinkedResource? expectedResource}) async {
    if (_resource == null ||
        (expectedResource != null &&
            audioResourceNeedsReload(_resource, expectedResource))) {
      throw const AudioPlaybackException(
        'The selected audio is not loaded. Retry to play this track.',
      );
    }
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

  /// Repeat the current resource without changing other app audio sessions.
  Future<void> toggleRepeatOne() => _player.setLoopMode(
    _player.loopMode == LoopMode.one ? LoopMode.off : LoopMode.one,
  );

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
