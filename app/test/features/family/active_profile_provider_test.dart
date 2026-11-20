import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/family/data/active_profile_store.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/features/family/domain/family_profile.dart';

import 'family_test_support.dart';

void main() {
  /// [listen] mimics the app root (ActiveProfileEffects) keeping the
  /// provider alive; Riverpod 3 pauses providers nobody listens to.
  ProviderContainer container(
    List<FamilyProfile> profiles, {
    MemoryActiveProfileStore? store,
    bool listen = true,
  }) {
    final c = ProviderContainer(
      overrides: familyOverrides(profiles, store: store),
    );
    addTearDown(c.dispose);
    if (listen) c.listen(activeProfileProvider, (_, _) {});
    return c;
  }

  test('FamilyProfile parses my_family_profiles() rows', () {
    final parsed = FamilyProfile.fromJson({
      'patient_id': 'p1',
      'full_name': '  Amina Rahim ',
      'relationship_label': ' স্ত্রী ',
      'display_order': 2,
      'is_primary': false,
      'family_id': 'f1',
      'family_label': 'রহিম পরিবার',
    });
    expect(parsed.patientId, 'p1');
    expect(parsed.fullName, 'Amina Rahim');
    expect(parsed.relationshipLabel, 'স্ত্রী');
    expect(parsed.displayOrder, 2);
    expect(parsed.familyLabel, 'রহিম পরিবার');

    final single = FamilyProfile.fromJson({
      'patient_id': 'p2',
      'full_name': 'Solo',
      'relationship_label': null,
      'display_order': 0,
      'is_primary': true,
      'family_id': null,
      'family_label': null,
    });
    expect(single.relationshipLabel, isNull);
    expect(single.isPrimary, isTrue);
  });

  test('initials work for Latin and Bangla names without dangling signs', () {
    expect(profile('a', 'Amina Rahim').initials, 'AR');
    expect(profile('a', 'rahim').initials, 'R');
    expect(profile('a', '').initials, '?');
    // "আমিনা রহিম": আ + র. "রহিম" starts with a plain letter.
    expect(profile('a', 'আমিনা রহিম').initials, 'আর');
    // Leading consonants keep their vowel signs: কি and হো stay whole.
    expect(profile('a', 'কিরণ হোসেন').initials, 'কিহো');
  });

  test('a single patient account resolves to exactly one profile', () async {
    final c = container([profile('only', 'Solo Patient', primary: true)]);
    final state = (await c.read(activeProfileProvider.future))!;
    expect(state.profiles, hasLength(1));
    expect(state.hasMultipleProfiles, isFalse);
    expect(state.active.patientId, 'only');
    expect(c.read(activePatientIdProvider), 'only');
  });

  test('defaults to the owner profile, even when listed later', () async {
    final c = container([
      profile('p-child', 'Zayd', relationship: 'ছেলে'),
      profile('p-owner', 'Rahim', primary: true),
    ]);
    final state = (await c.read(activeProfileProvider.future))!;
    expect(state.active.patientId, 'p-owner');
  });

  test('restores the stored per-device choice when it is valid', () async {
    final store = MemoryActiveProfileStore({testUserId: 'p-child1'});
    final c = container(fiveProfileFamily(), store: store);
    final state = (await c.read(activeProfileProvider.future))!;
    expect(state.active.patientId, 'p-child1');
  });

  test('a stored id that is not in the fetched list falls back to the owner and is forgotten', () async {
    final store = MemoryActiveProfileStore({testUserId: 'removed-profile'});
    final c = container(fiveProfileFamily(), store: store);
    final state = (await c.read(activeProfileProvider.future))!;
    expect(state.active.patientId, 'p-owner');
    expect(store.values.containsKey(testUserId), isFalse);
  });

  test('select persists on this device and ignores unknown ids', () async {
    final store = MemoryActiveProfileStore();
    final c = container(fiveProfileFamily(), store: store);
    await c.read(activeProfileProvider.future);
    final notifier = c.read(activeProfileProvider.notifier);

    await notifier.select('p-spouse');
    expect(c.read(activePatientIdProvider), 'p-spouse');
    expect(store.values[testUserId], 'p-spouse');

    await notifier.select('someone-elses-patient');
    expect(c.read(activePatientIdProvider), 'p-spouse');
    expect(store.values[testUserId], 'p-spouse');
  });

  test('the reader repositories use works with no listener and follows the selection', () async {
    // No app root here: a startup reminder refresh has no mounted screen.
    final c = container(fiveProfileFamily(), listen: false);
    final read = c.read(activePatientIdReaderProvider);
    expect(await read(), 'p-owner');
    await c.read(activeProfileProvider.notifier).select('p-parent');
    expect(await read(), 'p-parent');
  });

  test('guests and non-patient sessions have no profile and no RPC', () async {
    final repo = FakeFamilyProfilesRepository(fiveProfileFamily());
    final c = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(
          (ref) => Stream.value(const AppSession.guest()),
        ),
        familyProfilesRepositoryProvider.overrideWithValue(repo),
        activeProfileStoreProvider.overrideWithValue(
          MemoryActiveProfileStore(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activeProfileProvider, (_, _) {});
    expect(await c.read(activeProfileProvider.future), isNull);
    expect(repo.calls, 0);
  });

  test('shared_preferences store is per login and per device only', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesActiveProfileStore();
    await store.write('login-a', 'p1');
    await store.write('login-b', 'p9');
    expect(await store.read('login-a'), 'p1');
    expect(await store.read('login-b'), 'p9');
    await store.clear('login-a');
    expect(await store.read('login-a'), isNull);
    expect(await store.read('login-b'), 'p9');
  });
}
