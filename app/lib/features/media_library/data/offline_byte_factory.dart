import 'offline_byte_store.dart';
import 'offline_byte_unsupported.dart'
    if (dart.library.io) 'offline_byte_io.dart'
    if (dart.library.js_interop) 'offline_byte_web.dart' as platform;

OfflineByteStore createOfflineByteStore() => platform.createOfflineByteStore();
