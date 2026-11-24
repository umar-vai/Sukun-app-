import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/resources/data/cached_resources_repository.dart';
import 'package:sukun_life/features/resources/data/resource_disk_cache.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

final class _MemoryDisk implements ResourceDiskCache {
  final Map<String, DiskCacheEntry> store = {};

  @override
  Future<DiskCacheEntry?> read(String key) async => store[key];

  @override
  Future<void> write(String key, DiskCacheEntry entry) async {
    store[key] = entry;
  }

  @override
  Future<void> removeOtherScopes(String scope) async {
    store.removeWhere((_, entry) => entry.scope != scope);
  }

  @override
  Future<void> clear() async {
    store.clear();
  }
}

ContentResource _dua(String title) => ContentResource(
  id: 'dua-1',
  type: 'dua',
  title: title,
  visibility: 'public',
  status: 'published',
);

final class _Backend implements ResourcesRepository {
  _Backend(this.items);

  List<ContentResource> items;
  int calls = 0;

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    calls++;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CachedResourcesRepository _repo(
  _Backend backend,
  _MemoryDisk disk, {
  String? user,
  DateTime Function()? now,
}) {
  return CachedResourcesRepository(backend, () => user, disk: disk, now: now);
}

Future<List<ContentResource>> _read(CachedResourcesRepository repo) {
  return repo.browseResources(types: const {'dua'});
}

void main() {
  test('a saved list opens at once after the app restarts', () async {
    final disk = _MemoryDisk();
    final first = _Backend([_dua('Morning dua')]);
    await _read(_repo(first, disk));
    expect(first.calls, 1);

    // A new repository stands in for a fresh app launch.
    final second = _Backend([_dua('Should not be asked')]);
    final shown = await _read(_repo(second, disk));
    expect(second.calls, 0);
    expect(shown.single.title, 'Morning dua');
  });

  test('an older saved list shows first, then refreshes quietly', () async {
    final disk = _MemoryDisk();
    var now = DateTime(2026, 1, 1);
    final first = _Backend([_dua('Old text')]);
    await _read(_repo(first, disk, now: () => now));

    now = now.add(const Duration(hours: 2));
    final second = _Backend([_dua('New text')]);
    final shown = await _read(_repo(second, disk, now: () => now));
    expect(shown.single.title, 'Old text');

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(second.calls, 1);

    final third = _Backend([_dua('Unused')]);
    final next = await _read(_repo(third, disk, now: () => now));
    expect(third.calls, 0);
    expect(next.single.title, 'New text');
  });

  test('saved data of another account is never shown', () async {
    final disk = _MemoryDisk();
    final forA = _Backend([_dua('Private to A')]);
    await _read(_repo(forA, disk, user: 'user-a'));

    final forB = _Backend([_dua('For B')]);
    final shown = await _read(_repo(forB, disk, user: 'user-b'));
    expect(forB.calls, 1);
    expect(shown.single.title, 'For B');
    final scopes = disk.store.values.map((entry) => entry.scope);
    expect(scopes.every((scope) => scope == 'user-b'), isTrue);
  });

  test('empty answers are not saved and damaged data is ignored', () async {
    final disk = _MemoryDisk();
    await _read(_repo(_Backend(const []), disk));
    expect(disk.store, isEmpty);

    disk.store['browse|dua|'] = DiskCacheEntry(
      savedAt: DateTime.now(),
      scope: 'guest',
      json: '{not json',
    );
    final backend = _Backend([_dua('From backend')]);
    final shown = await _read(_repo(backend, disk));
    expect(backend.calls, 1);
    expect(shown.single.title, 'From backend');
  });

  test('clear() removes everything saved on the phone', () async {
    final disk = _MemoryDisk();
    final repo = _repo(_Backend([_dua('x')]), disk);
    await _read(repo);
    expect(disk.store, isNotEmpty);
    await repo.clear();
    expect(disk.store, isEmpty);
  });

  test('a resource keeps every field through save and load', () {
    final original = ContentResource(
      id: 'r1',
      slug: 'srg2024-c01-t001',
      type: 'guide',
      title: 'Title',
      titleBn: 'শিরোনাম',
      summary: 'সারাংশ',
      body: 'লেখা',
      arabicText: 'نص',
      banglaText: 'বাংলা',
      transliteration: 'nass',
      translation: 'অনুবাদ',
      referenceText: 'ref',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://example.com/a.mp3',
      createdAt: DateTime.utc(2026, 1, 2),
      categoryId: 'c1',
      categorySlug: 'dua-azkar-ma-01',
      categoryName: 'Cat',
      categoryNameBn: 'বিভাগ',
      sortOrder: 4,
      visibility: 'public',
      status: 'published',
    );
    final json = decodeDiskJson(encodeDiskJson(original.toJson()));
    final restored = ContentResource.fromJson(json! as Map<String, dynamic>);
    expect(restored.toJson(), original.toJson());
    expect(restored.categorySlug, 'dua-azkar-ma-01');
    expect(restored.sortOrder, 4);
  });

  test('prefs store round-trips and drops other scopes', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesResourceDiskCache();
    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final guest = DiskCacheEntry(
      savedAt: at,
      scope: 'guest',
      json: '{"a":"x|y"}',
    );
    final other = DiskCacheEntry(savedAt: at, scope: 'user-a', json: '[]');
    await store.write('k1', guest);
    await store.write('k2', other);

    final back = await store.read('k1');
    expect(back?.json, '{"a":"x|y"}');
    expect(back?.scope, 'guest');
    expect(back?.savedAt, at);

    await store.removeOtherScopes('guest');
    expect(await store.read('k1'), isNotNull);
    expect(await store.read('k2'), isNull);
  });
}
