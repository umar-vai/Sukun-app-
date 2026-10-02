import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

class TrackedTaskStatus {
  const TrackedTaskStatus({required this.date, required this.status});

  factory TrackedTaskStatus.fromJson(Map<String, dynamic> json) {
    return TrackedTaskStatus(
      date: DateTime.parse(json['occurrence_date'] as String),
      status: PatientTaskStatus.fromDatabase(json['status'] as String?),
    );
  }

  final DateTime date;
  final PatientTaskStatus status;
}

class AdherenceDay {
  const AdherenceDay({
    required this.date,
    required this.total,
    required this.completed,
    required this.skipped,
    required this.snoozed,
    required this.pending,
    required this.missed,
  });

  final DateTime date;
  final int total;
  final int completed;
  final int skipped;
  final int snoozed;
  final int pending;
  final int missed;

  double get completionRate => total == 0 ? 0 : completed / total;
}

class AdherenceSummary {
  const AdherenceSummary({required this.days});

  factory AdherenceSummary.fromTasks({
    required Iterable<TrackedTaskStatus> tasks,
    required DateTime throughDate,
    required int dayCount,
  }) {
    assert(dayCount > 0);
    final through = _dateOnly(throughDate);
    final first = through.subtract(Duration(days: dayCount - 1));
    final grouped = <DateTime, List<PatientTaskStatus>>{};
    for (final task in tasks) {
      final date = _dateOnly(task.date);
      if (date.isBefore(first) || date.isAfter(through)) continue;
      if (task.status == PatientTaskStatus.cancelled) continue;
      grouped.putIfAbsent(date, () => []).add(task.status);
    }

    return AdherenceSummary(
      days: List.generate(dayCount, (index) {
        final date = first.add(Duration(days: index));
        final statuses = grouped[date] ?? const <PatientTaskStatus>[];
        int count(PatientTaskStatus status) =>
            statuses.where((item) => item == status).length;
        return AdherenceDay(
          date: date,
          total: statuses.length,
          completed: count(PatientTaskStatus.completed),
          skipped: count(PatientTaskStatus.skipped),
          snoozed: count(PatientTaskStatus.snoozed),
          pending: count(PatientTaskStatus.pending),
          missed: count(PatientTaskStatus.missed),
        );
      }),
    );
  }

  final List<AdherenceDay> days;

  int get total => days.fold(0, (sum, day) => sum + day.total);
  int get completed => days.fold(0, (sum, day) => sum + day.completed);
  int get skipped => days.fold(0, (sum, day) => sum + day.skipped);
  int get missed => days.fold(0, (sum, day) => sum + day.missed);
  int get remaining =>
      days.fold(0, (sum, day) => sum + day.pending + day.snoozed);
  double get completionRate => total == 0 ? 0 : completed / total;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
