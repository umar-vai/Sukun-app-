import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_bangla_format.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin "Patients" tab (owner request 2026-11-12).
///
/// Lists only people under care: patient accounts and members an admin has
/// already set a routine for. Ordinary app users are not listed; a search
/// (name, email, phone or patient number) reaches anyone so the admin can
/// start care. Data comes from `admin_list_care_recipients`, which checks the
/// Super Admin role in the database.
class AdminAllUsersScreen extends StatefulWidget {
  const AdminAllUsersScreen({super.key});

  @override
  State<AdminAllUsersScreen> createState() => _AdminAllUsersScreenState();
}

class _AdminAllUsersScreenState extends State<AdminAllUsersScreen> {
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _people = _load();
  int _page = 0;
  static const int _pageSize = 40;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.rpc(
      'admin_list_care_recipients',
      params: {
        'p_query': _query.trim().isEmpty ? null : _query.trim(),
        'p_limit': _pageSize,
        'p_offset': _page * _pageSize,
      },
    );
    return [
      for (final row in rows as List)
        {...Map<String, dynamic>.from(row as Map), 'id': (row)['user_id']},
    ];
  }

  void _reload({bool firstPage = false}) {
    setState(() {
      if (firstPage) _page = 0;
      _query = _searchController.text;
      _people = _load();
    });
  }

  void _open(Map<String, dynamic> person) {
    final id = person['id']?.toString() ?? '';
    if (id.isEmpty) return;
    context.go('/admin/user-routines?userId=${Uri.encodeComponent(id)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = _query.trim().isNotEmpty;
    return AdminScaffold(
      title: 'রোগী',
      selectedIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/patients/new'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('নতুন রোগী'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _people;
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SukunSpace.page,
                SukunSpace.xs,
                SukunSpace.page,
                110,
              ),
              children: [
                SukunSearchField(
                  controller: _searchController,
                  hintText: 'নাম, ইমেইল, ফোন বা রোগী নম্বর',
                  onSubmitted: (_) => _reload(firstPage: true),
                  onClear: () {
                    _searchController.clear();
                    _reload(firstPage: true);
                  },
                ),
                const SizedBox(height: SukunSpace.lg),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _people,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _Message(
                        icon: Icons.cloud_off_rounded,
                        text: 'তালিকা আনা যাচ্ছে না',
                        action: TextButton(
                          onPressed: _reload,
                          child: const Text('আবার চেষ্টা'),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final people = snapshot.data!;
                    if (people.isEmpty) {
                      return _Message(
                        icon: searching
                            ? Icons.search_off_rounded
                            : Icons.people_outline_rounded,
                        text: searching
                            ? 'কাউকে পাওয়া যায়নি'
                            : 'এখনো কোনো রোগী নেই',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            bottom: SukunSpace.sm,
                          ),
                          child: Text(
                            searching
                                ? 'ফলাফল · ${people.length}'
                                : 'রোগী · ${people.length}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: SukunColors.muted,
                            ),
                          ),
                        ),
                        for (final person in people)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: SukunSpace.sm,
                            ),
                            child: AdminUserDirectoryTile(
                              user: person,
                              onOpen: () => _open(person),
                            ),
                          ),
                        if (_page > 0 || people.length >= _pageSize)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton.outlined(
                                tooltip: 'আগের পৃষ্ঠা',
                                onPressed: _page == 0
                                    ? null
                                    : () => setState(() {
                                        _page--;
                                        _people = _load();
                                      }),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'পরের পৃষ্ঠা',
                                onPressed: people.length < _pageSize
                                    ? null
                                    : () => setState(() {
                                        _page++;
                                        _people = _load();
                                      }),
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(icon, size: 44, color: SukunColors.muted),
        const SizedBox(height: SukunSpace.md),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
        ?action,
      ],
    ),
  );
}

/// One person row: avatar initial, name, patient number or contact, and a
/// status pill. The callback always uses the server-guarded admin routine
/// page, never a privileged client API.
class AdminUserDirectoryTile extends StatelessWidget {
  const AdminUserDirectoryTile({
    super.key,
    required this.user,
    required this.onOpen,
  });

  final Map<String, dynamic> user;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = user['id']?.toString() ?? '';
    final name = user['display_name']?.toString().trim() ?? '';
    final code = user['patient_code']?.toString().trim() ?? '';
    final email = user['email']?.toString().trim() ?? '';
    final phone = user['phone']?.toString().trim() ?? '';
    final isPatient = user['is_patient'] == true;
    final hasRoutine = user['has_admin_routine'] == true;
    final detail = [
      if (code.isNotEmpty) code,
      if (phone.isNotEmpty) phone else if (email.isNotEmpty) email,
    ].join(' · ');
    final shown = name.isEmpty ? 'নাম দেওয়া হয়নি' : name;
    return SukunSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        key: Key('admin-user-$id'),
        enabled: id.isNotEmpty,
        onTap: id.isEmpty ? null : onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 21,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.secondary,
          child: name.isEmpty
              ? const Icon(Icons.person_outline_rounded)
              : Text(
                  name.characters.first,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
        title: Text(
          shown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          detail.isNotEmpty ? detail : _joinedAndShortId(user, id),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: SukunColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPatient || hasRoutine)
              SukunStatusPill(
                label: isPatient ? 'রোগী' : 'রুটিন চালু',
                tone: SukunStatusTone.brand,
              )
            else
              const SukunStatusPill(label: 'নতুন'),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Fallback subtitle when a user has no code, phone or email: when they
/// joined and a short ID instead of the full UUID.
String _joinedAndShortId(Map<String, dynamic> user, String id) => [
  if (DateTime.tryParse(user['created_at']?.toString() ?? '')
      case final joined?)
    'যোগ দিয়েছেন ${banglaWeekdayDate(joined.toLocal())}',
  'ID …${id.isEmpty ? '—' : id.substring(id.length > 8 ? id.length - 8 : 0)}',
].join(' · ');
