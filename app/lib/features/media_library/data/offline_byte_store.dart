import 'dart:typed_data';

/// Only downloadable PUBLIC resources are stored here; never clinical records.
abstract interface class OfflineByteStore {
  Future<void> write(String key, Uint8List bytes);
  Future<Uint8List?> read(String key);
  Future<void> delete(String key);
}
