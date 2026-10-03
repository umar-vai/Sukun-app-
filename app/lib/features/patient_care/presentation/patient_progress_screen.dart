import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';
import 'package:sukun_life/features/progress/data/progress_providers.dart';
import 'package:sukun_life/features/progress/domain/adherence_summary.dart';

class PatientProgressScreen extends ConsumerStatefulWidget {
  const PatientProgressScreen({super.key});

  @override
  ConsumerState<PatientProgressScreen> createState() =>
      _PatientProgressScreenState();
}

class _PatientProgressScreenState extends ConsumerState<PatientProgressScreen> {
  int _days = 7;
  late Future<AdherenceSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  Future<AdherenceSummary> _load() =>
      ref.read(progressRepositoryProvider).getMyProgress(days: _days);

  void _reload() {
    setState(() {
      _summary = _load();
    });
  }

  void _setRange(int days) {
    if (days == _days) return;
    setState(() {
      _days = days;
      _summary = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      title: 'Progress',
      selectedIndex: 3,
      body: FutureBuilder<AdherenceSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading your progress');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final summary = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              final updated = await _load();
              if (mounted) {
                setState(() {
                  _summary = Future.value(updated);
                });
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 days')),
                    ButtonSegment(value: 30, label: Text('30 days')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (values) => _setRange(values.first),
                ),
                const SizedBox(height: 18),
                _ProgressOverview(summary: summary),
                const SizedBox(height: 24),
                Text(
                  'Daily activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (summary.total == 0)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No task activity has been tracked in this period yet.',
                      ),
                    ),
                  )
                else
                  for (final day in summary.days.reversed) ...[
                    _ProgressDayTile(day: day),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 8),
                Text(
                  'Progress reflects task activity only and is not a clinical assessment.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.summary});

  final AdherenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final percentage = (summary.completionRate * 100).round();
    return Card(
      color: SukunColors.mist,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$percentage% completed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: summary.completionRate),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: 'Done', value: summary.completed),
                _MetricChip(label: 'Remaining', value: summary.remaining),
                _MetricChip(label: 'Skipped', value: summary.skipped),
                _MetricChip(label: 'Missed', value: summary.missed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label $value'));
}

class _ProgressDayTile extends StatelessWidget {
  const _ProgressDayTile({required this.day});

  final AdherenceDay day;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _weekday(day.date),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(_shortDate(day.date)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: day.completionRate),
                  const SizedBox(height: 7),
                  Text(
                    day.total == 0
                        ? 'No tracked tasks'
                        : '${day.completed} of ${day.total} completed',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _weekday(DateTime date) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}';
