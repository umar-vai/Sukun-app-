import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/resources/data/cached_resources_repository.dart';
import 'package:sukun_life/features/resources/data/resource_disk_cache.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/data/supabase_resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final resourcesRepositoryProvider = Provider<ResourcesRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableResourcesRepository();
  }
  final client = Supabase.instance.client;
  return CachedResourcesRepository(
    SupabaseResourcesRepository(client),
    () => client.auth.currentUser?.id,
    ttl: const Duration(minutes: 15),
    // Saved on the phone so reopening the app needs no loaders. Cleared on
    // sign-out and whenever the signed-in identity changes.
    disk: SharedPreferencesResourceDiskCache(),
  );
});

final class UnavailableResourcesRepository implements ResourcesRepository {
  const UnavailableResourcesRepository();

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async =>
      throw const ResourceException('Connect Supabase to browse resources.');

  @override
  Future<ContentResource?> getResource(String resourceId) async =>
      throw const ResourceException('Connect Supabase to open this resource.');

  @override
  Future<List<QuranSurahSummary>> browseSurahs() async =>
      throw const ResourceException('Connect Supabase to browse Surahs.');

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) async =>
      throw const ResourceException('Connect Supabase to browse Ayat.');

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) async =>
      throw const ResourceException('Connect Supabase to browse topics.');

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) async => throw const ResourceException(
    'Connect Supabase to browse Ayat collections.',
  );

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) async =>
      throw const ResourceException(
        'Connect Supabase to open this collection.',
      );
}
