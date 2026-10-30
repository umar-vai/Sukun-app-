import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';
import 'package:sukun_life/features/resources/presentation/canonical_quran_ayah_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The server checks Super Admin authorization on EVERY cross-user read/write.
/// Profiles are filtered by existing server RLS; no service key is in the app.
class AdminUserRoutinesScreen extends StatefulWidget {
  const AdminUserRoutinesScreen({super.key});

  @override
  State<AdminUserRoutinesScreen> createState() =>
      _AdminUserRoutinesScreenState();
}

class _AdminUserRoutinesScreenState extends State<AdminUserRoutinesScreen> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _users = _loadUsers('');
  Future<Map<String, dynamic>>? _progress;
  Map<String, dynamic>? _selected;
  String _query = '';
  int _days = 7;
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadUsers(String query) async {
    var request = _client.from('profiles').select('id,display_name');
    final normalized = query.trim();
    final looksLikeId = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(normalized);
    if (looksLikeId) {
      request = request.eq('id', normalized);
    } else if (normalized.isNotEmpty) {
      request = request.ilike('display_name', '%$normalized%');
    }
    final rows = await request.order('display_name').limit(40);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> _loadProgress(String id, int days) async {
    final raw = await _client.rpc(
      'admin_get_user_routine_progress',
      params: {'p_target_user_id': id, 'p_days': days},
    );
    if (raw is! Map) throw StateError('Progress is unavailable');
    return Map<String, dynamic>.from(raw);
  }

  void _searchUsers() {
    setState(() {
      _query = _search.text.trim();
      _users = _loadUsers(_query);
    });
  }

  void _selectUser(Map<String, dynamic> user) {
    final id = user['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      _selected = user;
      _progress = _loadProgress(id, _days);
    });
  }

  Future<List<ContentResourceOption>> _loadPickerResources() async {
    final rows = await _client
        .from('content_items')
        .select(
          'id,slug,title,title_bn,type,status,visibility,'
          'verification_status,category_id,surah_number,ayah_number,'
          'ayah_end_number,media_source_type,media_url,'
          'content_categories(id,name,name_bn,slug,sort_order)',
        )
        .eq('status', 'published')
        .eq('visibility', 'public')
        .order('title')
        .limit(500);
    return rows
        .map(ContentResourceOption.fromJson)
        .where((resource) => resource.isLinkable)
        .toList(growable: false);
  }

  Future<void> _composeRoutine() async {
    final user = _selected;
    if (_saving || user == null) return;
    setState(() => _saving = true);
    try {
      final resources = await _loadPickerResources();
      if (!mounted) return;
      final proposal = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _AdminRoutineComposer(resources: resources),
      );
      if (proposal == null || !mounted) return;
      await _client.rpc(
        'admin_create_user_routine',
        params: {
          'p_target_user_id': user['id'],
          'p_title': proposal['title'],
          'p_actions': proposal['actions'],
        },
      );
      if (!mounted) return;
      _selectUser(user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ব্যবহারকারীর জন্য রুটিন খসড়া তৈরি হয়েছে। '
            'তিনি নিজে চালু করলে রুটিন সক্রিয় হবে।',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'রুটিন তৈরি করা যায়নি। Super Admin অনুমতি, '
            'ডাটাবেস আপডেট এবং উপকরণের প্রকাশনা যাচাই করুন।',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return AdminScaffold(
      title: 'ব্যবহারকারী ও রুটিন',
      selectedIndex: 0,
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'ব্যবহারকারীকে রুটিন দিন',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'শুধু Super Admin অনুমোদিত কাজ করতে পারবেন। '
            'প্রতিটি রুটিন তৈরি ও অগ্রগতি দেখার ঘটনা Audit Log-এ থাকবে।',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'ব্যবহারকারীর নাম বা ID খুঁজুন',
              hintText: 'নাম লিখে খুঁজুন',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'খুঁজুন',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _searchUsers,
              ),
            ),
            onSubmitted: (_) => _searchUsers(),
          ),
          const SizedBox(height: 10),
          Text(
            _query.isEmpty
                ? 'প্রথম ৪০ জনের তালিকা · নির্দিষ্ট নাম দিয়ে খুঁজুন'
                : '“$_query” অনুসন্ধানের প্রথম ৪০টি ফলাফল',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _users,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const ListTile(
                  leading: Icon(Icons.error_outline),
                  title: Text('ব্যবহারকারীর তালিকা আনা যাচ্ছে না।'),
                  subtitle: Text('অনুমতি ও সংযোগ যাচাই করুন।'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const ListTile(
                  title: Text('কোনো ব্যবহারকারী পাওয়া যায়নি।'),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final user = snapshot.data![index];
                    final selectedId = selected?['id'] == user['id'];
                    return Card(
                      child: ListTile(
                        selected: selectedId,
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(
                          user['display_name']?.toString().trim().isNotEmpty ==
                                  true
                              ? user['display_name'].toString()
                              : 'নাম দেওয়া নেই',
                        ),
                        subtitle: Text(
                          selectedId
                              ? 'নির্বাচিত ব্যবহারকারী'
                              : 'অগ্রগতি ও রুটিন দেখতে বাছুন',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _selectUser(user),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          if (selected != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected['display_name']?.toString() ?? 'ব্যবহারকারী',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'এই ব্যবহারকারীর রুটিন ও নিজে চিহ্নিত করা অগ্রগতি। '
                      'এগুলো Notification Delivery বা ক্লিনিক্যাল ফলাফলের প্রমাণ নয়।',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _composeRoutine,
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: Text(
                            _saving ? 'প্রস্তুত হচ্ছে…' : 'নতুন রুটিন তৈরি',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/resources'),
                          icon: const Icon(Icons.auto_stories_outlined),
                          label: const Text('সবার উপকরণ'),
                        ),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 7, label: Text('৭ দিন')),
                            ButtonSegment(value: 30, label: Text('৩০ দিন')),
                          ],
                          selected: {_days},
                          onSelectionChanged: (values) {
                            setState(() {
                              _days = values.single;
                              _progress = _loadProgress(
                                selected['id'] as String,
                                _days,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: _progress,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('অগ্রগতি আনা যায়নি।'),
                    subtitle: Text('Super Admin অনুমতি ও সার্ভার যাচাই করুন।'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final routines = (data['routines'] as List? ?? const []);
                final outcomes = (data['progress'] as List? ?? const []);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'রুটিন (${routines.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (routines.isEmpty)
                      const ListTile(title: Text('এখনো কোনো রুটিন নেই')),
                    for (final raw in routines)
                      if (raw is Map)
                        ListTile(
                          leading: Icon(
                            raw['is_active'] == true
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                          ),
                          title: Text(raw['title']?.toString() ?? 'রুটিন'),
                          subtitle: Text(
                            raw['is_active'] == true
                                ? 'চালু আছে'
                                : 'ব্যবহারকারীর চালু করার অপেক্ষায়',
                          ),
                        ),
                    const Divider(),
                    Text(
                      'সাম্প্রতিক অগ্রগতি (${outcomes.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (outcomes.isEmpty)
                      const ListTile(
                        title: Text('নির্বাচিত সময়ে কোনো অগ্রগতি নেই।'),
                      ),
                    for (final raw in outcomes)
                      if (raw is Map)
                        ListTile(
                          leading: Icon(
                            raw['outcome'] == 'done'
                                ? Icons.check_circle_outline
                                : Icons.remove_circle_outline,
                          ),
                          title: Text(
                            raw['action_title']?.toString() ?? 'করণীয়',
                          ),
                          subtitle: Text(
                            '${raw['routine_title'] ?? ''} · ${raw['local_date'] ?? ''}',
                          ),
                          trailing: Text(
                            raw['outcome'] == 'done' ? 'সম্পন্ন' : 'বাদ',
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerAction {
  _ComposerAction() : title = TextEditingController();
  final TextEditingController title;
  final List<Map<String, String>> resources = [];

  void dispose() => title.dispose();
}

class _AdminRoutineComposer extends StatefulWidget {
  const _AdminRoutineComposer({required this.resources});
  final List<ContentResourceOption> resources;

  @override
  State<_AdminRoutineComposer> createState() => _AdminRoutineComposerState();
}

class _AdminRoutineComposerState extends State<_AdminRoutineComposer> {
  final _title = TextEditingController();
  final _actions = <_ComposerAction>[_ComposerAction()];

  @override
  void dispose() {
    _title.dispose();
    for (final action in _actions) {
      action.dispose();
    }
    super.dispose();
  }

  Future<void> _addCms(_ComposerAction action) async {
    if (action.resources.length >= 16) return;
    final options = widget.resources
        .where(
          (r) => !action.resources.any(
            (linked) => linked['content_item_id'] == r.id,
          ),
        )
        .toList(growable: false);
    final id = await showResourcePickerSheet(
      context: context,
      resources: options,
      selectedId: '',
    );
    if (!mounted || id == null || id.isEmpty) return;
    setState(() {
      action.resources.add({'provider': 'cms', 'content_item_id': id});
    });
  }

  Future<void> _addQuranAyah(_ComposerAction action) async {
    if (action.resources.length >= 16) return;
    final choice = await showCanonicalQuranAyahPicker(
      context: context,
      excludedReferences: action.resources
          .where((r) => r['provider'] == 'quran')
          .map((r) => r['external_resource_ref']!)
          .toSet(),
    );
    if (!mounted || choice == null) return;
    setState(() {
      action.resources.add({
        'provider': 'quran',
        'external_resource_ref': choice.reference,
      });
    });
  }

  Future<void> _addSurah(_ComposerAction action) async {
    if (action.resources.length >= 16) return;
    final excluded = action.resources
        .where(
          (r) =>
              r['provider'] == 'quran' &&
              (r['external_resource_ref']?.split(':').length ?? 0) == 2,
        )
        .map((r) => int.tryParse(r['external_resource_ref']!.split(':').last))
        .whereType<int>()
        .toSet();
    final number = await showPersonalSurahPicker(
      context: context,
      exclude: excluded,
    );
    if (!mounted || number == null) return;
    setState(() {
      action.resources.add({
        'provider': 'quran',
        'external_resource_ref': 'quran:$number',
      });
    });
  }

  void _save() {
    if (_title.text.trim().isEmpty ||
        _title.text.trim().length > 120 ||
        _actions.any(
          (a) =>
              a.title.text.trim().isEmpty || a.title.text.trim().length > 160,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('রুটিন ও প্রতিটি করণীয়ের নাম লিখুন।')),
      );
      return;
    }
    Navigator.pop(context, {
      'title': _title.text.trim(),
      'actions': [
        for (final action in _actions)
          {'title': action.title.text.trim(), 'resources': action.resources},
      ],
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ব্যবহারকারীর জন্য রুটিন তৈরি'),
    content: SizedBox(
      width: 610,
      height: MediaQuery.sizeOf(context).height * .67,
      child: ListView(
        children: [
          const Text(
            'রুটিনটি প্রথমে বন্ধ থাকবে। ব্যবহারকারী নিজে চালু করবেন '
            'এবং নোটিফিকেশনের অনুমতি দেবেন।',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'রুটিনের নাম'),
          ),
          for (var index = 0; index < _actions.length; index++) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'করণীয় ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_actions.length > 1)
                  IconButton(
                    tooltip: 'করণীয় বাদ দিন',
                    onPressed: () =>
                        setState(() => _actions.removeAt(index).dispose()),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            TextField(
              controller: _actions[index].title,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'করণীয়ের নাম',
                hintText: 'উদাহরণ: সূরা ফাতিহা পাঠ',
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addCms(_actions[index]),
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('উপকরণ'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addSurah(_actions[index]),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('সূরা'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addQuranAyah(_actions[index]),
                  icon: const Icon(Icons.format_list_numbered_rounded),
                  label: const Text('আয়াত'),
                ),
              ],
            ),
            for (var item = 0; item < _actions[index].resources.length; item++)
              ListTile(
                dense: true,
                title: Text(
                  _actions[index].resources[item]['provider'] == 'quran'
                      ? _actions[index]
                                .resources[item]['external_resource_ref'] ??
                            'কুরআন'
                      : widget.resources
                                .where(
                                  (r) =>
                                      r.id ==
                                      _actions[index]
                                          .resources[item]['content_item_id'],
                                )
                                .firstOrNull
                                ?.displayTitle ??
                            'উপকরণ',
                ),
                trailing: IconButton(
                  tooltip: 'সংযুক্ত উপকরণ বাদ দিন',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      setState(() => _actions[index].resources.removeAt(item)),
                ),
              ),
          ],
          if (_actions.length < 12)
            OutlinedButton.icon(
              onPressed: () => setState(() => _actions.add(_ComposerAction())),
              icon: const Icon(Icons.add),
              label: const Text('আরও একটি করণীয় যোগ করুন'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('বাতিল'),
      ),
      FilledButton(
        onPressed: _save,
        child: const Text('নিষ্ক্রিয় খসড়া রুটিন দিন'),
      ),
    ],
  );
}
