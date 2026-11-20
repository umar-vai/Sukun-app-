import 'package:shared_preferences/shared_preferences.dart';

/// The selected profile, stored on THIS device only.
///
/// This is deliberately not a server or family-wide setting: one phone can
/// show a parent while another phone shows a child. The value is only a
/// hint; callers must validate it against the fetched profile list.
abstract interface class ActiveProfileStore {
  Future<String?> read(String userId);

  Future<void> write(String userId, String patientId);

  Future<void> clear(String userId);
}

final class SharedPreferencesActiveProfileStore implements ActiveProfileStore {
  const SharedPreferencesActiveProfileStore();

  // Keyed by login so two accounts on one device never inherit each other's
  // selection.
  static String keyFor(String userId) => 'sukun.active_patient_profile.$userId';

  @override
  Future<String?> read(String userId) async {
    final value = (await SharedPreferences.getInstance()).getString(
      keyFor(userId),
    );
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> write(String userId, String patientId) async {
    await (await SharedPreferences.getInstance()).setString(
      keyFor(userId),
      patientId,
    );
  }

  @override
  Future<void> clear(String userId) async {
    await (await SharedPreferences.getInstance()).remove(keyFor(userId));
  }
}
