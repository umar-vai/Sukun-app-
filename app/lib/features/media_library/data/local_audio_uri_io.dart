import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'local_audio_uri.dart';

/// A per-session copy. The offline source remains in app-private storage.
Future<Uri> _createFile(Uint8List bytes) async {
  final root = await getTemporaryDirectory();
  final file = File('${root.path}/sukun_offline_playback.mp3');
  await file.writeAsBytes(bytes, flush: true);
  return file.uri;
}

LocalAudioUri createLocalAudioUri(Uint8List bytes) =>
    _NativeAudioUri(bytes);

class _NativeAudioUri implements LocalAudioUri {
  _NativeAudioUri(Uint8List bytes) {
    // Native Uri is produced lazily; synchronous callers should use
    // playOfflineBytes() after waiting on ready.
    ready = _createFile(bytes).then((value) => _uri = value);
  }
  late final Future<void> ready;
  Uri? _uri;
  @override
  Uri get uri => _uri ?? (throw StateError('Offline audio is preparing.'));
  @override
  void dispose() {
    final value = _uri;
    if (value != null) {
      File.fromUri(value).delete().catchError((Object _) => File.fromUri(value));
    }
  }
}
