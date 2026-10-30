import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile directory for verified Super Admins.
/// The existing profiles_select_own_or_admin RLS policy authorizes reads;
/// no service-role key, email, phone or cross-user routine data is exposed.
class AdminAllUsersScreen extends StatefulWidget {
  const AdminAllUsersScreen({super.key});

  @override
  State<AdminAllUsersScreen> createState() => _AdminAllUsersScreenState();
}

class _AdminAllUsersScreenState extends State<AdminAllUsersScreen> {
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _profiles = _loadProfiles();
  int _page = 0;
  static const int _pageSize = 40;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadProfiles() async {
    var query = Supabase.instance.client
        .from('profiles')
        .select('id,display_name,created_at');
    final term = _query.trim();
    if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(term)) {
      query = query.eq('id', term);
    } else if (term.isNotEmpty) {
      query = query.ilike('display_name', '%$term%');
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _reload({bool firstPage = false}) {
    setState(() {
      if (firstPage) _page = 0;
      _query = _searchController.text;
      _profiles = _loadProfiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminScaffold(
      title: 'সকল ব্যবহারকারী',
      selectedIndex: 1,
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _profiles;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
          children: [
            Text('সকল অ্যাপ ব্যবহারকারী', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 5),
            const Text(
              'এই তালিকায় সাধারণ ব্যবহারকারী ও রোগী অ্যাকাউন্টের Profile আছে। '
              'রোগীর চিকিৎসাসংক্রান্ত তথ্য আলাদা সুরক্ষিত।',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/patients'),
                  icon: const Icon(Icons.medical_information_outlined),
                  label: const Text('রোগীদের আলাদা তালিকা'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/admin/library'),
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('সবার উপকরণ'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(firstPage: true),
              decoration: InputDecoration(
                labelText: 'নাম বা User ID',
                hintText: 'নাম লিখে খুঁজুন',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'খুঁজুন',
                  onPressed: () => _reload(firstPage: true),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _profiles,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ListTile(
                    leading: Icon(Icons.lock_outline_rounded),
                    title: Text('ব্যবহারকারীর তালিকা আনা যাচ্ছে না'),
                    subtitle: Text(
                      'Super Admin অনুমতি ও ইন্টারনেট সংযোগ যাচাই করুন।',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      users.isEmpty
                          ? 'এই অনুসন্ধানে কেউ নেই'
                          : 'ব্যবহারকারী · পৃষ্ঠা ${_page + 1} · ${users.length}টি',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final user in users)
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline_rounded),
                          ),
                          title: Text(
                            (user['display_name']?.toString().trim().isNotEmpty ??
                                    false)
                                ? user['display_name'].toString()
                                : 'নাম দেওয়া হয়নি',
                          ),
                          subtitle: Text(
                            'User ID: ${user['id'] ?? '—'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _page == 0
                              ? null
                              : () => setState(() {
                                  _page--;
                                  _profiles = _loadProfiles();
                                }),
                          child: const Text('আগের পৃষ্ঠা'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: users.length < _pageSize
                              ? null
                              : () => setState(() {
                                  _page++;
                                  _profiles = _loadProfiles();
                                }),
                          child: const Text('পরের পৃষ্ঠা'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'অন্য ব্যবহারকারীর রুটিন তৈরি ও অগ্রগতি দেখার '
                      'ফিচার নিরাপদ সার্ভার অনুমোদন চালুর পর পাওয়া যাবে।',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
