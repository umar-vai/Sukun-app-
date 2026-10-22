import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'local_audio_uri.dart';

Future<LocalAudioUri> createLocalAudioUri(Uint8List bytes) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/sukun_offline_${const Uuid().v4()}.mp3');
  await file.writeAsBytes(bytes, flush: true);
  return _NativeAudioUri(file);
}

class _NativeAudioUri implements LocalAudioUri {
  _NativeAudioUri(this._file);
  final File _file;
  @override
  Uri get uri => _file.uri;
  @override
  void dispose() {
    _file.delete().then((_) {}, onError: (Object _, StackTrace __) {});
  }
}
