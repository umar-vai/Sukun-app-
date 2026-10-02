import 'package:sukun_life/features/progress/data/progress_repository.dart';
import 'package:sukun_life/features/progress/domain/adherence_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseProgressRepository implements ProgressRepository {
  const SupabaseProgressRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AdherenceSummary> getMyProgress({int days = 7}) => _load(days: days);

  @override
  Future<AdherenceSummary> getPatientProgress(
    String patientId, {
    int days = 7,
  }) => _load(patientId: patientId, days: days);

  Future<AdherenceSummary> _load({String? patientId, required int days}) async {
    if (days < 1 || days > 90) {
      throw const ProgressException('Progress range must be 1 to 90 days.');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = today.subtract(Duration(days: days - 1));
    try {
      var query = _client
          .from('task_instances')
          .select('occurrence_date,status')
          .gte('occurrence_date', _dateOnly(first))
          .lte('occurrence_date', _dateOnly(today));
      if (patientId != null) query = query.eq('patient_id', patientId);
      final response = await query.order('occurrence_date');
      return AdherenceSummary.fromTasks(
        tasks: response.map(TrackedTaskStatus.fromJson),
        throughDate: today,
        dayCount: days,
      );
    } on PostgrestException catch (error) {
      throw ProgressException(error.message);
    }
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
