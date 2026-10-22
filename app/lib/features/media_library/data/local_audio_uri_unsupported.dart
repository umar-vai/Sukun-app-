import 'dart:typed_data';
import 'local_audio_uri.dart';

Future<LocalAudioUri> createLocalAudioUri(Uint8List bytes) =>
    Future.error(UnsupportedError('Offline audio is unavailable.'));
