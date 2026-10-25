import 'package:flutter/material.dart';
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
        final total = done + skipped;
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
                'যে করণীয়গুলো Done বা Skip করেছেন, সেগুলোর ব্যক্তিগত ইতিহাস।',
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'সম্পন্ন $done · বাদ দিয়েছেন $skipped',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        total == 0
                            ? 'এখনো কাজের রেকর্ড নেই'
                            : 'চিহ্নিত $total টি কাজের মধ্যে $done টি সম্পন্ন',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: const Text('এখনো কোনো হিস্ট্রি নেই'),
                    subtitle: const Text(
                      'রুটিনের করণীয় Done বা Skip করলে এখানে দেখা যাবে।',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my-routines'),
                  ),
                )
              else
                for (final date in dates)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          for (final record in byDay[date]!)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                record['outcome'] == 'done'
                                    ? Icons.check_circle_outline
                                    : Icons.remove_circle_outline,
                              ),
                              title: Text(record['title'].toString()),
                              subtitle: Text(
                                record['outcome'] == 'done'
                                    ? 'সম্পন্ন'
                                    : 'বাদ দিয়েছেন',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
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
