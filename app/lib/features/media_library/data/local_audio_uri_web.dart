import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'local_audio_uri.dart';

Future<LocalAudioUri> createLocalAudioUri(Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'audio/mpeg'),
  );
  return _WebAudioUri(web.URL.createObjectURL(blob));
}

class _WebAudioUri implements LocalAudioUri {
  _WebAudioUri(this._value);
  final String _value;
  @override
  Uri get uri => Uri.parse(_value);
  @override
  void dispose() => web.URL.revokeObjectURL(_value);
}
