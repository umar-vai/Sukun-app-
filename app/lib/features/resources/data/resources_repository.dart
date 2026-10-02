import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';

abstract interface class ResourcesRepository {
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  });

  Future<ContentResource?> getResource(String resourceId);

  Future<List<QuranSurahSummary>> browseSurahs();

  Future<List<ContentResource>> browseSurah(int surahNumber);

  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  });

  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  });

  Future<ContentCollectionDetails?> getCollection(String collectionId);
}

class ResourceException implements Exception {
  const ResourceException(this.message);

  final String message;

  @override
  String toString() => message;
}
