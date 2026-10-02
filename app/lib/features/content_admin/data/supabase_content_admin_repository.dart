import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseContentAdminRepository implements ContentAdminRepository {
  const SupabaseContentAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminContentItem>> listContent({String query = ''}) async {
    try {
      final response = await _client
          .from('content_items')
          .select()
          .order('updated_at', ascending: false)
          .limit(200);
      final items = response.map(AdminContentItem.fromJson);
      final term = query.trim().toLowerCase();
      return items
          .where(
            (item) =>
                term.isEmpty ||
                item.title.toLowerCase().contains(term) ||
                (item.titleBn?.toLowerCase().contains(term) ?? false) ||
                item.slug.contains(term) ||
                item.type.contains(term),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<AdminContentItem?> getContent(String contentItemId) async {
    try {
      final response = await _client
          .from('content_items')
          .select()
          .eq('id', contentItemId)
          .maybeSingle();
      return response == null ? null : AdminContentItem.fromJson(response);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<List<ContentCategory>> listCategories() async {
    try {
      final response = await _client
          .from('content_categories')
          .select()
          .order('sort_order')
          .order('name');
      return response.map(ContentCategory.fromJson).toList(growable: false);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<List<ContentReview>> listReviews(String contentItemId) async {
    try {
      final response = await _client
          .from('content_reviews')
          .select('id,decision,notes,created_at')
          .eq('content_item_id', contentItemId)
          .order('created_at', ascending: false);
      return response.map(ContentReview.fromJson).toList(growable: false);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<List<AdminContentCollection>> listCollections() async {
    try {
      final response = await _client
          .from('content_collections')
          .select(
            'id,type,title,title_bn,slug,summary,visibility,status,content_collection_items(content_item_id,sort_order)',
          )
          .order('updated_at', ascending: false);
      return response
          .map(AdminContentCollection.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<List<ContentCategory>> installStandardResourceTaxonomy({
    required String requestId,
  }) async {
    try {
      final response = await _client.rpc(
        'install_standard_resource_taxonomy',
        params: {'p_request_id': requestId},
      );
      return (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ContentCategory.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<AdminContentCollection> saveCollection(
    SaveContentCollectionInput input,
  ) async {
    final validationError = input.validate();
    if (validationError != null) throw ContentAdminException(validationError);
    try {
      final response = await _client.rpc(
        'save_content_collection',
        params: {
          'p_type': input.type,
          'p_title': input.title.trim(),
          'p_slug': input.slug.trim(),
          'p_content_item_ids': input.contentItemIds,
          'p_collection_id': input.collectionId,
          'p_title_bn': _value(input.titleBn),
          'p_summary': _value(input.summary),
          'p_visibility': input.visibility,
          'p_request_id': input.requestId,
        },
      );
      return AdminContentCollection.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<AdminContentCollection> transitionCollection({
    required String collectionId,
    required String transition,
    required String requestId,
  }) async {
    try {
      final response = await _client.rpc(
        'transition_content_collection',
        params: {
          'p_collection_id': collectionId,
          'p_transition': transition,
          'p_request_id': requestId,
        },
      );
      return AdminContentCollection.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  @override
  Future<AdminContentItem> saveContent(SaveContentInput input) async {
    final validationError = input.validate();
    if (validationError != null) throw ContentAdminException(validationError);
    return _contentRpc('save_content_item', {
      'p_content_item_id': input.contentItemId,
      'p_type': input.type,
      'p_category_id': input.categoryId,
      'p_parent_content_id': input.parentContentId,
      'p_title': input.title.trim(),
      'p_title_bn': _value(input.titleBn),
      'p_slug': input.slug.trim(),
      'p_summary': _value(input.summary),
      'p_body': _value(input.body),
      'p_arabic_text': _value(input.arabicText),
      'p_bangla_text': _value(input.banglaText),
      'p_transliteration': _value(input.transliteration),
      'p_translation': _value(input.translation),
      'p_reference_text': _value(input.referenceText),
      'p_source_type': _value(input.sourceType),
      'p_source_reference': _value(input.sourceReference),
      'p_source_url': _value(input.sourceUrl),
      'p_source_edition': _value(input.sourceEdition),
      'p_translation_source': _value(input.translationSource),
      'p_surah_number': input.surahNumber,
      'p_surah_name': _value(input.surahName),
      'p_surah_name_bn': _value(input.surahNameBn),
      'p_ayah_number': input.ayahNumber,
      'p_ayah_end_number': input.ayahEndNumber,
      'p_collection_name': _value(input.collectionName),
      'p_book_name': _value(input.bookName),
      'p_hadith_number': _value(input.hadithNumber),
      'p_narrator': _value(input.narrator),
      'p_grade': _value(input.grade),
      'p_author': _value(input.author),
      'p_publisher': _value(input.publisher),
      'p_chapter_number': input.chapterNumber,
      'p_language_code': _value(input.languageCode),
      'p_rights_note': _value(input.rightsNote),
      'p_thumbnail_url': _value(input.thumbnailUrl),
      'p_media_source_type': input.mediaSourceType,
      'p_media_url': _value(input.mediaUrl),
      'p_youtube_video_id': _value(input.youtubeVideoId),
      'p_visibility': input.visibility,
      'p_status': input.status,
      'p_request_id': input.requestId,
    });
  }

  @override
  Future<AdminContentItem> transitionContent({
    required String contentItemId,
    required String transition,
    required String requestId,
    String? notes,
  }) => _contentRpc('transition_content_item', {
    'p_content_item_id': contentItemId,
    'p_transition': transition,
    'p_notes': _value(notes),
    'p_request_id': requestId,
  });

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
  }) async {
    try {
      final response = await _client.rpc(
        'save_content_category',
        params: {
          'p_category_id': categoryId,
          'p_parent_id': parentId,
          'p_name': name.trim(),
          'p_name_bn': _value(nameBn),
          'p_slug': slug.trim(),
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
          'p_request_id': requestId,
        },
      );
      return ContentCategory.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }

  Future<AdminContentItem> _contentRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _client.rpc(functionName, params: params);
      return AdminContentItem.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw ContentAdminException(error.message);
    }
  }
}

String? _value(String? input) {
  final value = input?.trim();
  return value == null || value.isEmpty ? null : value;
}
