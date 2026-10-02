import 'package:sukun_life/features/progress/domain/adherence_summary.dart';

abstract interface class ProgressRepository {
  Future<AdherenceSummary> getMyProgress({int days = 7});

  Future<AdherenceSummary> getPatientProgress(String patientId, {int days = 7});
}

class ProgressException implements Exception {
  const ProgressException(this.message);

  final String message;

  @override
  String toString() => message;
}
