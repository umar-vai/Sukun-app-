import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'offline_byte_store.dart';

OfflineByteStore createOfflineByteStore() => _PrivateFileStore();

/// App-support directory is private to this installation, not Downloads.
class _PrivateFileStore implements OfflineByteStore {
  Future<File> _file(String key) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/sukun_public_offline_v1');
    await dir.create(recursive: true);
    final name = sha256.convert(utf8.encode(key)).toString();
    return File('${dir.path}/$name.media');
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final file = await _file(key);
    final temporary = File('${file.path}.partial');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }
}
