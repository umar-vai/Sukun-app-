import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/data/supabase_content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final contentAdminRepositoryProvider = Provider<ContentAdminRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableContentAdminRepository();
  }
  return SupabaseContentAdminRepository(Supabase.instance.client);
});

final class UnavailableContentAdminRepository
    implements ContentAdminRepository {
  const UnavailableContentAdminRepository();

  Never _unavailable() => throw const ContentAdminException(
    'Connect Supabase to manage canonical resources securely.',
  );

  @override
  Future<AdminContentItem?> getContent(String contentItemId) async =>
      _unavailable();

  @override
  Future<List<AdminContentItem>> listContent({String query = ''}) async =>
      _unavailable();

  @override
  Future<List<ContentCategory>> listCategories() async => _unavailable();

  @override
  Future<List<ContentReview>> listReviews(String contentItemId) async =>
      _unavailable();

  @override
  Future<List<AdminContentCollection>> listCollections() async =>
      _unavailable();

  @override
  Future<List<ContentCategory>> installStandardResourceTaxonomy({
    required String requestId,
  }) async => _unavailable();

  @override
  Future<AdminContentCollection> saveCollection(
    SaveContentCollectionInput input,
  ) async => _unavailable();

  @override
  Future<AdminContentCollection> transitionCollection({
    required String collectionId,
    required String transition,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<AdminContentItem> saveContent(SaveContentInput input) async =>
      _unavailable();

  @override
  Future<ContentCategory> saveCategory({
    required String name,
    required String slug,
    required String requestId,
    String? categoryId,
    String? parentId,
    String? nameBn,
    int sortOrder = 0,
    bool isActive = true,
  }) async => _unavailable();

  @override
  Future<AdminContentItem> transitionContent({
    required String contentItemId,
    required String transition,
    required String requestId,
    String? notes,
  }) async => _unavailable();
}
