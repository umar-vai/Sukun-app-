import 'dart:typed_data';
import 'offline_byte_store.dart';

OfflineByteStore createOfflineByteStore() => _UnsupportedOfflineStore();

class _UnsupportedOfflineStore implements OfflineByteStore {
  @override
  Future<void> write(String key, Uint8List bytes) =>
      Future.error(UnsupportedError('Offline storage is not available.'));
  @override
  Future<Uint8List?> read(String key) =>
      Future.error(UnsupportedError('Offline storage is not available.'));
  @override
  Future<void> delete(String key) =>
      Future.error(UnsupportedError('Offline storage is not available.'));
}
