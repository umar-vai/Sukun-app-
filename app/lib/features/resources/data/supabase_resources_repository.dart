import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseResourcesRepository implements ResourcesRepository {
  const SupabaseResourcesRepository(this._client);

  final SupabaseClient _client;

  static const _selection =
      'id,type,category_id,title,title_bn,summary,body,arabic_text,bangla_text,transliteration,translation,reference_text,source_reference,source_url,rights_note,media_source_type,media_url,youtube_video_id,thumbnail_url,verification_status,visibility,status,created_at,surah_number,surah_name,surah_name_bn,ayah_number,ayah_end_number,collection_name,book_name,hadith_number,narrator,grade,content_categories(slug,name,name_bn)';

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    try {
      var request = _client
          .from('content_items')
          .select(_selection)
          .eq('status', 'published');
      if (types.isNotEmpty) {
        request = request.inFilter('type', types.toList(growable: false));
      }
      final response = await request
          .order('published_at', ascending: false)
          .limit(1000);
      var resources = response
          .map(ContentResource.fromJson)
          .toList(growable: false);
      if (categoryPrefixes.isNotEmpty) {
        resources = resources
            .where(
              (resource) => categoryPrefixes.any(
                (prefix) =>
                    resource.categorySlug == prefix ||
                    resource.categorySlug?.startsWith('$prefix-') == true,
              ),
            )
            .toList(growable: false);
      }
      final terms = _searchTerms(query);
      if (terms.isEmpty) return resources;
      return resources
          .where((resource) => _matchesEveryTerm(resource, terms))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ResourceException(error.message);
    }
  }

  @override
  Future<ContentResource?> getResource(String resourceId) async {
    try {
      final response = await _client
          .from('content_items')
          .select(_selection)
          .eq('id', resourceId)
          .eq('status', 'published')
          .maybeSingle();
      return response == null ? null : ContentResource.fromJson(response);
    } on PostgrestException catch (error) {
      throw ResourceException(error.message);
    }
  }

  @override
  Future<List<QuranSurahSummary>> browseSurahs() async {
    final ayat = <ContentResource>[];
    const pageSize = 1000;
    try {
      for (var offset = 0; ; offset += pageSize) {
        final response = await _client
            .from('content_items')
            .select(_selection)
            .eq('status', 'published')
            .eq('type', 'quran')
            .order('surah_number')
            .order('ayah_number')
            .range(offset, offset + pageSize - 1);
        ayat.addAll(response.map(ContentResource.fromJson));
        if (response.length < pageSize) break;
      }
    } on PostgrestException catch (error) {
      throw ResourceException(error.message);
    }
    final grouped = <int, List<ContentResource>>{};
    for (final ayah in ayat) {
      final number = ayah.surahNumber;
      if (number != null) (grouped[number] ??= []).add(ayah);
    }
    final summaries =
        grouped.entries
            .map((entry) {
              final first = entry.value.first;
              return QuranSurahSummary(
                surahNumber: entry.key,
                name: first.surahName ?? 'Surah ${entry.key}',
                nameBn: first.surahNameBn,
                ayahCount: entry.value.length,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => a.surahNumber.compareTo(b.surahNumber));
    return summaries;
  }

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) async {
    try {
      final response = await _client
          .from('content_items')
          .select(_selection)
          .eq('status', 'published')
          .eq('type', 'quran')
          .eq('surah_number', surahNumber)
          .order('ayah_number')
          .limit(300);
      return response.map(ContentResource.fromJson).toList(growable: false);
    } on PostgrestException catch (error) {
      throw ResourceException(error.message);
    }
  }

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) async {
    final resources = await browseResources(
      types: types,
      categoryPrefixes: categoryPrefixes,
    );
    final grouped = <String, List<ContentResource>>{};
    for (final resource in resources) {
      final categoryId = resource.categoryId;
      if (categoryId != null) (grouped[categoryId] ??= []).add(resource);
    }
    final topics =
        grouped.entries
            .map((entry) {
              final first = entry.value.first;
              return ResourceTopic(
                id: entry.key,
                slug: first.categorySlug ?? '',
                name: first.categoryName ?? 'Topic',
                nameBn: first.categoryNameBn,
                resourceCount: entry.value.length,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => a.name.compareTo(b.name));
    return topics;
  }

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) async {
    try {
      var request = _client
          .from('content_collections')
          .select('id,type,title,title_bn,slug,summary,visibility,status')
          .eq('status', 'published');
      if (types.isNotEmpty) {
        request = request.inFilter('type', types.toList(growable: false));
      }
      final response = await request.order('title');
      return response.map(ContentCollection.fromJson).toList(growable: false);
    } on PostgrestException catch (error) {
      throw ResourceException(error.message);
    }
  }

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) async {
    try {
      final collectionJson = await _client
          .from('content_collections')
          .select('id,type,title,title_bn,slug,summary,visibility,status')
          .eq('id', collectionId)
          .eq('status', 'published')
          .maybeSingle();
      if (collectionJson == null) return null;
      final memberships = await _client
          .from('content_collection_items')
          .select('sort_order,content_items($_selection)')
          .eq('collection_id', collectionId)
          .order('sort_order');
      final items = memberships
          .map((row) => row['content_items'])
          .whereType<Map<String, dynamic>>()
          .map(ContentResource.fromJson)
          .toList(growable: false);
      return ContentCollectionDetails(
        collection: ContentCollection.fromJson(collectionJson),
        items: items,
      );
    } on PostgrestException catch (error) {
      throw ResourceException(error.message);
    }
  }
}

Set<String> _searchTerms(String query) => query
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .split(RegExp(r'\s+'))
    .where((term) => term.isNotEmpty)
    .toSet();

bool _matchesEveryTerm(ContentResource resource, Set<String> terms) {
  final searchable = [
    resource.title,
    resource.titleBn,
    resource.summary,
    resource.referenceText,
    resource.sourceReference,
  ].whereType<String>().join(' ').toLowerCase();
  return terms.every(searchable.contains);
}
