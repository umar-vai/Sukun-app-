import 'dart:typed_data';

import 'local_audio_uri_unsupported.dart'
    if (dart.library.io) 'local_audio_uri_io.dart'
    if (dart.library.js_interop) 'local_audio_uri_web.dart' as platform;

abstract interface class LocalAudioUri {
  Uri get uri;
  void dispose();
}

Future<LocalAudioUri> createLocalAudioUri(Uint8List bytes) =>
    platform.createLocalAudioUri(bytes);
