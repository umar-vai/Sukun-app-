import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
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
      title: 'অগ্রগতি',
      selectedIndex: 3,
      body: FutureBuilder<AdherenceSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'অগ্রগতি আনা হচ্ছে…');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'অগ্রগতির তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
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
                const SukunPageIntro(
                  eyebrow: 'করণীয় কাজের হিসাব',
                  title: 'আমার অগ্রগতি',
                  subtitle: 'কোন কাজগুলো করেছেন, তার একটি সহজ হিসাব। এটি স্বাস্থ্য পরীক্ষার ফল নয়।',
                ),
                const SizedBox(height: 20),
                _RangeToggle(value: _days, onChanged: _setRange),
                const SizedBox(height: 16),
                _ProgressOverview(summary: summary),
                const SizedBox(height: 24),
                const SukunSectionHeader(
                  title: 'প্রতিদিনের কাজ',
                  subtitle: 'দিন অনুযায়ী হিসাব',
                ),
                const SizedBox(height: 10),
                if (summary.total == 0)
                  const SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    child: Row(
                      children: [
                        SukunIconBadge(icon: Icons.insights_outlined),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text('এই সময়ে কোনো কাজের হিসাব পাওয়া যায়নি।'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final day in summary.days.reversed) ...[
                    _ProgressDayTile(day: day),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 8),
                Text(
                  'এখানে শুধু কাজ করার হিসাব দেখানো হয়, চিকিৎসার ফলাফল নয়।',
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

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: SukunColors.softBlue,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        for (final days in const [7, 30])
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value == days ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: value == days
                      ? [
                          BoxShadow(
                            color: SukunColors.nightNavy.withValues(
                              alpha: 0.07,
                            ),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '$days দিন',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: value == days
                        ? SukunColors.deepTide
                        : SukunColors.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.summary});

  final AdherenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final percentage = (summary.completionRate * 100).round();
    return SukunSurface(
      tone: SukunSurfaceTone.navy,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$percentage% কাজ করেছেন',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'নির্বাচিত সময়ের সম্পন্ন কাজের হিসাব',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: summary.completionRate,
            color: SukunColors.saffron,
            backgroundColor: Colors.white24,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'করেছি', value: summary.completed),
              _MetricChip(label: 'বাকি', value: summary.remaining),
              _MetricChip(label: 'আজ করা হয়নি', value: summary.skipped),
              _MetricChip(label: 'সময় পেরিয়েছে', value: summary.missed),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(
      '$value  $label',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}

class _ProgressDayTile extends StatelessWidget {
  const _ProgressDayTile({required this.day});

  final AdherenceDay day;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      radius: 18,
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
                      ? 'কোনো কাজের হিসাব নেই'
                      : '${day.total}টির মধ্যে ${day.completed}টি করেছেন',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _weekday(DateTime date) => const [
  'সোম',
  'মঙ্গল',
  'বুধ',
  'বৃহস্পতি',
  'শুক্র',
  'শনি',
  'রবি',
][date.weekday - 1];

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}';
