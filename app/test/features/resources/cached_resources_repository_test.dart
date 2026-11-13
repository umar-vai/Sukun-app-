import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/cached_resources_repository.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';

final class _CountingRepository implements ResourcesRepository {
  int browseCalls = 0;
  int surahCalls = 0;
  bool failNext = false;

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    browseCalls++;
    if (failNext) {
      failNext = false;
      throw const ResourceException('offline');
    }
    return const <ContentResource>[];
  }

  @override
  Future<List<QuranSurahSummary>> browseSurahs() async {
    surahCalls++;
    return const <QuranSurahSummary>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('repeat reads are served from memory until the TTL ends', () async {
    var now = DateTime(2026, 1, 1);
    final inner = _CountingRepository();
    final cache = CachedResourcesRepository(
      inner,
      scope: () => 'user-a',
      now: () => now,
    );

    await cache.browseSurahs();
    await cache.browseSurahs();
    expect(inner.surahCalls, 1);

    now = now.add(const Duration(minutes: 6));
    await cache.browseSurahs();
    expect(inner.surahCalls, 2);
  });

  test('a different signed-in user never sees another user cache', () async {
    var user = 'user-a';
    final inner = _CountingRepository();
    final cache = CachedResourcesRepository(inner, scope: () => user);

    await cache.browseSurahs();
    user = 'user-b';
    await cache.browseSurahs();
    expect(inner.surahCalls, 2);
  });

  test('failures and typed searches are never cached', () async {
    final inner = _CountingRepository();
    final cache = CachedResourcesRepository(inner, scope: () => null);

    inner.failNext = true;
    await expectLater(
      cache.browseResources(types: const {'quran'}),
      throwsA(isA<ResourceException>()),
    );
    await cache.browseResources(types: const {'quran'});
    await cache.browseResources(types: const {'quran'});
    expect(inner.browseCalls, 2);

    await cache.browseResources(query: 'noor');
    await cache.browseResources(query: 'noor');
    expect(inner.browseCalls, 4);
  });
}
