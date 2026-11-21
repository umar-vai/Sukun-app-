import 'package:sukun_life/features/family/domain/family_profile.dart';

abstract interface class FamilyProfilesRepository {
  /// The caller's selectable profiles, owner first. Never empty for a
  /// patient account; a single patient account returns one profile.
  Future<List<FamilyProfile>> getProfiles();
}

class FamilyProfilesException implements Exception {
  const FamilyProfilesException(this.message);

  final String message;

  @override
  String toString() => message;
}
