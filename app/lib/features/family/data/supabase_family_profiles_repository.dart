import 'package:sukun_life/features/family/data/family_profiles_repository.dart';
import 'package:sukun_life/features/family/domain/family_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseFamilyProfilesRepository
    implements FamilyProfilesRepository {
  const SupabaseFamilyProfilesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FamilyProfile>> getProfiles() async {
    try {
      final response = await _client.rpc('my_family_profiles');
      if (response is! List) {
        throw const FamilyProfilesException(
          'Profiles could not be read. Please try again.',
        );
      }
      return [
        for (final row in response)
          FamilyProfile.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } on PostgrestException {
      throw const FamilyProfilesException(
        'Profiles could not be read. Please try again.',
      );
    }
  }
}
