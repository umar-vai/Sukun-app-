import 'dart:convert';
import 'dart:js_interop';

import 'audio_frequency_types.dart';

@JS('sukunSpectrum.attach')
external void _attach(JSString url);

@JS('sukunSpectrum.sync')
external void _sync(JSNumber seconds, JSBoolean playing, JSNumber speed);

@JS('sukunSpectrum.sample')
external JSString _sample();

@JS('sukunSpectrum.stop')
external void _stop();

AudioFrequencySource createAudioFrequencySource() => _WebAudioFrequency();

class _WebAudioFrequency implements AudioFrequencySource {
  Uri? _uri;
  FrequencyStatus _status = FrequencyStatus.idle;

  @override
  void attach(Uri? url) {
    if (url == _uri) return;
    _uri = url;
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      _status = FrequencyStatus.unsupported;
      return;
    }
    try {
      _attach(url.toString().toJS);
      _status = FrequencyStatus.ready;
    } catch (_) {
      _status = FrequencyStatus.unsupported;
    }
  }

  @override
  void sync(Duration position, bool playing, double speed) {
    if (_uri == null || _status == FrequencyStatus.unsupported) return;
    try {
      _sync((position.inMilliseconds / 1000).toJS, playing.toJS, speed.toJS);
    } catch (_) {
      _status = FrequencyStatus.unsupported;
    }
  }

  @override
  AudioFrequencyFrame sample() {
    if (_status == FrequencyStatus.unsupported) {
      return const AudioFrequencyFrame(status: FrequencyStatus.unsupported);
    }
    try {
      final data = jsonDecode(_sample().toDart);
      if (data is! Map<String, dynamic>) {
        return const AudioFrequencyFrame(status: FrequencyStatus.blocked);
      }
      final state = switch (data['status']) {
        'active' => FrequencyStatus.active,
        'ready' => FrequencyStatus.ready,
        'paused' || 'idle' => FrequencyStatus.paused,
        'cors-or-network' || 'gesture-required' => FrequencyStatus.blocked,
        _ => FrequencyStatus.unsupported,
      };
      final parsed = data['bands'];
      final bands = parsed is List
          ? parsed
                .whereType<num>()
                .take(36)
                .map((value) => value.toDouble().clamp(0, 1).toDouble())
                .toList(growable: false)
          : <double>[];
      return AudioFrequencyFrame(
        status: state,
        bands: bands,
        bass: _safeLevel(data['bass']),
        mid: _safeLevel(data['mid']),
        treble: _safeLevel(data['treble']),
      );
    } catch (_) {
      return const AudioFrequencyFrame(status: FrequencyStatus.unsupported);
    }
  }

  static double _safeLevel(Object? value) =>
      value is num ? value.toDouble().clamp(0, 1).toDouble() : 0;

  @override
  void dispose() {
    _uri = null;
    try {
      _stop();
    } catch (_) {
      // An old cached index.html may not include the analysis JS bridge.
    }
  }
}
