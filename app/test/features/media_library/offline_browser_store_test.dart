import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/media_library/data/local_audio_uri.dart';
import 'package:sukun_life/features/media_library/data/offline_byte_factory.dart';
import 'package:sukun_life/features/media_library/data/offline_library.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'real browser IndexedDB persists binary bytes across store instances',
    () async {
      final store = createOfflineByteStore();
      final key = 'browser-roundtrip-synthetic-20261022';
      final media = Uint8List.fromList([0, 1, 2, 127, 128, 255]);
      try {
        await store.write(key, media);
        final reloaded = createOfflineByteStore();
        expect(await reloaded.read(key), media);
        await reloaded.delete(key);
        expect(await store.read(key), isNull);
      } finally {
        await store.delete(key);
      }
    },
    skip: !kIsWeb,
  );

  test(
    'real browser blob URL is created and disposed for offline MP3',
    () async {
      final handle = await createLocalAudioUri(
        Uint8List.fromList([0x49, 0x44, 0x33, 4, 0, 0, 1]),
      );
      expect(handle.uri.scheme, 'blob');
      handle.dispose();
    },
    skip: !kIsWeb,
  );

  test(
    'end-to-end offline save, restart, read without network and delete',
    () async {
      final bytes = Uint8List.fromList([
        0x49,
        0x44,
        0x33,
        4,
        0,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
      var networkCalls = 0;
      http.Client fakeClient() => MockClient((request) async {
        networkCalls++;
        return http.Response.bytes(bytes, 200);
      });
      final resource = ContentResource(
        id: 'chrome-test-only-public-audio',
        type: 'audio',
        title: 'Synthetic test MP3',
        status: 'published',
        visibility: 'public',
        mediaSourceType: 'direct_audio_url',
        mediaUrl: 'https://files.ruqyahbd.org/audio/browser-test-only.mp3',
      );
      Future<Set<String>> allowed() async => {resource.mediaUrl!};

      final library = OfflineLibrary(
        clientFactory: fakeClient,
        authorizedAudioUrls: allowed,
      );
      await library.open('synthetic-browser-owner');
      try {
        await library.download(resource);
        expect(networkCalls, 1);
        expect(library.items.single.id, resource.id);
        library.close();

        final reopened = OfflineLibrary(
          clientFactory: () => MockClient((request) async {
            fail('offline read must never call the network');
          }),
          authorizedAudioUrls: allowed,
        );
        await reopened.open('synthetic-browser-owner');
        expect(reopened.items.single.id, resource.id);
        expect(await reopened.read(resource.id), bytes);
        await reopened.remove(resource.id);
        expect(await reopened.read(resource.id), isNull);
        reopened.dispose();
      } finally {
        await library.open('synthetic-browser-owner');
        await library.remove(resource.id);
        library.dispose();
      }
    },
    skip: !kIsWeb,
  );
}
