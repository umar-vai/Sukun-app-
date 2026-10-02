import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/data/supabase_resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final resourcesRepositoryProvider = Provider<ResourcesRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableResourcesRepository();
  }
  return SupabaseResourcesRepository(Supabase.instance.client);
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
