import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/data/care_template_repository.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/prescription_overview.dart';
import 'package:sukun_life/features/care_plans/presentation/prescription_overview_card.dart';
import 'package:sukun_life/features/care_plans/data/reminder_controls.dart';
import 'package:sukun_life/features/care_plans/presentation/live_reminders_card.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/presentation/bulk_template_import_screen.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The server checks Super Admin authorization on EVERY cross-user read/write.
/// Profiles are filtered by existing server RLS; no service key is in the app.
class AdminUserRoutinesScreen extends StatefulWidget {
  const AdminUserRoutinesScreen({super.key, this.initialUserId});

  /// The selected user is resolved through normal RLS; a URL never grants access.
  final String? initialUserId;

  @override
  State<AdminUserRoutinesScreen> createState() =>
      _AdminUserRoutinesScreenState();
}

class _AdminUserRoutinesScreenState extends State<AdminUserRoutinesScreen> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _users;
  Future<Map<String, dynamic>>? _progress;
  Future<PrescriptionOverview>? _overview;
  Map<String, dynamic>? _selected;
  String _query = '';
  int _days = 7;
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUserId?.trim() ?? '';
    _query = initial;
    _search.text = initial;
    _users = _loadUsers(initial);
    if (initial.isNotEmpty) _selectInitialUser();
  }

  Future<void> _selectInitialUser() async {
    try {
      final users = await _users;
      if (!mounted || users.isEmpty) return;
      final target = widget.initialUserId;
      for (final user in users) {
        if (user['id']?.toString() == target) {
          _selectUser(user);
          return;
        }
      }
    } catch (_) {
      // FutureBuilder displays the permission/network error in the directory.
    }
  }

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
    final container = ProviderScope.containerOf(context);
    setState(() {
      _selected = user;
      _progress = _loadProgress(id, _days);
      _overview = loadPrescriptionOverview(
        carePlans: container.read(carePlansRepositoryProvider),
        routines: container.read(routineOverviewLoaderProvider),
        userId: id,
      );
    });
  }

  /// Actions of routines an admin set (the user's own ones are theirs to
  /// control, so they are not listed here).
  Future<List<LiveReminder>> _adminRoutineReminders(String userId) async {
    final routines = await ProviderScope.containerOf(context)
        .read(routineOverviewLoaderProvider)(userId);
    return [
      for (final routine in routines)
        if (routine['is_active'] == true &&
            routine['assigned_by_admin'] == true)
          for (final action in routine['actions'] as List? ?? const [])
            if (action is Map)
              ?LiveReminder.fromRoutineAction(
                Map<String, dynamic>.from(action),
              ),
    ];
  }

  /// Public, published resources only: a routine is visible outside care
  /// plans, so patient-only items are never linked here.
  Future<List<ContentResourceOption>> _loadPickerResources() async {
    final all = await ProviderScope.containerOf(context)
        .read(carePlansRepositoryProvider)
        .getAvailableResources();
    return all
        .where(
          (resource) => resource.isLinkable && resource.visibility == 'public',
        )
        .toList(growable: false);
  }

  /// One click: tick templates or library items, check the times, import.
  /// The routine is active straight away with daily reminder times.
  Future<void> _bulkImport() async {
    final user = _selected;
    if (_saving || user == null) return;
    final name = user['display_name']?.toString().trim();
    final templateRepository = ProviderScope.containerOf(context)
        .read(careTemplateRepositoryProvider);
    final items = await showBulkTemplateImport(
      context,
      recipientLabel: name == null || name.isEmpty
          ? 'নির্বাচিত ব্যবহারকারী'
          : 'ব্যবহারকারী: $name',
      resources: _loadPickerResources(),
      showDuration: false,
      templates: templateRepository.load(),
      saveTemplate: templateRepository.save,
    );
    if (items == null || items.isEmpty || !mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final drafts = expandBulkItems(items);
      final now = DateTime.now();
      await _client.rpc(
        'admin_import_user_routine_reminders',
        params: {
          'p_target_user_id': user['id'],
          'p_title':
              'সুকুন রুটিন · ${toBanglaDigits('${now.day}/${now.month}')}',
          'p_actions': [for (final draft in drafts) draft.toRoutineJson()],
        },
      );
      if (!mounted) return;
      _selectUser(user);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${toBanglaDigits('${drafts.length}')}টি করণীয় রিমাইন্ডারসহ চালু হয়েছে। '
            'ব্যবহারকারী অ্যাপ খুললেই সময়মতো রিমাইন্ডার পাবেন।',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'ইম্পোর্ট করা যায়নি। Super Admin অনুমতি, সংযোগ ও '
            'উপকরণ প্রকাশিত কিনা দেখে আবার চেষ্টা করুন।',
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
      selectedIndex: 1,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
        children: [
          TextButton.icon(
            onPressed: () => context.go('/admin/users'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('সকল ব্যবহারকারী'),
          ),
          const SizedBox(height: 10),
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
          if (selected == null) ...[
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
                            user['display_name']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
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
          ],
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
                          key: const Key('admin-routine-bulk-import'),
                          onPressed: _saving ? null : _bulkImport,
                          icon: const Icon(Icons.playlist_add_check_rounded),
                          label: Text(
                            _saving
                                ? 'যুক্ত হচ্ছে…'
                                : 'আমল ও রিমাইন্ডার যোগ করুন',
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
            if (_overview != null) ...[
              PrescriptionOverviewCard(
                key: ValueKey(_overview),
                recipientName:
                    selected['display_name']?.toString().trim().isNotEmpty ==
                        true
                    ? selected['display_name'].toString()
                    : 'ব্যবহারকারী',
                overview: _overview!,
                selfLabel: 'ইউজার নিজে যোগ করেছেন',
              ),
              const SizedBox(height: 16),
              Text(
                'চলমান রিমাইন্ডার (অ্যাডমিনের দেওয়া)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              LiveRemindersCard(
                key: ValueKey(('live', _overview)),
                emptyText: 'অ্যাডমিনের দেওয়া কোনো চলমান রিমাইন্ডার নেই।',
                load: () => _adminRoutineReminders(selected['id'].toString()),
                onToggle: (id, enabled) =>
                    ProviderScope.containerOf(context)
                        .read(reminderControlsProvider)
                        .setRoutineActionReminder(id, enabled),
              ),
              const SizedBox(height: 12),
            ],
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
