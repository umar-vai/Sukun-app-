import 'package:sukun_life/features/resources/domain/content_resource.dart';

abstract interface class ResourcesRepository {
  Future<ContentResource?> getResource(String resourceId);
}

class ResourceException implements Exception {
  const ResourceException(this.message);

  final String message;

  @override
  String toString() => message;
}
