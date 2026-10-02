import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/data/supabase_resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
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
  Future<ContentResource?> getResource(String resourceId) async =>
      throw const ResourceException('Connect Supabase to open this resource.');
}
