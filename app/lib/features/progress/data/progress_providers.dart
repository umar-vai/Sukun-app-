import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/progress/data/progress_repository.dart';
import 'package:sukun_life/features/progress/data/supabase_progress_repository.dart';
import 'package:sukun_life/features/progress/domain/adherence_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableProgressRepository();
  }
  return SupabaseProgressRepository(Supabase.instance.client);
});

final class UnavailableProgressRepository implements ProgressRepository {
  const UnavailableProgressRepository();

  Never _unavailable() =>
      throw const ProgressException('Connect Supabase to view progress.');

  @override
  Future<AdherenceSummary> getMyProgress({int days = 7}) async =>
      _unavailable();

  @override
  Future<AdherenceSummary> getPatientProgress(
    String patientId, {
    int days = 7,
  }) async => _unavailable();
}
