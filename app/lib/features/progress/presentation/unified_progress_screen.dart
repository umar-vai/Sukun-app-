import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/core/widgets/sukun_bangla_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A shared, owner-private personal routine history for Members and Patients.
class UnifiedProgressScreen extends ConsumerStatefulWidget {
  const UnifiedProgressScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<UnifiedProgressScreen> createState() =>
      _UnifiedProgressScreenState();
}

class _UnifiedProgressScreenState extends ConsumerState<UnifiedProgressScreen> {
  int _days = 7;
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = PersonalRoutineRepository(Supabase.instance.client)
        .listProgress(days: _days);
  }

  void _changeDays(int days) {
    if (_days == days) return;
    setState(() {
      _days = days;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = ref.watch(appSessionProvider).value?.isPatient == true;
    final body = FutureBuilder<List<Map<String, dynamic>>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('হিস্ট্রি আনা যাচ্ছে না। আবার চেষ্টা করুন।'),
                TextButton(
                  onPressed: () => setState(_reload),
                  child: const Text('আবার চেষ্টা করুন'),
                ),
              ],
            ),
          );
        }
        final records = snapshot.data ?? [];
        final done = records.where((row) => row['outcome'] == 'done').length;
        final skipped = records
            .where((row) => row['outcome'] == 'skipped')
            .length;
        final byDay = <String, List<Map<String, dynamic>>>{};
        for (final record in records) {
          final date = record['local_date'].toString();
          byDay.putIfAbsent(date, () => []).add(record);
        }
        final dates = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

        return RefreshIndicator(
          onRefresh: () async {
            final refreshed = PersonalRoutineRepository(
              Supabase.instance.client,
            ).listProgress(days: _days);
            if (mounted) setState(() => _history = refreshed);
            await refreshed;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
            children: [
              Text(
                'আমার রুটিনের হিসাব',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'যে করণীয়গুলো সম্পন্ন করেছেন বা বাদ দিয়েছেন, সেগুলোর ব্যক্তিগত ইতিহাস।',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('৭ দিন'),
                    selected: _days == 7,
                    onSelected: (_) => _changeDays(7),
                  ),
                  ChoiceChip(
                    label: const Text('৩০ দিন'),
                    selected: _days == 30,
                    onSelected: (_) => _changeDays(30),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RoutineSummary(done: done, skipped: skipped),
              const SizedBox(height: 16),
              if (records.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: const Text('এখনো কোনো হিস্ট্রি নেই'),
                    subtitle: const Text(
                      'রুটিনের করণীয় সম্পন্ন বা বাদ দিলে এখানে দেখা যাবে।',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my-routines'),
                  ),
                )
              else
                for (final date in dates) ...[
                  _DayHistory(date: date, records: byDay[date]!),
                  const SizedBox(height: 10),
                ],
              if (isPatient) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_turned_in_outlined),
                    title: const Text('নির্ধারিত পরিকল্পনার অগ্রগতি'),
                    subtitle: const Text('সুকুন লাইফের অনুমোদিত করণীয়র হিসাব'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/patient/progress'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'এটি আপনার করা কাজের রেকর্ড, চিকিৎসার ফলাফল নয়। '
                'নির্ধারিত সব কাজের তুলনায় সম্পন্ন হওয়ার হার এখানে দেখানো হয়নি।',
              ),
            ],
          ),
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('আমার অগ্রগতি')),
      body: body,
    );
  }
}

class _RoutineSummary extends StatelessWidget {
  const _RoutineSummary({required this.done, required this.skipped});

  final int done;
  final int skipped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = done + skipped;
    final ratio = total == 0 ? 0.0 : done / total;
    Widget stat(String value, String label, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: SukunColors.muted,
            ),
          ),
        ],
      ),
    );
    return SukunSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ),
                    Text(
                      '${banglaDigits((ratio * 100).round())}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              stat(banglaDigits(done), 'সম্পন্ন', SukunColors.success),
              stat(
                banglaDigits(skipped),
                'বাদ দিয়েছেন',
                const Color(0xFF8A5A00),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            total == 0
                ? 'এখনো কাজের রেকর্ড নেই'
                : 'চিহ্নিত ${banglaDigits(total)}টি কাজের মধ্যে ${banglaDigits(done)}টি সম্পন্ন',
            style: theme.textTheme.bodySmall?.copyWith(
              color: SukunColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHistory extends StatelessWidget {
  const _DayHistory({required this.date, required this.records});

  final String date;
  final List<Map<String, dynamic>> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = DateTime.tryParse(date);
    return SukunSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parsed == null ? date : banglaWeekdayDate(parsed),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final record in records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    record['outcome'] == 'done'
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: record['outcome'] == 'done'
                        ? SukunColors.success
                        : const Color(0xFFB7791F),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      record['title'].toString(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  SukunStatusPill(
                    label: record['outcome'] == 'done'
                        ? 'সম্পন্ন'
                        : 'বাদ দিয়েছেন',
                    tone: record['outcome'] == 'done'
                        ? SukunStatusTone.success
                        : SukunStatusTone.warning,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
