import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/family/data/active_profile_store.dart';
import 'package:sukun_life/features/family/data/family_profiles_repository.dart';
import 'package:sukun_life/features/family/data/supabase_family_profiles_repository.dart';
import 'package:sukun_life/features/family/domain/family_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves the patient profile every patient-facing query must target.
///
/// Repositories take this instead of reading a provider directly so they stay
/// plain Dart and testable. It returns null only for sessions that have no
/// patient profile (never for a signed-in patient).
typedef ActivePatientIdReader = Future<String?> Function();

final familyProfilesRepositoryProvider = Provider<FamilyProfilesRepository>((
  ref,
) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableFamilyProfilesRepository();
  }
  return SupabaseFamilyProfilesRepository(Supabase.instance.client);
});

final activeProfileStoreProvider = Provider<ActiveProfileStore>(
  (ref) => const SharedPreferencesActiveProfileStore(),
);

final class UnavailableFamilyProfilesRepository
    implements FamilyProfilesRepository {
  const UnavailableFamilyProfilesRepository();

  @override
  Future<List<FamilyProfile>> getProfiles() async =>
      throw const FamilyProfilesException(
        'Connect Supabase to open family profiles.',
      );
}

/// The fetched profile list plus the profile this device is showing.
class ActiveProfileState {
  const ActiveProfileState({required this.profiles, required this.active});

  final List<FamilyProfile> profiles;
  final FamilyProfile active;

  /// The switcher is only shown when there is something to switch to, so a
  /// single patient account looks exactly as it did before family accounts.
  bool get hasMultipleProfiles => profiles.length > 1;

  ActiveProfileState withActive(FamilyProfile profile) =>
      ActiveProfileState(profiles: profiles, active: profile);
}

/// Picks the profile to show: the stored one if it is still in the fetched
/// list, otherwise the owner profile, otherwise the first profile.
FamilyProfile resolveActiveProfile(
  List<FamilyProfile> profiles,
  String? storedPatientId,
) {
  assert(profiles.isNotEmpty);
  if (storedPatientId != null) {
    for (final profile in profiles) {
      if (profile.patientId == storedPatientId) return profile;
    }
  }
  for (final profile in profiles) {
    if (profile.isPrimary) return profile;
  }
  return profiles.first;
}

class ActiveProfileNotifier extends AsyncNotifier<ActiveProfileState?> {
  String? _userId;

  @override
  Future<ActiveProfileState?> build() async {
    // selectAsync waits while the session is still loading (for example a
    // reminder refresh at startup) so a caller never sees "no profile" too
    // early and runs an unscoped query. It only re-runs when the login
    // itself changes, not on every session refresh.
    final userId = await ref.watch(
      appSessionProvider.selectAsync(
        (session) => session.isPatient ? session.userId : null,
      ),
    );
    _userId = userId;
    if (userId == null) return null;
    final login = userId;

    final profiles = await ref
        .read(familyProfilesRepositoryProvider)
        .getProfiles();
    if (profiles.isEmpty) {
      throw const FamilyProfilesException('No patient profile is available.');
    }
    final stored = await _readStored(login);
    final active = resolveActiveProfile(profiles, stored);
    if (stored != active.patientId) {
      // The stored id was stale (profile unlinked) or absent: forget it so a
      // removed profile can never come back as a selection.
      await _safely(() => ref.read(activeProfileStoreProvider).clear(login));
    }
    return ActiveProfileState(profiles: profiles, active: active);
  }

  /// Switch this device to [patientId]. Ignored unless it is one of the
  /// profiles the server returned, so a stale or forged id is never used.
  Future<void> select(String patientId) async {
    final current = state.value;
    final userId = _userId;
    if (current == null || userId == null) return;
    if (current.active.patientId == patientId) return;
    FamilyProfile? next;
    for (final profile in current.profiles) {
      if (profile.patientId == patientId) next = profile;
    }
    if (next == null) return;
    // Update the in-memory choice first so the UI and every repository move
    // together; persistence is best effort and per device.
    state = AsyncData(current.withActive(next));
    await _safely(
      () => ref.read(activeProfileStoreProvider).write(userId, patientId),
    );
  }

  Future<String?> _readStored(String userId) async {
    try {
      return await ref.read(activeProfileStoreProvider).read(userId);
    } on Object {
      return null;
    }
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // A failed preference write only costs the remembered choice.
    }
  }
}

final activeProfileProvider =
    AsyncNotifierProvider<ActiveProfileNotifier, ActiveProfileState?>(
      ActiveProfileNotifier.new,
      // A profile lookup failure is shown with a retry. Do not hammer the
      // backend with silent automatic retries.
      retry: (_, _) => null,
    );

/// The selected patient id, or null while loading / for non-patients.
final activePatientIdProvider = Provider<String?>(
  (ref) => ref.watch(
    activeProfileProvider.select((value) => value.value?.active.patientId),
  ),
);

final activePatientIdReaderProvider = Provider<ActivePatientIdReader>(
  (ref) => () async {
    // Riverpod pauses a provider nobody listens to, which would leave a
    // pending load unfinished (for example a reminder refresh before any
    // screen is mounted). Hold a listener while waiting.
    final hold = ref.listen(activeProfileProvider, (_, _) {});
    try {
      if (ref.read(activeProfileProvider).isLoading) {
        await ref.read(activeProfileProvider.future);
      }
      // Read the settled state, not the awaited future: right after a
      // switch the synchronous state is the source of truth.
      final settled = ref.read(activeProfileProvider);
      if (settled.hasError) throw settled.error!;
      return settled.value?.active.patientId;
    } finally {
      hold.close();
    }
  },
);
