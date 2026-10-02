import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseResourcesRepository implements ResourcesRepository {
  const SupabaseResourcesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ContentResource?> getResource(String resourceId) async {
    try {
      final response = await _client
          .from('content_items')
          .select(
            'id,type,title,title_bn,summary,body,arabic_text,bangla_text,transliteration,translation,reference_text,source_reference,media_source_type,media_url,youtube_video_id,visibility,status',
          )
          .eq('id', resourceId)
          .eq('status', 'published')
          .maybeSingle();
      return response == null ? null : ContentResource.fromJson(response);
    } on PostgrestException catch (error) {
      throw ResourceException(error.message);
    }
  }
}
