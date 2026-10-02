import 'package:sukun_life/features/resources/domain/content_resource.dart';

abstract interface class ResourcesRepository {
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  });

  Future<ContentResource?> getResource(String resourceId);
}

class ResourceException implements Exception {
  const ResourceException(this.message);

  final String message;

  @override
  String toString() => message;
}
