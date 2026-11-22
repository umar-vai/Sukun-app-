import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_bangla_format.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
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

  /// Last good history per user and range, shown at once on reopen while
  /// fresh data loads.
  static final Map<String, List<Map<String, dynamic>>> _last = {};

  String get _cacheKey =>
      '${Supabase.instance.client.auth.currentUser?.id ?? ''}|$_days';

  void _reload() {
    final key = _cacheKey;
    _history = PersonalRoutineRepository(Supabase.instance.client)
        .listProgress(days: _days)
        .then((rows) {
          _last[key] = rows;
          return rows;
        });
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
        final cached = _last[_cacheKey];
        if (snapshot.connectionState != ConnectionState.done &&
            cached == null) {
          return const AppLoadingState(label: 'অগ্রগতি আনা হচ্ছে…');
        }
        if (snapshot.hasError && cached == null) {
          return AppErrorState(
            message: 'হিস্ট্রি আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            onRetry: () => setState(_reload),
          );
        }
        final records = snapshot.data ?? cached ?? [];
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
        final textTheme = Theme.of(context).textTheme;

        return RefreshIndicator(
          onRefresh: () async {
            final refreshed = PersonalRoutineRepository(
              Supabase.instance.client,
            ).listProgress(days: _days);
            if (mounted) setState(() => _history = refreshed);
            await refreshed;
          },
          child: ListView(
            key: const Key('routine-progress-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.page,
              SukunSpace.xs,
              SukunSpace.page,
              36,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'আমার রুটিনের হিসাব',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SukunFilterPill(
                    key: const Key('progress-range-7'),
                    label: '৭ দিন',
                    selected: _days == 7,
                    onTap: () => _changeDays(7),
                  ),
                  const SizedBox(width: SukunSpace.sm),
                  SukunFilterPill(
                    key: const Key('progress-range-30'),
                    label: '৩০ দিন',
                    selected: _days == 30,
                    onTap: () => _changeDays(30),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'যে করণীয়গুলো সম্পন্ন বা বাদ দিয়েছেন, সেগুলোর ব্যক্তিগত ইতিহাস।',
                style: textTheme.bodySmall?.copyWith(color: SukunColors.muted),
              ),
              const SizedBox(height: SukunSpace.lg),
              _RoutineSummary(
                key: const Key('routine-progress-summary'),
                done: done,
                skipped: skipped,
              ),
              const SizedBox(height: SukunSpace.section),
              if (records.isEmpty)
                SukunSurface(
                  tone: SukunSurfaceTone.soft,
                  showBorder: false,
                  onTap: () => context.push('/my-routines'),
                  child: const Row(
                    children: [
                      Icon(Icons.event_note_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'এখনো কোনো হিস্ট্রি নেই',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'রুটিনের করণীয় সম্পন্ন বা বাদ দিলে এখানে দেখা যাবে।',
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                )
              else ...[
                const SukunSectionHeader(title: 'দিন অনুযায়ী'),
                const SizedBox(height: SukunSpace.md),
                for (final date in dates) ...[
                  _DayHistory(date: date, records: byDay[date]!),
                  const SizedBox(height: 10),
                ],
              ],
              if (isPatient) ...[
                const SizedBox(height: SukunSpace.sm),
                SukunSurface(
                  key: const Key('progress-patient-plan-link'),
                  tone: SukunSurfaceTone.soft,
                  showBorder: false,
                  onTap: () => context.push('/patient/progress'),
                  child: const Row(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'নির্ধারিত পরিকল্পনার অগ্রগতি',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text('সুকুন লাইফের অনুমোদিত করণীয়র হিসাব'),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ],
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
  const _RoutineSummary({super.key, required this.done, required this.skipped});

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
    return SukunSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            banglaDayLabel(date),
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

/// "2026-11-09" → "সোম, ৯ নভেম্বর". Falls back to the raw value if it is
/// not a date, so nothing is hidden.
String banglaDayLabel(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  const weekdays = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];
  const months = [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];
  const digits = '০১২৩৪৫৬৭৮৯';
  final day = date.day
      .toString()
      .split('')
      .map((d) => digits[int.parse(d)])
      .join();
  return '${weekdays[date.weekday - 1]}, $day ${months[date.month - 1]}';
}
