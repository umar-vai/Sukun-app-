import 'package:sukun_life/features/content_admin/domain/admin_content.dart';

abstract interface class ContentAdminRepository {
  Future<List<AdminContentItem>> listContent({String query = ''});

  Future<AdminContentItem?> getContent(String contentItemId);

  Future<List<ContentCategory>> listCategories();

  Future<List<ContentReview>> listReviews(String contentItemId);

  Future<List<AdminContentCollection>> listCollections();

  Future<List<ContentCategory>> installStandardResourceTaxonomy({
    required String requestId,
  });

  Future<AdminContentCollection> saveCollection(
    SaveContentCollectionInput input,
  );

  Future<AdminContentCollection> transitionCollection({
    required String collectionId,
    required String transition,
    required String requestId,
  });

  Future<AdminContentItem> saveContent(SaveContentInput input);

  Future<AdminContentItem> transitionContent({
    required String contentItemId,
    required String transition,
    required String requestId,
    String? notes,
  });

  Future<ContentCategory> saveCategory({
    required String name,
    required String slug,
    required String requestId,
    String? categoryId,
    String? parentId,
    String? nameBn,
    int sortOrder = 0,
    bool isActive = true,
  });
}

class ContentAdminException implements Exception {
  const ContentAdminException(this.message);

  final String message;

  @override
  String toString() => message;
}
