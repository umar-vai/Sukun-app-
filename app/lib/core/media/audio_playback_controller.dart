import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/media_library/data/local_audio_uri.dart';

final audioPlaybackControllerProvider = Provider<AudioPlaybackController>((
  ref,
) {
  final controller = AudioPlaybackController(
    AudioPlayer(),
    SharedPreferencesPlaybackPositionStore(),
  );
  // Never keep another user's patient audio playing after auth changes.
  ref.listen(appSessionProvider, (previous, next) {
    final before = previous?.value;
    final after = next.value;
    if (before?.userId != after?.userId || before?.role != after?.role) {
      unawaited(controller.stopAndClear());
    }
  });
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

class QuranVerseAudio {
  const QuranVerseAudio({required this.key, required this.url});
  final String key;
  final String url;
}

/// Stop once the requested number of sequential playlist tracks has played.
/// The next item's index marks the boundary after the previous track ends.
bool playlistTrackLimitReached({
  required int startIndex,
  required int currentIndex,
  required int tracks,
}) => tracks > 0 && currentIndex >= startIndex + tracks;

/// Fifteen minutes is counted from the beginning of each actual recording,
/// not from the wall clock or a guessed duration.
bool playlistSegmentBoundary(Duration position, int minutes) =>
    minutes > 0 && position >= Duration(minutes: minutes);

class AudioPlaybackController extends ChangeNotifier {
  AudioPlaybackController(this._player, this._positions) {
    _positionSubscription = _player.positionStream.listen((position) {
      _rememberPosition(position);
      _maybeAdvanceTimedPlaylist(position);
    });
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        final resourceId = _resource?.id;
        if (resourceId != null) unawaited(_positions.clear(resourceId));
      }
      notifyListeners();
    });
    _indexSubscription = _player.currentIndexStream.listen((index) {
      if (_playlistQueue.isNotEmpty &&
          index != null &&
          index >= 0 &&
          index < _playlistQueue.length) {
        _resource = _playlistQueue[index];
        _lastSavedSecond = -1;
        _segmentAdvancePending = false;
        if (playlistTrackLimitReached(
          startIndex: _stopAfterStartIndex,
          currentIndex: index,
          tracks: _stopAfterTracks,
        )) {
          _stopAfterTracks = 0;
          unawaited(_player.pause());
        }
      }
      notifyListeners();
    });
  }

  final AudioPlayer _player;
  final PlaybackPositionStore _positions;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<PlayerState> _stateSubscription;
  late final StreamSubscription<int?> _indexSubscription;
  LinkedResource? _resource;
  String? _quranTitle;
  List<QuranVerseAudio> _quranQueue = const [];
  List<LinkedResource> _playlistQueue = const [];
  List<LocalAudioUri> _offlineHandles = const [];
  String? _playlistTitle;
  int _lastSavedSecond = -1;
  Future<void> _loadQueue = Future<void>.value();
  int _requestedLoad = 0;
  Timer? _sleepTimer;
  DateTime? _sleepDeadline;
  int _stopAfterTracks = 0;
  int _stopAfterStartIndex = 0;
  int _playlistSegmentMinutes = 0;
  bool _segmentAdvancePending = false;

  int get stopAfterTracks => _stopAfterTracks;
  int get playlistSegmentMinutes => _playlistSegmentMinutes;

  /// A one-tap session: 15 minutes from each track and then stop after
  /// 3/4 recordings. A natural short recording advances normally.
  void setTimedPlaylist(int tracks) {
    setStopAfterTracks(tracks);
    _playlistSegmentMinutes = tracks == 0 ? 0 : 15;
    _segmentAdvancePending = false;
    notifyListeners();
  }

  void _maybeAdvanceTimedPlaylist(Duration position) {
    if (_playlistSegmentMinutes == 0 ||
        _segmentAdvancePending ||
        _playlistQueue.isEmpty ||
        !_player.playing ||
        !playlistSegmentBoundary(position, _playlistSegmentMinutes)) {
      return;
    }
    _segmentAdvancePending = true;
    final index = _player.currentIndex ?? 0;
    final onLastSelectedTrack =
        _stopAfterTracks > 0 &&
        index - _stopAfterStartIndex + 1 >= _stopAfterTracks;
    if (onLastSelectedTrack || !_player.hasNext) {
      _playlistSegmentMinutes = 0;
      _stopAfterTracks = 0;
      unawaited(_player.pause());
      notifyListeners();
      return;
    }
    unawaited(_player.seekToNext().catchError((Object _) {
      _segmentAdvancePending = false;
    }));
  }

  /// Applies to this playlist queue only. The timer and Repeat One controls
  /// remain independent. A track manually skipped counts as traversed.
  void setStopAfterTracks(int tracks) {
    if (![0, 3, 4].contains(tracks)) {
      throw ArgumentError.value(tracks, 'tracks', 'Choose 0, 3 or 4 tracks');
    }
    if (tracks != 0 && _playlistQueue.isEmpty) {
      throw StateError('প্লেলিস্ট চালু করে এই অপশন বেছে নিন।');
    }
    _stopAfterTracks = tracks;
    _stopAfterStartIndex = _player.currentIndex ?? 0;
    notifyListeners();
  }

  /// Timer belongs to the shared playback session, not the player screen.
  /// Browsers may throttle timers when backgrounded; native device QA is separate.
  DateTime? get sleepDeadline => _sleepDeadline;

  static const supportedSleepMinutes = [0, 5, 15, 30, 60];

  void setSleepTimer(int minutes) {
    if (!supportedSleepMinutes.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes', 'Unsupported sleep timer');
    }
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    if (minutes != 0) {
      _sleepDeadline = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _sleepTimer = null;
        _sleepDeadline = null;
        // Pause rather than clearing the queue: resume positions stay intact.
        unawaited(_player.pause());
        notifyListeners();
      });
    }
    notifyListeners();
  }

  AudioPlayer get player => _player;
  LinkedResource? get resource => _resource;
  bool get hasSelection => _resource != null || _quranTitle != null;
  bool get isQuranSequence => _quranTitle != null && _quranQueue.length > 1;
  bool get isPersonalPlaylist => _playlistQueue.isNotEmpty;
  String? get playlistTitle => _playlistTitle;
  int get playlistLength => _playlistQueue.length;
  int get playlistIndex => _player.currentIndex ?? 0;
  String? get currentTitle =>
      _quranTitle ??
      (_resource?.titleBn?.trim().isNotEmpty == true
          ? _resource!.titleBn
          : _resource?.title);
  String? get currentVerseKey {
    final index = _player.currentIndex ?? 0;
    return _quranTitle != null && index >= 0 && index < _quranQueue.length
        ? _quranQueue[index].key
        : null;
  }

  int get quranVerseCount => _quranQueue.length;
  int get currentVerseIndex => _player.currentIndex ?? 0;

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
    _quranTitle = null;
    _quranQueue = const [];
    _lastSavedSecond = -1;
    // Old local blob URLs must remain valid until the player is stopped.
    notifyListeners();
    try {
      await _player.stop();
      _releaseLocalPlaylist();
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
      notifyListeners();
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

  /// Uses one shared engine for individual ayat, complete surahs and CMS audio.
  /// just_audio prepares the next playlist items; browsers/network quality can
  /// still introduce a small transition, so zero-gap is not guaranteed.
  Future<void> loadQuran({
    required String title,
    required List<QuranVerseAudio> verses,
  }) {
    if (verses.isEmpty) {
      return Future<void>.error(
        const AudioPlaybackException('এই সূরার জন্য তিলাওয়াত পাওয়া যায়নি।'),
      );
    }
    final sources = <AudioSource>[];
    for (final verse in verses) {
      final uri = Uri.tryParse(verse.url);
      if (uri == null ||
          uri.scheme != 'https' ||
          !{
            'verses.quran.foundation',
            'audio.qurancdn.com',
            'cdn.islamic.network',
            'cdn.alquran.cloud',
          }.contains(uri.host)) {
        return Future<void>.error(
          const AudioPlaybackException('অডিওর নিরাপদ লিংক পাওয়া যায়নি।'),
        );
      }
      sources.add(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: verse.key,
            title: '$title · ${verse.key}',
            album: 'Sukun Life',
          ),
        ),
      );
    }

    final previous = _loadQueue;
    final completion = Completer<void>();
    _loadQueue = completion.future;
    final request = ++_requestedLoad;
    return () async {
      try {
        await previous;
        if (request != _requestedLoad) return;
        try {
          await _persistCurrentPosition();
        } on Exception {
          // Optional history must not prevent switching to the Quran.
        }
        _resource = null;
        _quranTitle = null;
        _quranQueue = const [];
        notifyListeners();
        await _player.stop();
        _releaseLocalPlaylist();
        if (request != _requestedLoad) return;
        await _player.setLoopMode(LoopMode.off);
        await _player.setAudioSources(sources, preload: true);
        if (request != _requestedLoad) return;
        _quranTitle = title;
        _quranQueue = List.unmodifiable(verses);
        notifyListeners();
      } on PlayerException {
        throw const AudioPlaybackException('কুরআনের তিলাওয়াত লোড করা যায়নি।');
      } on PlayerInterruptedException {
        throw const AudioPlaybackException('অডিও লোড বন্ধ হয়ে গেছে।');
      } finally {
        completion.complete();
      }
    }();
  }

  void _releaseLocalPlaylist() {
    _stopAfterTracks = 0;
    _stopAfterStartIndex = 0;
    _playlistSegmentMinutes = 0;
    _segmentAdvancePending = false;
    _playlistQueue = const [];
    _playlistTitle = null;
    for (final handle in _offlineHandles) {
      handle.dispose();
    }
    _offlineHandles = const [];
  }

  /// One continuous native/web just_audio queue for CMS recordings.
  /// Callers must re-authorize saved resource IDs before constructing sources.
  /// `localUris` are created only from verified, app-private offline bytes.
  Future<void> loadPlaylist({
    required String title,
    required List<LinkedResource> resources,
    Map<String, Uri> localUris = const {},
    List<LocalAudioUri> handles = const [],
    int startIndex = 0,
  }) {
    if (resources.isEmpty || startIndex < 0 || startIndex >= resources.length) {
      return Future.error(
        const AudioPlaybackException('প্লেলিস্টে চালানোর মতো অডিও নেই।'),
      );
    }
    final sources = <AudioSource>[];
    for (final resource in resources) {
      final resolved = resolveResourceMedia(resource);
      final localUri = localUris[resource.id];
      if (localUri == null &&
          (resolved?.kind != ResourceMediaKind.audio ||
              resolved?.uri == null)) {
        for (final handle in handles) {
          handle.dispose();
        }
        return Future.error(
          const AudioPlaybackException('প্লেলিস্টে অডিওর লিংক সঠিক নয়।'),
        );
      }
      final uri = localUri ?? resolved!.uri!;
      if (localUris.containsKey(resource.id) &&
          !const ['blob', 'file'].contains(uri.scheme)) {
        for (final handle in handles) {
          handle.dispose();
        }
        return Future.error(
          const AudioPlaybackException('অফলাইন অডিও খোলা যাচ্ছে না।'),
        );
      }
      sources.add(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: resource.id,
            title: resource.titleBn?.trim().isNotEmpty == true
                ? resource.titleBn!
                : resource.title,
            album: title,
            artUri: _validHttpsUri(resource.thumbnailUrl),
          ),
        ),
      );
    }
    final previous = _loadQueue;
    final completion = Completer<void>();
    _loadQueue = completion.future;
    final request = ++_requestedLoad;
    return () async {
      try {
        await previous;
        if (request != _requestedLoad) {
          for (final handle in handles) {
            handle.dispose();
          }
          return;
        }
        try {
          await _persistCurrentPosition();
        } on Exception {
          /* optional */
        }
        await _player.stop();
        _releaseLocalPlaylist();
        if (request != _requestedLoad) {
          for (final handle in handles) {
            handle.dispose();
          }
          return;
        }
        await _player.setLoopMode(LoopMode.off);
        await _player.setAudioSources(
          sources,
          initialIndex: startIndex,
          preload: true,
        );
        if (request != _requestedLoad) {
          await _player.stop();
          for (final handle in handles) {
            handle.dispose();
          }
          return;
        }
        _quranTitle = null;
        _quranQueue = const [];
        _playlistTitle = title;
        _playlistQueue = List.unmodifiable(resources);
        _offlineHandles = List.unmodifiable(handles);
        _resource = resources[startIndex];
        _lastSavedSecond = -1;
        notifyListeners();
      } on PlayerException {
        for (final handle in handles) {
          handle.dispose();
        }
        throw const AudioPlaybackException(
          'প্লেলিস্টের অডিও চালানো যাচ্ছে না।',
        );
      } finally {
        completion.complete();
      }
    }();
  }

  /// This returns immediately; a play Future itself completes when audio ends.
  void resumeCurrent() {
    if (!hasSelection) return;
    if (_player.processingState == ProcessingState.completed) {
      unawaited(
        _player.seek(Duration.zero, index: 0).then((_) => _player.play()),
      );
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> previous() => _player.seekToPrevious();
  Future<void> next() => _player.seekToNext();

  Future<void> stopAndClear() async {
    setSleepTimer(0);
    setStopAfterTracks(0);
    ++_requestedLoad;
    await _loadQueue;
    try {
      await _persistCurrentPosition();
    } on Exception {
      // No-op if local persistence is not available.
    }
    await _player.stop();
    _releaseLocalPlaylist();
    _resource = null;
    _quranTitle = null;
    _quranQueue = const [];
    notifyListeners();
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

  @override
  Future<void> dispose() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    await _persistCurrentPosition();
    await _positionSubscription.cancel();
    await _stateSubscription.cancel();
    await _indexSubscription.cancel();
    await _player.dispose();
    _releaseLocalPlaylist();
    super.dispose();
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
