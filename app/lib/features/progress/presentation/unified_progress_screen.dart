import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
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
          return const AppLoadingState(label: 'অগ্রগতি আনা হচ্ছে…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'হিস্ট্রি আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            onRetry: () => setState(_reload),
          );
        }
        final records = snapshot.data ?? [];
        final done = records.where((row) => row['outcome'] == 'done').length;
        final skipped = records
            .where((row) => row['outcome'] == 'skipped')
            .length;
        final total = done + skipped;
        final byDay = <String, List<Map<String, dynamic>>>{};
        for (final record in records) {
          final date = record['local_date'].toString();
          byDay.putIfAbsent(date, () => []).add(record);
        }
        final dates = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
        final textTheme = Theme.of(context).textTheme;
        final rate = total == 0 ? 0.0 : done / total;

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
              SukunSurface(
                key: const Key('routine-progress-summary'),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: rate,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              backgroundColor: SukunColors.mist,
                            ),
                          ),
                          Text(
                            '${(rate * 100).round()}%',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SukunSpace.page),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'সম্পন্ন $done · বাদ দিয়েছেন $skipped',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            total == 0
                                ? 'এখনো কাজের রেকর্ড নেই'
                                : 'চিহ্নিত $total টি কাজের মধ্যে $done টি সম্পন্ন',
                            style: textTheme.bodySmall?.copyWith(
                              color: SukunColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                  SukunSurface(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banglaDayLabel(date),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final record in byDay[date]!)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  record['outcome'] == 'done'
                                      ? Icons.check_circle_rounded
                                      : Icons.remove_circle_outline,
                                  size: 20,
                                  color: record['outcome'] == 'done'
                                      ? SukunColors.sukunBlue
                                      : SukunColors.muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(record['title'].toString()),
                                ),
                                Text(
                                  record['outcome'] == 'done'
                                      ? 'সম্পন্ন'
                                      : 'বাদ দিয়েছেন',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: SukunColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
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
              const SizedBox(height: SukunSpace.lg),
              Text(
                'নির্ধারিত সব কাজের তুলনায় সম্পন্ন হওয়ার হার এখানে দেখানো হয়নি।',
                style: textTheme.bodySmall?.copyWith(color: SukunColors.muted),
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
