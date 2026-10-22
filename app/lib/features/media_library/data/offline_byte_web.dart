import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

import 'offline_byte_store.dart';

OfflineByteStore createOfflineByteStore() => _BrowserIndexedDbStore();

/// Real IndexedDB binary storage, not localStorage/base64. Browser eviction,
/// Safari private browsing and CORS may restrict offline availability.
class _BrowserIndexedDbStore implements OfflineByteStore {
  Future<Database>? _database;

  Future<Database> get _db => _database ??= idbFactoryBrowser.open(
    'sukun-public-offline-v1',
    version: 1,
    onUpgradeNeeded: (event) {
      event.database.createObjectStore('media');
    },
  );

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final db = await _db;
    final transaction = db.transaction('media', idbModeReadWrite);
    await transaction.objectStore('media').put(bytes, key);
    await transaction.completed;
  }

  @override
  Future<Uint8List?> read(String key) async {
    final db = await _db;
    final transaction = db.transaction('media', idbModeReadOnly);
    final value = await transaction.objectStore('media').getObject(key);
    await transaction.completed;
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(value.cast<int>());
    return null;
  }

  @override
  Future<void> delete(String key) async {
    final db = await _db;
    final transaction = db.transaction('media', idbModeReadWrite);
    await transaction.objectStore('media').delete(key);
    await transaction.completed;
  }
}
