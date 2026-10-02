import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseResourcesRepository implements ResourcesRepository {
  const SupabaseResourcesRepository(this._client);

  final SupabaseClient _client;

  static const _selection =
      'id,type,title,title_bn,summary,body,arabic_text,bangla_text,transliteration,translation,reference_text,source_reference,media_source_type,media_url,youtube_video_id,thumbnail_url,verification_status,visibility,status,created_at,content_categories(slug,name,name_bn)';

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
          .limit(100);
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
