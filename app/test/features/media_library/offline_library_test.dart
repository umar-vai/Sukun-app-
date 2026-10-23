import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/media_library/data/offline_byte_store.dart';
import 'package:sukun_life/features/media_library/data/offline_library.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

class MemoryOfflineBytes implements OfflineByteStore {
  final entries = <String, Uint8List>{};
  @override
  Future<void> write(String key, Uint8List bytes) async {
    entries[key] = bytes;
  }

  @override
  Future<Uint8List?> read(String key) async {
    return entries[key];
  }

  @override
  Future<void> delete(String key) async {
    entries.remove(key);
  }
}

ContentResource audio({
  String visibility = 'public',
  String status = 'published',
  String mediaUrl = 'https://files.ruqyahbd.org/audio/approved.mp3',
}) => ContentResource(
  id: 'media-1',
  type: 'audio',
  title: 'Approved recording',
  visibility: visibility,
  status: status,
  mediaSourceType: 'direct_audio_url',
  mediaUrl: mediaUrl,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only published public authorized MP3 is downloadable', () {
    final allowed = {'https://files.ruqyahbd.org/audio/approved.mp3'};
    expect(canSaveOffline(audio(), ownerAuthorizedAudioUrls: allowed), isTrue);
    expect(
      canSaveOffline(
        audio(visibility: 'patient_only'),
        ownerAuthorizedAudioUrls: allowed,
      ),
      isFalse,
    );
    expect(
      canSaveOffline(audio(status: 'draft'), ownerAuthorizedAudioUrls: allowed),
      isFalse,
    );
    expect(
      canSaveOffline(
        audio(mediaUrl: 'https://evil.test/track.mp3'),
        ownerAuthorizedAudioUrls: allowed,
      ),
      isFalse,
    );
    expect(
      canSaveOffline(
        audio(
          mediaUrl:
              'https://files.ruqyahbd.org/audio/approved.mp3?token=secret',
        ),
        ownerAuthorizedAudioUrls: allowed,
      ),
      isFalse,
    );
    expect(
      canSaveOffline(
        ContentResource(
          id: 'private',
          type: 'pdf',
          title: 'Patient prescription',
          visibility: 'assigned_only',
          status: 'published',
          mediaSourceType: 'external_pdf',
          mediaUrl: 'https://example.org/private.pdf',
          rightsNote: 'offline_allowed',
        ),
        ownerAuthorizedAudioUrls: allowed,
      ),
      isFalse,
    );
  });

  test(
    'offline MP3 is saved, integrity verified and isolated by owner',
    () async {
      final store = MemoryOfflineBytes();
      final media = Uint8List.fromList([0x49, 0x44, 0x33, 4, 0, 0, 1]);
      http.Client factory() => MockClient(
        (request) async => http.Response.bytes(
          media,
          200,
          headers: {'content-type': 'audio/mpeg'},
        ),
      );
      final library = OfflineLibrary(
        useWebMediaGateway: false,
        bytes: store,
        clientFactory: factory,
        authorizedAudioUrls: () async => {
          'https://files.ruqyahbd.org/audio/approved.mp3',
        },
      );
      await library.open('owner-a');
      await library.download(audio());
      expect(library.items.length, 1);
      expect(await library.read('media-1'), media);
      library.close();
      await library.open('owner-b');
      expect(library.items, isEmpty);
      expect(await library.read('media-1'), isNull);
      library.close();
      await library.open('owner-a');
      expect((await library.read('media-1'))?.length, 7);
      store.entries.values.first[0] = 0;
      expect(await library.read('media-1'), isNull);
      expect(library.items, isEmpty);
      library.dispose();
    },
  );

  test(
    'invalid HTML instead of MP3 is rejected without saving bytes',
    () async {
      final store = MemoryOfflineBytes();
      final library = OfflineLibrary(
        useWebMediaGateway: false,
        bytes: store,
        clientFactory: () => MockClient(
          (request) async => http.Response('<html>not audio</html>', 200),
        ),
        authorizedAudioUrls: () async => {
          'https://files.ruqyahbd.org/audio/approved.mp3',
        },
      );
      await library.open('owner-a');
      await expectLater(library.download(audio()), throwsStateError);
      expect(store.entries, isEmpty);
      expect(library.items, isEmpty);
      library.dispose();
    },
  );
  test(
    'rapid second download is rejected while rights lookup is pending',
    () async {
      final permissions = Completer<Set<String>>();
      final library = OfflineLibrary(
        useWebMediaGateway: false,
        bytes: MemoryOfflineBytes(),
        authorizedAudioUrls: () => permissions.future,
      );
      await library.open('owner-a');
      final first = library.download(audio());
      expect(library.busy, isTrue);
      await expectLater(library.download(audio()), throwsStateError);
      library.close();
      await library.open('owner-b');
      permissions.complete({'https://files.ruqyahbd.org/audio/approved.mp3'});
      await expectLater(first, throwsStateError);
      expect(library.items, isEmpty);
      library.dispose();
    },
  );

  test(
    'existing downloads over 250 MB do not block an authorized new file',
    () async {
      // Metadata fixture only: do not allocate 300 MiB just for a quota test.
      final past = DateTime.utc(2026, 10, 21);
      final oldItems = [
        for (var i = 0; i < 3; i++)
          OfflineItem(
            id: 'already-saved-$i',
            title: 'Saved audio $i',
            kind: 'audio',
            size: 100 * 1024 * 1024,
            digest: 'metadata-only',
            savedAt: past,
          ),
      ];
      SharedPreferences.setMockInitialValues({
        'sukun.offline.public.v1.owner-a': jsonEncode(
          oldItems.map((item) => item.toJson()).toList(),
        ),
      });
      final bytes = MemoryOfflineBytes();
      final mp3 = Uint8List.fromList([0x49, 0x44, 0x33, 4, 0, 0, 1]);
      final library = OfflineLibrary(
        useWebMediaGateway: false,
        bytes: bytes,
        clientFactory: () => MockClient(
          (request) async => http.Response.bytes(mp3, 200),
        ),
        authorizedAudioUrls: () async => {
          'https://files.ruqyahbd.org/audio/approved.mp3',
        },
      );
      await library.open('owner-a');
      expect(library.totalBytes, 300 * 1024 * 1024);
      await library.download(audio());
      expect(library.items.length, 4);
      expect(await library.read('media-1'), mp3);
      library.dispose();
    },
  );

  test('negated rights note does not authorize PDF offline copying', () {
    final pdf = ContentResource(
      id: 'public-pdf',
      type: 'pdf',
      title: 'Test PDF',
      status: 'published',
      visibility: 'public',
      mediaSourceType: 'external_pdf',
      mediaUrl: 'https://example.org/test.pdf',
      rightsNote: 'not_offline_allowed',
    );
    expect(canSaveOffline(pdf, ownerAuthorizedAudioUrls: const {}), isFalse);
  });
}
