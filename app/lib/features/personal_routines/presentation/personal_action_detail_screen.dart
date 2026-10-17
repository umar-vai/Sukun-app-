import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Same action detail screen for members and patients' *self-owned* routines.
/// Supabase RLS independently protects action and linked-resource ownership.
class PersonalActionDetailScreen extends StatefulWidget {
  const PersonalActionDetailScreen({super.key, required this.actionId});
  final String actionId;

  @override
  State<PersonalActionDetailScreen> createState() =>
      _PersonalActionDetailScreenState();
}

class _PersonalActionDetailScreenState
    extends State<PersonalActionDetailScreen> {
  late Future<_PersonalActionDetail> _load;
  bool _saving = false;

  PersonalRoutineRepository get _repo =>
      PersonalRoutineRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load = _read();
  }

  Future<_PersonalActionDetail> _read() async {
    final action = await _repo.getAction(widget.actionId);
    if (action == null) return const _PersonalActionDetail();
    final refs = await _repo.listActionResources(widget.actionId);
    // Backward compatibility for actions created before multiple links.
    if (refs.isEmpty && action['content_item_id'] is String) {
      final id = action['content_item_id'] as String;
      final item = await Supabase.instance.client
          .from('content_items')
          .select('id,title,title_bn,type,status,visibility')
          .eq('id', id)
          .maybeSingle();
      if (item != null) {
        refs.add({
          'provider': 'cms',
          'content_item_id': id,
          'content_items': item,
        });
      }
    }
    final outcomes = await _repo.todaysOutcomes(DateTime.now());
    return _PersonalActionDetail(
      action: action,
      references: refs,
      todayOutcome: outcomes[widget.actionId],
    );
  }

  Future<void> _complete(String status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repo.recordOutcome(
        actionId: widget.actionId,
        localDate: DateTime.now(),
        outcome: status,
      );
      if (!mounted) return;
      setState(() => _load = _read());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'done' ? 'আজকের আমল সম্পন্ন' : 'আজকের আমল Skip করা হয়েছে',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সংরক্ষণ হয়নি। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('আমার করণীয়')),
    body: FutureBuilder<_PersonalActionDetail>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: () => setState(() => _load = _read()),
              child: const Text('রিসোর্স আনা যায়নি — আবার চেষ্টা করুন'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.action == null) {
          return const Center(
            child: Text('অ্যাকশনটি পাওয়া যায়নি বা অনুমতি নেই।'),
          );
        }
        final action = data.action!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              action['title'] as String? ?? 'আমার করণীয়',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              action['notification_title'] as String? ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Text(
              'সংযুক্ত রিসোর্স',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (data.references.isEmpty)
              const ListTile(
                title: Text('এখনো কোনো রিসোর্স যুক্ত করা হয়নি'),
                subtitle: Text(
                  'রুটিন থেকে Edit করে লাইব্রেরির রিসোর্স যুক্ত করুন।',
                ),
              ),
            for (final reference in data.references)
              _ResourceReferenceTile(reference: reference),
            const SizedBox(height: 24),
            if (data.todayOutcome case final outcome?) ...[
              Text(
                outcome == 'done'
                    ? 'আজকের অবস্থা: সম্পন্ন'
                    : 'আজকের অবস্থা: Skip করা হয়েছে',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _saving ? null : () => _complete('done'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('আজকের আমল সম্পন্ন'),
            ),
            TextButton(
              onPressed: _saving ? null : () => _complete('skipped'),
              child: const Text('আজকের জন্য Skip'),
            ),
          ],
        );
      },
    ),
  );
}

class _ResourceReferenceTile extends StatelessWidget {
  const _ResourceReferenceTile({required this.reference});
  final Map<String, dynamic> reference;

  @override
  Widget build(BuildContext context) {
    final provider = reference['provider'] as String?;
    final content = reference['content_items'];
    final cms = content is Map ? Map<String, dynamic>.from(content) : null;
    final id = reference['content_item_id'] as String?;
    final canOpen =
        provider == 'cms' &&
        cms != null &&
        cms['status'] == 'published' &&
        cms['visibility'] == 'public' &&
        id != null;
    final label = cms?['title_bn'] as String?;
    final name = label?.trim().isNotEmpty == true
        ? label!
        : (cms?['title'] as String? ?? 'রিসোর্সটি এখন অনুপলব্ধ');
    final external = reference['external_resource_ref'] as String?;
    final surahNumber = provider == 'quran'
        ? quranNumberFromRef(external)
        : null;
    final route = canOpen
        ? '/resources/${Uri.encodeComponent(id)}'
        : surahNumber != null
        ? '/resources/quran/$surahNumber'
        : null;
    return Card(
      child: ListTile(
        leading: Icon(
          provider == 'quran'
              ? Icons.menu_book_outlined
              : Icons.library_books_outlined,
        ),
        title: Text(
          provider == 'cms'
              ? name
              : surahNumber != null
              ? 'সূরা $surahNumber'
              : 'রিসোর্স অনুপলব্ধ',
        ),
        subtitle: Text(
          route != null ? 'খুলুন ও আমল করুন' : 'যাচাই বা প্রকাশের অপেক্ষায়',
        ),
        trailing: route != null ? const Icon(Icons.chevron_right) : null,
        onTap: route == null ? null : () => context.push(route),
      ),
    );
  }
}

class _PersonalActionDetail {
  const _PersonalActionDetail({
    this.action,
    this.references = const [],
    this.todayOutcome,
  });
  final Map<String, dynamic>? action;
  final List<Map<String, dynamic>> references;
  final String? todayOutcome;
}
