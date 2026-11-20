import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/family/data/active_profile_store.dart';
import 'package:sukun_life/features/family/data/family_profiles_repository.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/features/family/domain/family_profile.dart';

const testUserId = 'family-login';

FamilyProfile profile(
  String id,
  String name, {
  String? relationship,
  bool primary = false,
  int order = 0,
}) => FamilyProfile(
  patientId: id,
  fullName: name,
  relationshipLabel: relationship,
  isPrimary: primary,
  displayOrder: order,
  familyId: 'family-1',
);

/// Owner plus four relatives: five profiles, no hard-coded limit anywhere.
List<FamilyProfile> fiveProfileFamily() => [
  profile('p-owner', 'Rahim Uddin', primary: true),
  profile('p-spouse', 'Amina Rahim', relationship: 'স্ত্রী', order: 1),
  profile('p-child1', 'Zayd Rahim', relationship: 'ছেলে', order: 2),
  profile('p-child2', 'Maryam Rahim', relationship: 'মেয়ে', order: 3),
  profile('p-parent', 'Abdul Karim', relationship: 'বাবা', order: 4),
];

final class FakeFamilyProfilesRepository implements FamilyProfilesRepository {
  FakeFamilyProfilesRepository(this.profiles);

  List<FamilyProfile> profiles;
  int calls = 0;

  @override
  Future<List<FamilyProfile>> getProfiles() async {
    calls++;
    return profiles;
  }
}

final class MemoryActiveProfileStore implements ActiveProfileStore {
  MemoryActiveProfileStore([Map<String, String>? initial])
    : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String userId) async => values[userId];

  @override
  Future<void> write(String userId, String patientId) async =>
      values[userId] = patientId;

  @override
  Future<void> clear(String userId) async => values.remove(userId);
}

/// Overrides that make the app behave as a signed-in patient login whose
/// family is [profiles].
List<Override> familyOverrides(
  List<FamilyProfile> profiles, {
  MemoryActiveProfileStore? store,
  FakeFamilyProfilesRepository? repository,
}) => [
  appSessionProvider.overrideWith(
    (ref) => Stream.value(
      const AppSession(
        role: UserRole.patient,
        userId: testUserId,
        displayName: 'Rahim',
      ),
    ),
  ),
  familyProfilesRepositoryProvider.overrideWithValue(
    repository ?? FakeFamilyProfilesRepository(profiles),
  ),
  activeProfileStoreProvider.overrideWithValue(
    store ?? MemoryActiveProfileStore(),
  ),
];
